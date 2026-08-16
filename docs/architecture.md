# Code Architecture & Technical Design Document

This document provides a comprehensive technical overview of the **Hybrid Metagenomics Pipeline**, a Nextflow DSL2 software framework. It details the underlying architectural principles, 5-layer separation of concerns, channel dataflows, workflow orchestration, module designs, and extensibility patterns.

---

## 1. Architectural Philosophy

This framework is built upon five core software engineering principles adapted for computational biology:

1. **Single Responsibility Principle**: Each module wraps exactly one bioinformatics tool. A module does not coordinate workflows or make pipeline routing decisions.
2. **Replaceability**: Upstream or downstream components can be swapped without touching unrelated stages (e.g., changing `MEGAHIT` to `metaSPAdes` does not alter preprocessing, binning, or reporting).
3. **Layer Isolation**: Strict layer boundaries are enforced to prevent coupling. Application code cannot invoke shell scripts directly; modules cannot invoke other modules.
4. **Reproducibility & Pinned Containers**: All dependencies are encapsulated in version-pinned OCI container images (`tool:version`, never `latest`).
5. **HPC Scalability**: Task parallelism is handled natively by Nextflow's dataflow engine, with fine-grained CPU and memory resource allocations configured per process label (`process_low`, `process_medium`, `process_high`).

---

## 2. The 5-Layer Software Architecture

```
┌────────────────────────────────────────────────────────────────────────┐
│                        1. APPLICATION LAYER                            │
│                              main.nf                                   │
│  - Parses samplesheet via lib/Samplesheet.groovy                      │
│  - Pre-flight parameter validation via lib/Validation.groovy           │
│  - Orchestrates execution of the 11 subworkflows                      │
└───────────────────────────────────┬────────────────────────────────────┘
                                    │ invokes
┌───────────────────────────────────▼────────────────────────────────────┐
│                         2. WORKFLOW LAYER                              │
│                          workflows/*.nf                                │
│  - Connects modules via Nextflow channels for distinct pipeline stages │
│  - Handles tool selection logic (params.assembler, params.polisher)     │
│  - Emits clean, standardized output channels                           │
└───────────────────────────────────┬────────────────────────────────────┘
                                    │ invokes
┌───────────────────────────────────▼────────────────────────────────────┐
│                          3. MODULE LAYER                               │
│                     modules/local/<tool>/main.nf                       │
│  - 35 discrete DSL2 process definitions                                │
│  - Pinned biocontainers, input/output declarations, shell scripts      │
└───────────────────────────────────┬────────────────────────────────────┘
                                    │ calls
┌───────────────────────────────────▼────────────────────────────────────┐
│                          4. SCRIPT LAYER                               │
│                      lib/*.groovy  bin/*.py                            │
│  - lib/Utils.groovy, lib/Samplesheet.groovy, lib/Validation.groovy     │
│  - bin/generate_report.py (Jinja2 report compiler)                     │
│  - bin/kraken_to_biom.py (BIOM 1.0 JSON & TSV matrix converter)        │
│  - templates/report.html, templates/summary.md                         │
└───────────────────────────────────┬────────────────────────────────────┘
                                    │ configured by
┌───────────────────────────────────▼────────────────────────────────────┐
│                     5. INFRASTRUCTURE LAYER                            │
│                    conf/*.config  params/*.yaml                        │
│  - Global config: nextflow.config                                      │
│  - Runtime profiles: conf/slurm.config, conf/singularity.config, etc.  │
│  - Parameter presets: params/illumina.yaml, params/hybrid.yaml, etc.   │
└────────────────────────────────────────────────────────────────────────┘
```

### Layer Boundary Rules

| Layer | Source Location | May Call | May NOT Call |
|---|---|---|---|
| **Application** | `main.nf` | `workflows/` | Modules, Shell commands |
| **Workflow** | `workflows/*.nf` | `modules/` | Other workflows directly, Shell commands |
| **Module** | `modules/local/*/main.nf` | Shell/Container only | Other modules, Workflows |
| **Script** | `lib/*.groovy`, `bin/*.py` | Groovy / Python stdlib | Nextflow DSL operators |
| **Infrastructure** | `conf/`, `params/` | Configuration keys | Bioinformatic logic |

---

## 3. Detailed Workflow Orchestration (11 Stages)

