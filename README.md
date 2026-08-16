# Hybrid Metagenomics Pipeline

[![Nextflow](https://img.shields.io/badge/Nextflow-DSL2-brightgreen.svg)](https://www.nextflow.io/)
[![Container Engine](https://img.shields.io/badge/Containers-Docker%20%7C%20Singularity%20%7C%20Apptainer-blue.svg)](https://singularity-tutorial.github.io/)
[![HPC Support](https://img.shields.io/badge/HPC-SLURM%20Ready-orange.svg)](https://slurm.schedmd.com/)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)

A production-ready, HPC-first **Nextflow DSL2 software framework** for end-to-end hybrid (Illumina short-read + Oxford Nanopore long-read) shotgun metagenomic analysis. 

Rather than a static script collection, this framework is built around **strict 5-layer separation of concerns**, allowing any bioinformatics tool (assemblers, binners, taxonomic profilers, annotators) to be swapped, updated, or tested independently without modifying pipeline orchestration logic.

---

## 🌟 Key Features

- **Multi-Platform Support**: Seamlessly analyzes **Illumina paired-end**, **Oxford Nanopore long-reads**, or combined **Hybrid short+long read** datasets.
- **Strict 5-Layer Architecture**: Clear separation between Application (`main.nf`), Workflows (`workflows/`), Modules (`modules/local/`), Scripts (`lib/`, `bin/`), and Infrastructure (`conf/`, `params/`).
- **Comprehensive 11-Stage Workflow**:
  1. **Preprocessing & QC**: FastQC, fastp, NanoPlot, Dorado basecalling, Porechop-ABI, Filtlong.
  2. **Host Decontamination**: Bowtie2 (short reads) and Minimap2 (long reads) decontamination against host reference.
  3. **Multi-Assembler Support**: MEGAHIT (short reads), Flye (long reads), or Opera-MS (hybrid short+long reads).
  4. **Assembly Polishing**: Racon/Medaka (long reads) and NextPolish (short reads).
  5. **Assembly Quality Assessment**: QUAST contig statistics, N50, and GC metrics.
  6. **Read Mapping & Depth Coverage**: BWA-MEM2 / Bowtie2, Minimap2, Samtools, and MetaBAT2 depth profiling.
  7. **Multi-Binner Consensus Recovery**: MetaBAT2, MaxBin2, SemiBin2, and CONCOCT binned contigs consolidated via DAS Tool and standardized via CAT_BINS.
  8. **MAG Quality & Taxonomy**: CheckM2 completeness/contamination scoring, GUNC chimerism detection, and GTDB-Tk taxonomic assignment.
  9. **Assembly-Free Read Profiling**: Kraken 2 taxonomic classification, Bracken abundance re-estimation, Krona interactive visualization, BIOM 1.0 JSON export, and HUMAnN 3 functional profiling.
  10. **Structural & Mobile Element Annotation**: Prokka gene annotation and geNomad plasmid / provirus / giant virus identification.
  11. **Aggregated Reporting**: MultiQC aggregate dashboard and custom interactive Jinja2 HTML + Markdown summary reports.
- **HPC & Cloud Ready**: Fully containerized using biocontainers with pinned tags (`tool:version`) and profiles for SLURM, Singularity/Apptainer, and Docker.

---

## 🏗️ 5-Layer Architecture

```
Application Layer    ──▶  main.nf                      (orchestrates subworkflows only)
Workflow Layer       ──▶  workflows/*.nf               (connects modules into stage pipelines)
Module Layer         ──▶  modules/local/<tool>/main.nf (one process = one tool, containerized)
Script Layer         ──▶  lib/*.groovy, bin/*.py       (validation, helper utilities, report CLI)
Infrastructure       ──▶  conf/*.config, params/*.yaml (resource allocations, execution profiles)
```

| Layer | Responsibility | Allowed Calls |
|---|---|---|
| **Application Layer** (`main.nf`) | Entry point, pre-flight checks, samplesheet dispatch | `workflows/` only |
| **Workflow Layer** (`workflows/*.nf`) | Connects modules for a specific analytical phase | `modules/` only |
| **Module Layer** (`modules/local/*/main.nf`) | Executes individual command-line bioinformatics tools | Shell/container only |
| **Script Layer** (`lib/`, `bin/`) | Helper Groovy classes and Python standalone CLI scripts | Stdlib only |
| **Infrastructure Layer** (`conf/`, `params/`) | Execution profiles and YAML parameter presets | No bioinformatics logic |

---

## 🚀 Quickstart

### 1. Prerequisites

- [Nextflow](https://www.nextflow.io/) (version `>= 22.10.0`)
- [Docker](https://www.docker.com/) OR [Singularity / Apptainer](https://apptainer.org/)
- Java 11 or later

### 2. Run Test Dataset

Verify your installation with the built-in synthetic test dataset and Docker profile (runs in ~1 minute):

```bash
nextflow run main.nf -profile docker,test
```

Or run with Singularity / Apptainer on HPC:

```bash
nextflow run main.nf -profile singularity,test
```

---

## 📋 Input Samplesheet Format

Prepare a CSV samplesheet specifying your input sequencing reads (`samplesheet.csv`):

```csv
sample,fastq_1,fastq_2,long_reads,platform
SAMPLE001,/path/to/sample1_R1.fastq.gz,/path/to/sample1_R2.fastq.gz,/path/to/sample1_nanopore.fastq.gz,hybrid
SAMPLE002,/path/to/sample2_R1.fastq.gz,/path/to/sample2_R2.fastq.gz,,illumina
SAMPLE003,,,/path/to/sample3_nanopore.fastq.gz,nanopore
```

### Samplesheet Columns

- `sample` (**required**): Unique sample identifier (e.g. `SAMPLE001`).
- `fastq_1` (*optional for long-read only*): Absolute path to Illumina Forward (R1) FASTQ.
- `fastq_2` (*optional for long-read only*): Absolute path to Illumina Reverse (R2) FASTQ.
- `long_reads` / `long_fastq` (*optional for short-read only*): Absolute path to Oxford Nanopore FASTQ.
- `platform`: `illumina`, `nanopore`, or `hybrid`.

---

## 💻 Running the Pipeline

### Production Run on SLURM HPC Cluster (with Singularity)

```bash
nextflow run main.nf \
    -profile slurm,singularity \
    -params-file params/hybrid.yaml \
    -params-file params/databases.yaml \
    --input /path/to/samplesheet.csv \
    --outdir ./results
```

### Production Run with Docker (Local Workstation)

```bash
nextflow run main.nf \
    -profile docker \
    -params-file params/illumina.yaml \
    -params-file params/databases.yaml \
    --input /path/to/samplesheet.csv \
    --outdir ./results
```

### Parameter Presets

Pre-configured YAML presets are available in `params/`:
- `params/illumina.yaml`: Optimized for short-read Illumina datasets (MEGAHIT, NextPolish, short-read mapping).
- `params/nanopore.yaml`: Optimized for long-read ONT datasets (Flye, Racon/Medaka, Minimap2).
- `params/hybrid.yaml`: Optimized for co-assembled or hybrid datasets (Opera-MS, hybrid binning).
- `params/databases.yaml`: Paths to reference databases (Host, Kraken2, GTDB-Tk, CheckM2, etc.).

---

## 🗂️ Pipeline Stage Overview

```
                      ┌───────────────────────────────────────┐
                      │            samplesheet.csv            │
                      └───────────────────┬───────────────────┘
                                          │
                  ┌───────────────────────┴───────────────────────┐
                  ▼                                               ▼
     ┌────────────────────────┐                       ┌────────────────────────┐
     │ 1. Short-Read Preproc  │                       │  1. Long-Read Preproc  │
     │ FastQC ──▶ fastp       │                       │ NanoPlot ──▶ Filtlong  │
     └───────────┬────────────┘                       └───────────┬────────────┘
                 │                                                │
                 ▼                                                ▼
     ┌────────────────────────┐                       ┌────────────────────────┐
     │ 2. Host Removal        │                       │ 2. Host Removal        │
     │ Bowtie2 (GRCh38)       │                       │ Minimap2 (GRCh38)      │
     └───────────┬────────────┘                       └───────────┬────────────┘
                 │                                                │
                 ├────────────────────────┬───────────────────────┤
                 ▼                        ▼                       ▼
    ┌─────────────────────────┐  ┌─────────────────┐  ┌─────────────────────────┐
    │ 9. Read Profiling       │  │ 3. Assembly     │  │ 3. Assembly             │
    │ Kraken2 ──▶ Bracken     │  │ MEGAHIT / Flye  │  │ Opera-MS (Hybrid)       │
    │ Krona ──▶ BIOM 1.0 JSON │  └────────┬────────┘  └───────────┬─────────────┘
    └─────────────────────────┘           │                       │
                                          └───────────┬───────────┘
                                                      ▼
                                         ┌─────────────────────────┐
                                         │ 4. Polishing & 5. QC    │
                                         │ NextPolish / Racon      │
                                         │ QUAST Contig Metrics    │
                                         └────────────┬────────────┘
                                                      │
                                                      ▼
                                         ┌─────────────────────────┐
                                         │ 6. Mapping & Coverage   │
                                         │ Samtools & MetaBAT2 cov │
                                         └────────────┬────────────┘
                                                      │
                                                      ▼
                                         ┌─────────────────────────┐
                                         │ 7. Binning (Consensus)  │
                                         │ MetaBAT2 / MaxBin2 /    │
                                         │ SemiBin2 / CONCOCT      │
                                         │ ──▶ DAS Tool Consensus  │
                                         └────────────┬────────────┘
                                                      │
                                                      ▼
                                         ┌─────────────────────────┐
                                         │ 8. MAG QC & Taxonomy    │
                                         │ CheckM2 ──▶ GUNC        │
                                         │ ──▶ GTDB-Tk Taxonomy    │
                                         └────────────┬────────────┘
                                                      │
                                                      ▼
                                         ┌─────────────────────────┐
                                         │ 10. Annotation          │
                                         │ Prokka (CDS/tRNA/rRNA)  │
                                         │ geNomad (Virus/Plasmid) │
                                         └────────────┬────────────┘
                                                      │
                                                      ▼
                                         ┌─────────────────────────┐
                                         │ 11. Final Reporting     │
                                         │ MultiQC + HTML / MD     │
                                         └─────────────────────────┘
```

---

## 📊 Output Directory Structure

Results are organized into clean, structured subdirectories:

```
results/
├── 01_preprocessing/
│   ├── fastqc/                  # Raw and trimmed FastQC HTML/ZIP reports
│   ├── fastp/                   # fastp trimming JSON & HTML reports
│   └── nanoplot/                # NanoPlot long-read summary plots & stats
├── 02_host_removal/
│   ├── nonhost_reads/           # Host-filtered microbial FASTQ files
│   └── stats/                   # Alignment flagstats (% host reads removed)
├── 03_assembly/
│   ├── contigs/                 # Assembled contigs (MEGAHIT / Flye / Opera-MS)
│   └── logs/                    # Assembler execution logs
├── 04_polishing/
│   └── polished_contigs/        # Racon / NextPolish polished assemblies
├── 05_assembly_qc/
│   └── quast/                   # QUAST HTML report and TSV metrics (N50, GC)
├── 06_mapping/
│   ├── bams/                    # Sorted coordinate BAM and BAI files
│   └── depth/                   # MetaBAT2 depth matrix table
├── 07_binning/
│   ├── raw_bins/                # Per-binner FASTA bins (MetaBAT2, SemiBin2, etc.)
│   ├── dastool/                 # DAS Tool refined consensus MAGs
│   └── final_bins/              # Standardized MAG bins & bins_summary.tsv
├── 08_mag_qc/
│   ├── checkm2/                 # Completeness and contamination quality scores
│   ├── gunc/                    # Chimerism and contamination detection tables
│   └── gtdbtk/                  # Taxonomic classification summaries
├── 09_assembly_free/
│   ├── kraken2/                 # Kraken 2 taxonomic classification reports
│   ├── bracken/                 # Bracken species/genus abundance tables
│   ├── krona/                   # Interactive Krona taxonomic HTML charts
│   ├── biom/                    # BIOM 1.0 JSON taxonomic matrix
│   └── humann3/                 # Pathway abundance & gene families
├── 10_annotation/
│   ├── prokka/                  # Annotated GFF, FAA, FNA, and GBK files
│   └── genomad/                 # Identified plasmid and viral sequences
└── 11_reporting/
    ├── multiqc_report.html      # MultiQC consolidated dashboard
    ├── SAMPLE_pipeline_report.html # Interactive per-sample HTML report
    └── SAMPLE_summary.md        # Summary Markdown report
```

---

## 🗄️ Reference Databases

Download reference databases automatically using [`databases/download.sh`](databases/download.sh):

```bash
chmod +x databases/download.sh

# Download specific databases
./databases/download.sh --host /path/to/databases/host
./databases/download.sh --kraken2 /path/to/databases/kraken2
./databases/download.sh --checkm2 /path/to/databases/checkm2
./databases/download.sh --genomad /path/to/databases/genomad

# Or download all databases
./databases/download.sh --all /path/to/databases
```

Configure your database paths in `params/databases.yaml`.

---

## 📖 Detailed Documentation

- [Quickstart Guide](docs/quickstart.md) — Step-by-step tutorial for your first run.
- [Installation Guide](docs/installation.md) — Dependencies, container engines, and SLURM setup.
- [Code Architecture](docs/architecture.md) — In-depth guide to the 5 layers, DSL2 workflows, and channel dataflows.
- [Pipeline Outputs](docs/outputs.md) — Detailed description of generated files and metrics.
- [Developer Guide](docs/developer.md) — How to add modules, build workflows, and write tests.
- [Contributing](docs/contributing.md) — Guidelines for code contributions and testing.

---

## 📜 Citations & Tools

This framework integrates the following open-source bioinformatics software:

- **Nextflow**: Di Tommaso et al. (2017). *Nature Biotechnology*, 35(4), 316-319.
- **FastQC**: Andrews, S. (2010). Babraham Bioinformatics.
- **fastp**: Chen et al. (2018). *Bioinformatics*, 34(17), i884-i890.
- **Bowtie 2**: Langmead & Salzberg (2012). *Nature Methods*, 9(4), 357-359.
- **Minimap2**: Li, H. (2018). *Bioinformatics*, 34(18), 3094-3100.
- **MEGAHIT**: Li et al. (2015). *Bioinformatics*, 31(10), 1674-1676.
- **Flye**: Kolmogorov et al. (2020). *Nature Methods*, 17(11), 1103-1110.
- **Opera-MS**: Bertrand et al. (2019). *Nature Biotechnology*, 37(8), 938-944.
- **Racon**: Vaser et al. (2017). *Genome Research*, 27(5), 737-746.
- **NextPolish**: Hu et al. (2020). *Bioinformatics*, 36(7), 2255-2257.
- **QUAST**: Gurevich et al. (2013). *Bioinformatics*, 29(8), 1072-1075.
- **MetaBAT 2**: Kang et al. (2019). *PeerJ*, 7, e7359.
- **MaxBin 2**: Wu et al. (2016). *Bioinformatics*, 32(4), 605-607.
- **SemiBin 2**: Pan et al. (2023). *Nature Communications*, 14(1), 6980.
- **CONCOCT**: Alneberg et al. (2014). *Nature Methods*, 11(11), 1144-1146.
- **DAS Tool**: Sieber et al. (2018). *Nature Microbiology*, 3(7), 836-843.
- **CheckM2**: Chklovski et al. (2023). *Nature Methods*, 20(8), 1203-1212.
- **GUNC**: Orakov et al. (2021). *Genome Biology*, 22(1), 142.
- **GTDB-Tk**: Chaumeil et al. (2022). *Bioinformatics*, 38(19), 4618-4620.
- **Kraken 2**: Wood et al. (2019). *Genome Biology*, 20(1), 257.
- **Bracken**: Lu et al. (2017). *PeerJ Computer Science*, 3, e104.
- **Krona**: Ondov et al. (2011). *BMC Bioinformatics*, 12(1), 385.
- **HUMAnN 3**: Beghini et al. (2021). *eLife*, 10, e65088.
- **Prokka**: Seemann, T. (2014). *Bioinformatics*, 30(14), 2068-2069.
- **geNomad**: Camargo et al. (2023). *Nature Biotechnology*, 42, 608-618.
- **MultiQC**: Ewels et al. (2016). *Bioinformatics*, 32(19), 3047-3048.

---

## ⚖️ License

Distributed under the MIT License. See `LICENSE` for more information.
