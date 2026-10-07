#!/bin/bash
# ==============================================================================
# run_chicken.sh — Assembly-Free Profiling (Chicken Nanopore 24 Barcodes)
# ==============================================================================

set -e

# พาธฐานข้อมูล Kraken2 (สามารถระบุหรือ override ได้)
KRAKEN2_DB="${1:-/home/koraop/nob_dir/metagenomics/metagenomics_pipe/databases/Standard/kraken2}"

# The conda Nextflow profile uses this existing Pixi environment for processes.
PIXI_BIN="${PWD}/.pixi/envs/default/bin"
if [ ! -d "${PIXI_BIN}" ]; then
    echo "ERROR: Pixi environment is missing at ${PIXI_BIN}; run 'pixi install' first." >&2
    exit 1
fi
export PATH="${PIXI_BIN}:${PATH}"

missing_tool=0
for tool in nextflow kraken2 bracken ktImportText python3 multiqc; do
    if ! command -v "${tool}" >/dev/null 2>&1; then
        echo "ERROR: ${tool} is unavailable in the Pixi environment (${PIXI_BIN})." >&2
        missing_tool=1
    fi
done
if [ "${missing_tool}" -ne 0 ]; then
    exit 1
fi

if ! kraken2 --version >/dev/null 2>&1; then
    echo "ERROR: kraken2 was found but cannot run in the Pixi environment." >&2
    exit 1
fi

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
    -profile conda \
    -resume