### 1. `workflows/preprocessing.nf`
- **Purpose**: Raw sequencing quality control, adapter trimming, and filtering for both short and long reads.
- **Inputs**:
  - `ch_short_reads`: `[ meta, [ fastq_1, fastq_2 ] ]`
  - `ch_long_reads`: `[ meta, fastq ]`
- **Sub-processes**:
  - `FASTQC`: Short-read per-base quality metrics.
  - `FASTP`: Short-read adapter trimming, polyG clipping, and quality filtering.
  - `DORADO_BASECALL` (*conditional*): Oxford Nanopore raw POD5/FAST5 GPU basecalling.
  - `NANOPLOT`: Long-read quality and length distribution analysis.
  - `PORECHOP_ABI` (*conditional*): Long-read adapter trimming.
  - `FILTLONG` (*conditional*): Long-read quality and minimum length filtering.
- **Outputs**:
  - `short_reads`: Clean Illumina reads `[ meta, [ r1, r2 ] ]`
  - `long_reads`: Clean Nanopore reads `[ meta, fastq ]`
  - `qc_reports`: Channel of generated QC log files (FastQC zips, fastp JSONs, NanoPlot text reports).

---

### 2. `workflows/host_removal.nf`
- **Purpose**: Decontaminate human/host reads from metagenomic samples.
- **Inputs**:
  - `ch_clean_short`: Clean short reads from preprocessing.
  - `ch_clean_long`: Clean long reads from preprocessing.
- **Sub-processes**:
  - `BOWTIE2_HOST_REMOVAL`: Maps short reads to host reference genome (`GRCh38`); exports unmapped read pairs (`--un-conc-gz`) and mapping flagstat.
  - `MINIMAP2_HOST_REMOVAL`: Maps long reads to host reference; filters unmapped reads (`samtools view -f 4`) to FASTQ.
- **Outputs**:
  - `short_reads`: Decontaminated short reads `[ meta, [ r1, r2 ] ]`
  - `long_reads`: Decontaminated long reads `[ meta, fastq ]`
  - `host_stats`: Host decontamination alignment flagstat summaries.

---

### 3. `workflows/assembly.nf`
- **Purpose**: De novo contig assembly based on sequencing platform.
- **Inputs**:
  - `ch_short_reads`, `ch_long_reads`
- **Branching Logic (`params.assembler`)**:
  - `'megahit'`: Short-read ultra-fast de novo assembly via `MEGAHIT`.
  - `'flye'`: Long-read assembly via `FLYE` with `--meta` and `--nano-hq` / `--nano-raw` mode.
  - `'opera_ms'`: Hybrid co-assembly integrating short and long reads via `OPERA_MS`.
- **Outputs**:
  - `contigs`: Assembled contigs `[ meta, contigs.fa ]`.

---

### 4. `workflows/polishing.nf`
- **Purpose**: Error correction of assembled contigs to repair frameshifts and base inaccuracies.
- **Inputs**:
  - `ch_contigs`: Raw assembly contigs.
  - `ch_reads`: Sequencing reads for polishing.
- **Branching Logic (`params.polisher`)**:
  - `'racon'`: Long-read alignment and consensus polishing via `RACON_MEDAKA`.
  - `'nextpolish'`: Short-read k-mer/alignment-based polishing via `NEXTPOLISH`.
- **Outputs**:
  - `contigs`: Polished contig fasta file `[ meta, polished_contigs.fa ]`.

---

### 5. `workflows/assembly_qc.nf`
- **Purpose**: Assembly quality evaluation and contiguity metrics.
- **Inputs**: `ch_contigs`
- **Sub-processes**:
  - `QUAST`: Computes N50, L50, total length, GC content, and largest contig statistics.
- **Outputs**:
  - `html`: Interactive QUAST HTML report.
  - `tsv`: Tabular metric summary (`report.tsv`).
  - `dir`: Complete QUAST output directory.

---

### 6. `workflows/mapping.nf`
- **Purpose**: Map short and/or long reads back to contigs and calculate depth coverage across samples.
- **Inputs**:
  - `ch_contigs`, `ch_short_reads`, `ch_long_reads`
- **Sub-processes**:
  - `MAP_SHORT_READS`: Bowtie2/BWA-MEM2 indexing, paired-end mapping, coordinate sorting, and indexing (`samtools sort`).
  - `MAP_LONG_READS`: Minimap2 long-read alignment (`-ax map-ont`), coordinate sorting, and indexing.
  - `ALIGN_READS_TO_CONTIGS`: Runs `jgi_summarize_bam_contig_depths` to calculate mean coverage depth and variance per contig.
