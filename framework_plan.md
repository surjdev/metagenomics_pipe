# Hybrid Metagenomics Nextflow DSL2 Framework
## High-Level Software Architecture & Developer Guide

**Version:** 1.0 (Architecture Design)

**Target**
- Production-ready
- HPC-first (SLURM)
- Nextflow DSL2
- Modular
- Open-source
- Easy to extend
- Research reproducible

---

# 1. Philosophy

This project is **not a collection of bioinformatics tools**.

Instead, it is a **software framework** that orchestrates many bioinformatics tools into reproducible metagenomics workflows.

Every tool should be replaceable without changing the entire pipeline.

Example

```
MEGAHIT
      ↓

can later become

metaSPAdes
```

without changing

- preprocessing
- reporting
- MAG analysis
- annotation

This is the reason every tool is isolated into an independent module.

---

# 2. High-Level Architecture

```
                        User
                          │
                          ▼
                 Sample Sheet + Config
                          │
                          ▼
                    Input Validation
                          │
                          ▼
                    Main Workflow
                          │
      ┌───────────────────┼────────────────────┐
      │                   │                    │
      ▼                   ▼                    ▼
Preprocessing      Assembly Branch     Read-based Branch
      │                   │                    │
      └───────────────────┼────────────────────┘
                          ▼
                 Report Aggregation
                          │
                          ▼
                    Final Report
```

---

# 3. Architecture Layers

```
Application Layer
──────────────────────────────
main.nf

Workflow Layer
──────────────────────────────
preprocessing.nf
assembly.nf
annotation.nf
reporting.nf

Module Layer
──────────────────────────────
FastQC
Fastp
Bowtie2
MEGAHIT
Flye
Kraken2
...

Script Layer
──────────────────────────────
Python
Bash
R

Infrastructure Layer
──────────────────────────────
SLURM
Singularity
Docker
Conda
```

---

# 4. AI Digest Architecture

Think of the project like a modern backend system.

```
Controller
↓

Workflow

↓

Service

↓

Tool

↓

Output
```

Equivalent mapping

```
Controller
↓

main.nf

Workflow
↓

assembly.nf

Service
↓

megahit.nf

Business Logic
↓

MEGAHIT executable

Database
↓

Generated files
```

Or another analogy:

```
Restaurant

Customer
↓

Manager
↓

Chef
↓

Kitchen Tool
↓

Food
```

Mapping

```
User
↓

main.nf

↓

workflow

↓

module

↓

bioinformatics tool

↓

results
```

Each component has **one responsibility**.

---

# 5. Project Structure

```
hybrid-metagenomics/

├── main.nf
├── nextflow.config
├── conf/
├── params/
├── workflows/
├── modules/
├── lib/
├── bin/
├── templates/
├── assets/
├── docs/
├── test/
├── databases/
└── results/
```

---

# 6. File-by-File Documentation

---

## main.nf

### Purpose

Main application entry point.

Equivalent to

```
main()
```

in C++ or Python.

### Responsibilities

- Load configuration
- Include workflows
- Connect workflows
- Define execution order

### Should NOT

- Execute shell commands
- Implement FastQC
- Implement Kraken2
- Parse BAM

It only orchestrates.

---

## nextflow.config

### Purpose

Global runtime configuration.

### Responsibilities

- Executor
- Memory
- CPU
- Container
- Cache
- Profiles

Example

```
executor = 'slurm'

cpus = 16

memory = '64 GB'
```

No biological logic belongs here.

---

# conf/

Purpose

Separate environment-specific settings.

```
conf/

base.config

slurm.config

singularity.config

docker.config

test.config
```

---

## base.config

Mission

Store default settings used by every environment.

Contains

- publishDir
- default CPUs
- retry policy
- cache
- error strategy

---

## slurm.config

Mission

Configure HPC execution.

Contains

- executor
- partition
- queue
- clusterOptions
- submit limits

---

## singularity.config

Mission

Configure containers.

Contains

- image path
- cache
- bind paths

---

## docker.config

Mission

Run locally using Docker.

---

## test.config

Mission

Small datasets for continuous testing.

---

# params/

Purpose

Store parameter presets.

Example

```
illumina.yaml

nanopore.yaml

hybrid.yaml

databases.yaml
```

Instead of writing

```
--quality 20

--adapter xxx

--threads 32

...
```

Users simply choose

```
hybrid.yaml
```

---

# workflows/

Purpose

Pipeline orchestration.

A workflow connects modules.

It never performs bioinformatics analysis directly.

Example

```
FASTQC

↓

Fastp

↓

Bowtie2
```

---

## preprocessing.nf

Mission

Convert raw sequencing data into clean reads.

Responsible for

- QC
- trimming
- filtering
- basecalling
- read statistics

---

## host_removal.nf

Mission

Remove host contamination.

Input

Clean FASTQ

Output

Microbial FASTQ

---

## assembly.nf

Mission

Construct genomes.

Chooses

- MEGAHIT
- Flye
- Opera-MS

depending on sequencing platform.

---

## polishing.nf

Mission

Improve assembly quality.

Runs

- Racon
- Medaka
- NextPolish

---

## assembly_qc.nf

Mission

