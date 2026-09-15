#!/usr/bin/env bash
# ==============================================================================
# run_compare_assembly_free.sh — Short vs Long Metagenomics Comparison Runner
# ==============================================================================
# Usage:
#   chmod +x run_compare_assembly_free.sh
#   ./run_compare_assembly_free.sh [clean|raw] [conda|singularity|docker|slurm] [EXTRA_ARGS]
#
# Examples:
#   ./run_compare_assembly_free.sh clean conda     # Fast-forward from clean reads (instant profiling)
#   ./run_compare_assembly_free.sh raw conda       # Full run: Fastp/Filtlong + Bowtie2/Minimap2 + Profiling
#   ./run_compare_assembly_free.sh clean slurm     # Run on SLURM cluster
# ==============================================================================

set -eo pipefail

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MODE="${1:-clean}"
PROFILE="${2:-conda}"
shift 2 2>/dev/null || true
EXTRA_ARGS="$@"

# Colors
CYAN='\033[0;36m'
BOLD='\033[1m'
YELLOW='\033[1;33m'
GREEN='\033[0;32m'
BLUE='\033[1;34m'
NC='\033[0m'

# Mode Resolution
if [ "${MODE}" = "raw" ]; then
    DEFAULT_SAMPLESHEET="${PROJECT_DIR}/samplesheet_hybrid.csv"
    DEFAULT_OUTDIR="${PROJECT_DIR}/results_compare_assembly_free_raw"
    PREPROC_ARGS="--run_preprocessing true --run_host_removal true"
else
    DEFAULT_SAMPLESHEET="${PROJECT_DIR}/samplesheet_hybrid_clean.csv"
    DEFAULT_OUTDIR="${PROJECT_DIR}/results_compare_assembly_free_clean"
    PREPROC_ARGS="--run_preprocessing false --run_host_removal false"
fi

SAMPLESHEET="${SAMPLESHEET:-${DEFAULT_SAMPLESHEET}}"
OUTDIR="${OUTDIR:-${DEFAULT_OUTDIR}}"

# Include Pixi / Conda path if available
if [ -d "${PROJECT_DIR}/.pixi/envs/default/bin" ]; then
    export PATH="${PROJECT_DIR}/.pixi/envs/default/bin:${PATH}"
fi

echo -e "${CYAN}==============================================================================${NC}"
echo -e "${BOLD}   🔬 Short vs Long Reads: Assembly-Free Comparison Pipeline Runner 🔬   ${NC}"
echo -e "${CYAN}==============================================================================${NC}"
echo -e " ⚙️ Mode              : ${YELLOW}${MODE}${NC} (${PREPROC_ARGS})"
echo -e " 📋 Samplesheet       : ${BLUE}${SAMPLESHEET}${NC}"
echo -e " 🐳 Runtime Profile   : ${YELLOW}${PROFILE}${NC}"
echo -e " 📂 Output Directory  : ${YELLOW}${OUTDIR}${NC}"
echo -e "${CYAN}==============================================================================${NC}\n"

if [ ! -f "${SAMPLESHEET}" ]; then
    echo -e "\033[0;31m[ERROR] Samplesheet not found: ${SAMPLESHEET}\033[0m"
    exit 1
fi

nextflow run "${PROJECT_DIR}/main_compare_assembly_free.nf" \
    -profile "${PROFILE}" \
    -c "${PROJECT_DIR}/conf/compare_assembly_free.config" \
    --input "${SAMPLESHEET}" \
    --outdir "${OUTDIR}" \
    ${PREPROC_ARGS} \
    ${EXTRA_ARGS} \
    -resume

echo -e "\n${GREEN}==============================================================================${NC}"
echo -e "${GREEN}✅ Assembly-Free Comparison Pipeline execution completed successfully!${NC}"
echo -e "${GREEN}==============================================================================${NC}"
echo -e " 📊 Key Comparison Deliverables in: ${YELLOW}${OUTDIR}${NC}"
echo -e "   - Interactive HTML Dashboard : ${OUTDIR}/compare_assembly_free/assembly_free_comparison.html"
echo -e "   - Markdown Summary Report   : ${OUTDIR}/compare_assembly_free/assembly_free_comparison.md"
echo -e "   - Metrics & Abundance TSVs   : ${OUTDIR}/compare_assembly_free/*_comparison_*.tsv"
echo -e "   - Short Krona Charts         : ${OUTDIR}/krona_short/*_short.krona.html"
echo -e "   - Long Krona Charts          : ${OUTDIR}/krona_long/*_long.krona.html"
echo -e "   - Consolidated MultiQC       : ${OUTDIR}/multiqc/multiqc_report.html\n"