- **Outputs**:
  - `bam`: Sorted BAM alignments `[ meta, bam ]`.
  - `bai`: BAM index files `[ meta, bai ]`.
  - `depth`: MetaBAT2 depth table `[ meta, depth.txt ]`.

---

### 7. `workflows/binning.nf`
- **Purpose**: Reconstruct Metagenome-Assembled Genomes (MAGs) using multiple binners and consensus refinement.
- **Inputs**:
  - `ch_contigs`, `ch_bam`, `ch_bai`, `ch_depth`
- **Sub-processes**:
  - `METABAT2`: Tetranucleotide frequency and abundance-based binning.
  - `MAXBIN2` (*optional*): Marker-gene and depth-based binning.
  - `SEMIBIN2` (*optional*): Deep learning single-sample and multi-sample binning.
  - `CONCOCT` (*optional*): Gaussian mixture model contig binning.
  - `DASTOOL`: Dereplication and scoring to identify consensus, non-redundant MAG bins.
  - `CAT_BINS`: Standardizes bin file names, calculates bin statistics, and compiles `bins_summary.tsv`.
- **Outputs**:
  - `bins`: Channel of individual MAG FASTA files `[ meta, bin_fastas ]`.
  - `bins_dir`: Directory containing all consolidated MAGs `[ meta, final_bins/ ]`.
  - `summary`: Tabular MAG count and size summary `[ meta, bins_summary.tsv ]`.

---

### 8. `workflows/mag_qc.nf`
- **Purpose**: Quality scoring, contamination assessment, and taxonomic classification of recovered MAGs.
- **Inputs**: `ch_bins_dir`
- **Sub-processes**:
  - `CHECKM2`: Machine-learning based completeness and contamination estimation.
  - `GUNC`: Gene-based chimerism and taxonomic heterogeneity detection.
  - `GTDBTK`: Genome Taxonomy Database phylogenetic placement and classification.
- **Outputs**:
  - `checkm2_report`: CheckM2 completeness and contamination TSV.
  - `gunc_report`: GUNC chimerism detection TSV.
  - `gtdbtk_summary`: GTDB-Tk taxonomic summary table.

---

### 9. `workflows/assembly_free.nf`
- **Purpose**: Direct read-based taxonomic and metabolic profiling.
- **Inputs**: `ch_short_reads`
- **Sub-processes**:
  - `KRAKEN2`: Exact k-mer taxonomic classification against Kraken 2 reference database.
  - `BRACKEN`: Bayesian re-estimation of species/genus abundance.
  - `KRONA`: Interactive multi-layered radial visualization of taxonomic profiles.
  - `KRAKEN_BIOM` (via `bin/kraken_to_biom.py`): Converts taxonomic reports to standard BIOM 1.0 JSON format.
  - `HUMANN3`: Pathway abundance and UniRef gene family profiling.
- **Outputs**:
  - `kraken_report`: Kraken 2 taxonomic summary `[ meta, kraken2_report.txt ]`.
  - `bracken_report`: Bracken species abundance table.
  - `krona_html`: Interactive Krona chart HTML.
  - `biom`: BIOM 1.0 JSON taxonomy file.
  - `humann_genefamilies`, `humann_pathabundance`: Metabolic pathway matrices.

---

### 10. `workflows/annotation.nf`
- **Purpose**: Structural, functional, and viral/plasmid sequence annotation.
- **Inputs**: `ch_contigs`
- **Sub-processes**:
  - `PROKKA`: Rapid prokaryotic genome annotation (CDS, tRNA, rRNA, CRISPRs).
  - `GENOMAD`: Neural-network based identification of proviruses, plasmids, and giant viruses.
- **Outputs**:
  - `gff`: General Feature Format annotation `[ meta, sample.gff ]`.
  - `faa`: Translated protein FASTA `[ meta, sample.faa ]`.
  - `fna`: Nucleotide transcript FASTA `[ meta, sample.fna ]`.
  - `genomad_summary`: geNomad virus and plasmid classification tables.

---

### 11. `workflows/reporting.nf`
- **Purpose**: Multi-tool metric aggregation and final interactive reporting.
- **Inputs**:
  - `ch_multiqc_files`: Channel of all generated QC logs.
  - `ch_quast_tsv`: QUAST assembly quality metrics.
  - `ch_bins_summary`: Reconstructed MAG statistics.
  - `ch_kraken_report`: Taxonomic classification results.
