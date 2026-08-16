# Reference Databases Guide

This directory documents the external reference databases utilized across the 11 stages of the Hybrid Metagenomics Pipeline.

> **Important**: Never commit database files to Git. Configure database locations via `params/databases.yaml` or command-line parameters (`--kraken2_db`, `--host_genome`, etc.).

---

## Database Overview

| Database | Target Workflow | Tool | Approx. Size | Source / URL |
|---|---|---|---|---|
| **Human Reference** | `host_removal.nf` | Bowtie2 / Minimap2 | ~3.2 GB | [NCBI GRCh38.p14](https://ftp.ncbi.nlm.nih.gov/genomes/all/GCA/000/001/405/GCA_000001405.29_GRCh38.p14/) |
| **Kraken 2 Standard / PlusPFP** | `assembly_free.nf` | Kraken2 / Bracken | ~16 GB (8GB Mini) to ~70 GB | [Ben Langmead AWS Indexes](https://benlangmead.github.io/aws-indexes/k2) |
| **CheckM2 Model DB** | `mag_qc.nf` | CheckM2 | ~3.5 GB | [CheckM2 Zenodo](https://zenodo.org/record/5571251) |
| **GTDB-Tk Reference DB** | `mag_qc.nf` | GTDB-Tk | ~110 GB (r220) | [GTDB-Tk Data](https://data.gtdb.ecogenomic.org/releases/) |
| **GUNC Database** | `mag_qc.nf` | GUNC | ~13 GB (Progenomes) | [GUNC Zenodo](https://zenodo.org/record/4648784) |
| **geNomad Database** | `annotation.nf` | geNomad | ~4.5 GB | [geNomad Release Data](https://zenodo.org/record/8339387) |
| **HUMAnN3 ChocoPhlAn / UniRef**| `assembly_free.nf` | HUMAnN3 | ~25 GB (UniRef50) / ~40 GB (UniRef90) | [BioBakery Data](http://huttenhower.sph.harvard.edu/humann_data/) |

---

## Recommended Directory Structure

```
/path/to/databases/
├── host/
│   ├── GRCh38_noalt.fa
│   └── GRCh38_noalt.*.bt2
├── kraken2/
│   └── k2_standard_20240112/
│       ├── hash.k2d
│       ├── opts.k2d
│       ├── taxo.k2d
│       └── database150mers.kmer_distrib
├── checkm2/
│   └── CheckM2_database/
│       └── uniref100.KO.1.dmnd
├── gtdbtk/
│   └── release220/
├── gunc/
│   └── gunc_db_progenomes2.1.dmnd
├── genomad/
│   └── genomad_db/
└── humann/
    ├── chocophlan/
    └── uniref/
```

---

## Automated Download Script

You can download reference databases using the included script `download.sh`:

```bash
# Make script executable
chmod +x databases/download.sh

# Download specific databases
./databases/download.sh --host /path/to/databases/host
./databases/download.sh --kraken2 /path/to/databases/kraken2
./databases/download.sh --checkm2 /path/to/databases/checkm2
./databases/download.sh --genomad /path/to/databases/genomad

# Download all databases
./databases/download.sh --all /path/to/databases
```
