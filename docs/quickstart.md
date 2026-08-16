# Quickstart Guide

This quickstart guide walks you through running your first analysis with the **Hybrid Metagenomics Pipeline**.

---

## 1. Quick Verification Run

To verify that Nextflow and your container runtime are properly installed, run the built-in synthetic test dataset:

```bash
nextflow run main.nf -profile docker,test
```

Or on an HPC cluster with Singularity:

```bash
nextflow run main.nf -profile singularity,test
```

The test dataset exercises all 11 pipeline stages with synthetic short and long reads in under 2 minutes.

---

## 2. Prepare Your Data

### Step 1: Create a Samplesheet

Create a CSV file named `samplesheet.csv` listing your sequencing samples:

```csv
sample,fastq_1,fastq_2,long_reads,platform
SAMPLE001,/data/reads/SAMPLE001_R1.fastq.gz,/data/reads/SAMPLE001_R2.fastq.gz,/data/reads/SAMPLE001_nanopore.fastq.gz,hybrid
SAMPLE002,/data/reads/SAMPLE002_R1.fastq.gz,/data/reads/SAMPLE002_R2.fastq.gz,,illumina
SAMPLE003,,,/data/reads/SAMPLE003_nanopore.fastq.gz,nanopore
```

---

## 3. Run the Pipeline

### Illumina Short-Read Profiling & Assembly

```bash
nextflow run main.nf \
    -profile docker \
    -params-file params/illumina.yaml \
    --input samplesheet.csv \
    --kraken2_db /data/databases/kraken2 \
    --outdir ./results
```

### Oxford Nanopore Long-Read Assembly & Profiling

```bash
nextflow run main.nf \
    -profile docker \
    -params-file params/nanopore.yaml \
    --input samplesheet.csv \
    --kraken2_db /data/databases/kraken2 \
    --outdir ./results
```

### Hybrid Co-Assembly & MAG Reconstruction

```bash
nextflow run main.nf \
    -profile slurm,singularity \
    -params-file params/hybrid.yaml \
    -params-file params/databases.yaml \
    --input samplesheet.csv \
    --outdir ./results
```

---

## 4. Reviewing Results

Once complete, open the generated HTML reports:
- Consolidated QC Dashboard: `results/11_reporting/multiqc_report.html`
- Interactive Pipeline Report: `results/11_reporting/SAMPLE001_pipeline_report.html`
- Summary Markdown: `results/11_reporting/SAMPLE001_summary.md`
- Taxonomic Krona Chart: `results/09_assembly_free/krona/SAMPLE001.krona.html`