- **Sub-processes**:
  - `MULTIQC`: Aggregates FastQC, fastp, Bowtie2, and QUAST logs into a unified dashboard.
  - `GENERATE_REPORTS`: Invokes `bin/generate_report.py` using `templates/report.html` and `templates/summary.md` to produce per-sample interactive HTML dashboards and Markdown summaries.
- **Outputs**:
  - `multiqc_html`: `multiqc_report.html`.
  - `report_html`: Per-sample HTML report `[ meta, sample_pipeline_report.html ]`.
  - `summary_md`: Per-sample Markdown report `[ meta, sample_summary.md ]`.

---

## 4. Module Layer Index (35 Discrete Modules)

All modules reside under `modules/local/` and use pinned biocontainers:

| Module | Process Name | Pinned Container Image | Responsibility |
|---|---|---|---|
| `fastqc` | `FASTQC` | `quay.io/biocontainers/fastqc:0.12.1--hdfd78af_0` | Short-read quality control |
| `fastp` | `FASTP` | `quay.io/biocontainers/fastp:0.23.4--hadf994f_2` | Short-read trimming & filtering |
| `dorado_basecall` | `DORADO_BASECALL` | `community.wave.seqera.io/library/samtools_ont-dorado-server:7e66dfc15cae4cbe` | ONT GPU basecalling |
| `nanoplot` | `NANOPLOT` | `quay.io/biocontainers/nanoplot:1.42.0--pyhdfd78af_0` | Long-read quality statistics |
| `porechop_abi` | `PORECHOP_ABI` | `quay.io/biocontainers/porechop_abi:0.5.0--py310h30d9ebd_2` | ONT adapter trimming |
| `filtlong` | `FILTLONG` | `quay.io/biocontainers/filtlong:0.2.1--h9a82719_1` | Long-read length/quality filter |
| `bowtie2_host_removal` | `BOWTIE2_HOST_REMOVAL` | `community.wave.seqera.io/library/bowtie2_htslib_samtools_pigz:edeb13799090a2a6` | Short-read host decontamination |
| `minimap2_host_removal` | `MINIMAP2_HOST_REMOVAL` | `community.wave.seqera.io/library/minimap2_samtools:b09096fc890429ce` | Long-read host decontamination |
| `megahit` | `MEGAHIT` | `quay.io/biocontainers/megahit:1.2.9--h2e03b76_1` | Short-read metagenomic assembly |
| `flye` | `FLYE` | `quay.io/biocontainers/flye:2.9.2--py310h2b6aa90_2` | Long-read metagenomic assembly |
| `opera_ms` | `OPERA_MS` | `community.wave.seqera.io/library/opera-ms:4.0--f4ae1b9952df0c10` | Hybrid short+long read assembly |
| `racon_medaka` | `RACON_MEDAKA` | `community.wave.seqera.io/library/minimap2_racon_samtools:540f3532b273b5ee` | Long-read consensus polishing |
| `nextpolish` | `NEXTPOLISH` | `community.wave.seqera.io/library/bwa_nextpolish_samtools:10c85c2c77d6ba4b` | Short-read k-mer polishing |
| `quast` | `QUAST` | `quay.io/biocontainers/quast:5.2.0--py39pl5321h2add14b_1` | Assembly quality evaluation |
| `map_short_reads` | `MAP_SHORT_READS` | `community.wave.seqera.io/library/bowtie2_htslib_samtools_pigz:edeb13799090a2a6` | Map short reads to contigs |
| `map_long_reads` | `MAP_LONG_READS` | `community.wave.seqera.io/library/minimap2_samtools:b09096fc890429ce` | Map long reads to contigs |
| `align_reads_to_contigs` | `ALIGN_READS_TO_CONTIGS`| `quay.io/biocontainers/metabat2:2.15--h984e79f_2` | Calculate contig depth table |
| `metabat2` | `METABAT2` | `quay.io/biocontainers/metabat2:2.15--h984e79f_2` | MetaBAT2 binning |
| `maxbin2` | `MAXBIN2` | `quay.io/biocontainers/maxbin2:2.2.7--hdbdd923_5` | MaxBin2 binning |
| `semibin2` | `SEMIBIN2` | `quay.io/biocontainers/semibin:2.1.0--pyhdfd78af_0` | SemiBin2 deep-learning binning |
| `concoct` | `CONCOCT` | `quay.io/biocontainers/concoct:1.1.0--py38h2452295_4` | CONCOCT GMM binning |
| `dastool` | `DASTOOL` | `quay.io/biocontainers/das_tool:1.1.6--r42hdfd78af_0` | DAS Tool consensus bin selection |
| `cat_bins` | `CAT_BINS` | `quay.io/biocontainers/python:3.10` | Standardize and summarize bins |
| `checkm2` | `CHECKM2` | `quay.io/biocontainers/checkm2:1.0.2--pyh7cba7a3_0` | CheckM2 MAG quality scoring |
| `gunc` | `GUNC` | `quay.io/biocontainers/gunc:1.0.5--pyhdfd78af_0` | GUNC MAG chimerism detection |
| `gtdbtk` | `GTDBTK` | `quay.io/biocontainers/gtdbtk:2.3.2--pyhdfd78af_0` | GTDB-Tk taxonomic assignment |
| `kraken2` | `KRAKEN2` | `quay.io/biocontainers/kraken2:2.1.6--pl5321h077b44d_0` | K-mer taxonomic classification |
| `bracken` | `BRACKEN` | `quay.io/biocontainers/bracken:3.0--h9948957_2` | Abundance re-estimation |
| `kraken_biom` | `KRAKEN_BIOM` | `quay.io/biocontainers/kraken-biom:1.2.0--pyh5e36f6f_0` | BIOM 1.0 JSON format export |
| `krona` | `KRONA` | `quay.io/biocontainers/krona:2.7.1--pl526_0` | Radial taxonomic visualization |
| `humann3` | `HUMANN3` | `quay.io/biocontainers/humann:3.8--pyh7cba7a3_0` | Functional metabolic profiling |
| `prokka` | `PROKKA` | `quay.io/biocontainers/prokka:1.14.6--pl5321hdfd78af_5` | Prokaryotic genome annotation |
| `genomad` | `GENOMAD` | `quay.io/biocontainers/genomad:1.8.1--pyhdfd78af_0` | Plasmid and viral annotation |
| `multiqc` | `MULTIQC` | `quay.io/biocontainers/multiqc:1.35--pyhdfd78af_0` | Multi-tool QC aggregation |
| `generate_reports` | `GENERATE_REPORTS` | `quay.io/biocontainers/python:3.10` | HTML/MD report compilation |

