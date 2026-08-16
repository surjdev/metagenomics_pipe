# Pipeline Outputs Guide

This document describes all outputs produced by the **Hybrid Metagenomics Pipeline**, organized by analytical stage.

---

## Output Directory Layout

```
results/
├── 01_preprocessing/
│   ├── fastqc/                  # Raw & clean FastQC HTML & ZIP reports
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

## Detailed File Descriptions

### 1. Preprocessing (`01_preprocessing/`)
- `*_fastqc.html`: Per-base quality, GC distribution, adapter content before and after trimming.
- `*.fastp.json`: JSON report detailing input read count, duplication rate, trimmed bases, and surviving reads.
- `*.NanoStats.txt`: N50, mean read length, median Q-score, and total bases for long reads.

### 2. Host Removal (`02_host_removal/`)
- `*_nonhost_R1.fastq.gz`, `*_nonhost_R2.fastq.gz`: Decontaminated microbial short reads.
- `*_nonhost.fastq.gz`: Decontaminated microbial long reads.
- `*.flagstat`: Samtools flagstat indicating total reads vs. host-aligned reads.

### 3. Assembly & QC (`03_assembly/`, `04_polishing/`, `05_assembly_qc/`)
- `*.contigs.fa`: De novo assembled contigs from MEGAHIT, Flye, or Opera-MS.
- `quast/report.html`: Interactive assembly contiguity dashboard.
- `quast/report.tsv`: Tab-delimited metrics: N50, N75, L50, total length, GC percentage, contig count.

### 4. Binning & MAG QC (`07_binning/`, `08_mag_qc/`)
- `final_bins/*.fa`: Individual reconstructed Metagenome-Assembled Genomes.
- `bins_summary.tsv`: Table listing MAG ID, total contig count, total bp length, and N50.
- `checkm2/quality_report.tsv`: Machine learning completeness (%), contamination (%), and strain heterogeneity.
- `gunc/GUNC.progenomes_2.1.max_css_level.tsv`: GUNC contamination and clade separation scores.
- `gtdbtk.bac120.summary.tsv`: GTDB-Tk domain, phylum, class, order, family, genus, and species assignment.

### 5. Read-Based Analysis (`09_assembly_free/`)
- `*.kraken2_report.txt`: Standard 6-column Kraken 2 report.
- `*.bracken.tsv`: Bracken estimated read counts, fractions, and assigned taxonomies.
- `*.krona.html`: Interactive multi-layered radial pie chart of microbial community taxonomy.
- `*_taxonomy.biom`: BIOM 1.0 JSON format matrix compatible with QIIME 2, phyloseq, and microbiome analysis packages.

### 6. Annotation & Final Reporting (`10_annotation/`, `11_reporting/`)
- `*.gff`: Annotated features with genomic coordinates.
- `*.faa`: Translated protein coding sequences.
- `multiqc_report.html`: Consolidated MultiQC execution report.
- `*_pipeline_report.html`: Dedicated standalone interactive HTML dashboard containing sample KPIs, assembly quality, binning yield, and stage completion statuses.
