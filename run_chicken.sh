#!/bin/bash
# ==============================================================================
# run_chicken.sh — Assembly-Free Profiling (Chicken Nanopore 24 Barcodes)
# ==============================================================================

set -e

# พาธฐานข้อมูล Kraken2 (สามารถระบุหรือ override ได้)
KRAKEN2_DB="${1:-/home/koraop/nob_dir/metagenomics/metagenomics_pipe/databases/Standard/kraken2}"

nextflow run main.nf \
    --mode assembly_free \
    --platform nanopore \
    --input samplesheet_chicken.csv \
    --outdir results_chicken_assembly_free \
    --kraken2_db "${KRAKEN2_DB}" \
    --kraken2_confidence 0.0 \
    --run_bracken true \
    --bracken_threshold 10 \
    --bracken_level S \
    --run_krona true \
    --run_kraken_biom true \
    --run_preprocessing false \
    --run_host_removal false \
    -profile singularity \
    -resume