---

## 5. Script & Helper Layer

### 1. `lib/Utils.groovy`
- Encapsulates reusable utility logic.
- `Utils.headerBanner()`: Returns formatted ASCII pipeline header banner.
- `Utils.logParameters(params)`: Pretty-prints execution parameters.

### 2. `lib/Samplesheet.groovy`
- Validates CSV headers (ensuring `sample` column exists).
- Parses individual rows into maps and checks for missing sample identifiers.

### 3. `lib/Validation.groovy`
- Performs pre-flight parameter verification.
- Validates `--input` existence before task scheduling.

### 4. `bin/generate_report.py`
- Python 3 CLI leveraging standard libraries (`jinja2` optional, regex/html parsing built-in).
- Dynamically parses QUAST metrics, binning statistics, and Kraken 2 taxonomic abundance.
- Populates Jinja2 templates into standalone, self-contained HTML and Markdown documents.

### 5. `bin/kraken_to_biom.py`
- Parses Kraken2 and Bracken tabular reports.
- Constructs hierarchical taxonomic lineages (`d__;p__;c__;o__;f__;g__;s__`).
- Exports compliant BIOM 1.0 JSON format and TSV abundance matrices.

---

## 6. How to Extend the Framework

### Adding a New Tool Module
1. Create a new directory under `modules/local/<tool_name>/main.nf`.
2. Define `process TOOL_NAME { ... }` with a pinned container, input/output declarations, and shell script.
3. Add the module to the appropriate workflow under `workflows/`.
4. Define parameter defaults in `nextflow.config` and presets in `params/*.yaml`.
5. Write a test case in `test/test_phase<N>.nf`.

### Example Module Template

```groovy
process MY_TOOL {
    tag "$meta.id"
    label 'process_medium'

    container 'quay.io/biocontainers/mytool:1.0.0--py_0'

    input:
    tuple val(meta), path(reads)

    output:
    tuple val(meta), path("*.tsv"), emit: tsv

    script:
    def prefix = task.ext.prefix ?: "${meta.id}"
    """
    mytool \\
        --input ${reads} \\
        --threads ${task.cpus} \\
        --out ${prefix}_output.tsv
    """
}
```
