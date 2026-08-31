# Metagenomics Pipeline Report — barcode21

Generated: 2026-08-30

## Key Metrics

- **Total Samples**: 1
- **Total Assembled Contigs**: 9
- **Assembly N50**: 16575 bp
- **Reconstructed MAGs**: 2
- **Classified Taxa**: 1

## Sample Summary Table

| Sample ID | Platform | Contigs | Total Length (bp) | N50 (bp) | Bins | Status |
|---|---|---|---|---|---|---|

| barcode21 | hybrid | 9 | 98965 | 16575 | 2 | Completed |


## Pipeline Workflow Stages

1. **Preprocessing & Host Removal**: FastQC, Fastp, NanoPlot, Bowtie2, Minimap2
2. **Assembly & Polishing**: MEGAHIT, Flye, Opera-MS, NextPolish, QUAST
3. **MAG Reconstruction & QC**: MetaBAT2, MaxBin2, SemiBin2, CONCOCT, DAS Tool, CAT_BINS, CheckM2
4. **Read-Based Profiling**: Kraken2, Bracken, Krona, BIOM, HUMAnN3
5. **Annotation & Reporting**: Prokka, geNomad, MultiQC, Final Report