Evaluate assembly quality.

Runs

- QUAST

Produces

- N50
- GC
- contig statistics

---

## mapping.nf

Mission

Map reads back to assembly.

Produces

- BAM
- depth
- coverage

---

## binning.nf

Mission

Generate MAGs.

Runs

- MetaBAT2
- MaxBin2
- SemiBin2
- CONCOCT
- DAS Tool

---

## mag_qc.nf

Mission

Evaluate MAG quality.

Runs

- CheckM2
- GUNC
- GTDB-Tk

---

## annotation.nf

Mission

Functional and taxonomic annotation.

Runs

- Prokka
- geNomad

---

## assembly_free.nf

Mission

Read-based analysis.

Runs

- Kraken2
- Bracken
- Krona
- HUMAnN3

---

## reporting.nf

Mission

Collect every output.

Generate

- HTML
- PDF
- TSV
- summary

---

## cat_bins.nf

Mission

Collect all the bins from different binning tools.

Generate

- combined bins
- bin summary

---

## kraken2_to_biom.nf

Mission

Convert Kraken2 output to BIOM format.

Generate

- BIOM file
- summary

---
# modules/

Purpose

The heart of the project.

Rule

One module

=

One bioinformatics tool

Example

```
fastqc.nf
```

Contains

```
process FASTQC
```

Nothing else.

Advantages

- reusable
- testable
- replaceable

---

## Module Responsibilities

```
fastqc.nf

Mission

Run FastQC only.
```

```
fastp.nf

Mission

Run fastp only.
```

```
bowtie2.nf

Mission

Host removal only.
```

```
megahit.nf

Mission

Assemble Illumina reads.
```

```
flye.nf

Mission

Assemble Nanopore reads.
```

Every module follows the same philosophy.

---

# lib/

Purpose

Reusable Groovy helper classes.

Contains

```
Utils.groovy

Samplesheet.groovy

Validation.groovy
```

These files never run bioinformatics software.

---

## Utils.groovy

Mission

General helper methods.

Examples

- filename utilities
- logging
- formatting
- path helpers

---

## Samplesheet.groovy

Mission

Read sample sheet.

Validate

- sample IDs
- paired-end files
- metadata

Return structured channels.

---

## Validation.groovy

Mission

Validate pipeline inputs.

Checks

- FASTQ exists
- database exists
- parameter values
- duplicate samples

Stop execution before wasting HPC resources.

---

# bin/

Purpose

Standalone scripts.

Examples

```
extract_nonhost.py

kraken_to_biom.py

generate_report.py
```

These scripts are executed from Nextflow modules.

Never executed directly by users.

---

# templates/

Purpose

Reusable report templates.

Examples

```
report.html

summary.md
```

---

# assets/

Purpose

Static resources.

Contains

- logo
- CSS
- workflow images
- icons

---

# docs/

Purpose

Documentation.

Suggested files

```
installation.md

quickstart.md

architecture.md

outputs.md

developer.md

contributing.md
```

---

# test/

Purpose

Automated testing.

Contains

```
tiny FASTQ

tiny assembly

small databases
```

Pipeline should finish within minutes.

---

# databases/

Purpose

Describe external database structure.

Contains

```
README.md

download.sh

database layout
```

No large databases are committed to Git.

---

# 7. Execution Flow

```
User

↓

main.nf

↓

workflow

↓

module

↓

Bioinformatics Tool

↓

Output Files

↓

Next Module

↓

Report
```

---

# 8. Software Design Principles

Every component follows these rules:

### Single Responsibility Principle

One module = one tool.

---

### Replaceability

Changing one tool should not require modifying unrelated workflows.

---

### Reusability

Modules should be reusable across different workflows.

---

### Testability

Every module must run independently with a small test dataset.

---

### Scalability

Designed for SLURM HPC, supporting thousands of samples through Nextflow's parallel execution model.

---

### Reproducibility

Results are deterministic through version-controlled code, fixed containers, parameter presets, and explicit workflow definitions.

---

# 9. Development Roadmap

## Phase 1 — Core Modules

- FastQC
- Fastp
- Dorado
- NanoPlot
- Porechop
- Filtlong
- Bowtie2
- Minimap2

---

## Phase 2 — Assembly

- MEGAHIT
- Flye
- Opera-MS
- Racon
- Medaka
- NextPolish
- QUAST

---

## Phase 3 — MAG Reconstruction

- Read Mapping
- Coverage
- MetaBAT2
- MaxBin2
- SemiBin2
- CONCOCT
- DAS Tool
- CheckM2
- GUNC
- GTDB-Tk

---

## Phase 4 — Read-Based Analysis

- Kraken2
- Bracken
- Krona
- HUMAnN3

---

## Phase 5 — Reporting

- MultiQC
- HTML report
- PDF report
- Interactive visualizations
- Final summary generation

---

# 10. Final Vision

The goal is to build a framework rather than a fixed pipeline.

The architecture should allow future contributors to add new sequencing technologies, assemblers, classifiers, or annotation tools by implementing a single module and plugging it into the appropriate workflow without modifying the rest of the system. This modular design ensures long-term maintainability, reproducibility, and community-driven extensibility while remaining suitable for production use on HPC environments.