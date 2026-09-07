#!/usr/bin/env bash
# ==============================================================================
# run_eval_host.sh — Runner for Host Removal & Krona Evaluation Pipeline
# ==============================================================================
# Usage:
#   chmod +x run_eval_host.sh
#   ./run_eval_host.sh [smoke|full] [conda|singularity|docker] [EXTRA_ARGS]
#
# Examples:
#   ./run_eval_host.sh smoke conda
#   ./run_eval_host.sh full conda
# ==============================================================================

set -eo pipefail

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MODE="${1:-full}"
PROFILE="${2:-conda}"
shift 2 2>/dev/null || true
EXTRA_ARGS="$@"

# Colors
CYAN='\033[0;36m'
BOLD='\033[1m'
YELLOW='\033[1;33m'
GREEN='\033[0;32m'
NC='\033[0m'

if [ "${MODE}" = "smoke" ]; then
    SAMPLESHEET="${PROJECT_DIR}/samplesheet_meta_npi_smoke.csv"
    OUTDIR="${PROJECT_DIR}/results_eval_host_smoke"
elif [ "${MODE}" = "subset" ]; then
    SAMPLESHEET="${PROJECT_DIR}/samplesheet_meta_npi_subset.csv"
    OUTDIR="${PROJECT_DIR}/results_eval_host_subset"
else
    SAMPLESHEET="${PROJECT_DIR}/samplesheet_meta_npi_full.csv"
    OUTDIR="${PROJECT_DIR}/results_eval_host_full"
fi

echo -e "${CYAN}==============================================================================${NC}"
echo -e "${BOLD}   🔬 Host Removal & Krona Evaluation Pipeline Runner (EPI2ME Standard) 🔬   ${NC}"
echo -e "${CYAN}==============================================================================${NC}"
echo -e " ⚙️ Mode        : ${YELLOW}${MODE}${NC} (${SAMPLESHEET})"
echo -e " 🐳 Profile     : ${YELLOW}${PROFILE}${NC}"
echo -e " 📂 Output Dir  : ${YELLOW}${OUTDIR}${NC}"
echo -e "${CYAN}==============================================================================${NC}\n"

nextflow run "${PROJECT_DIR}/main_eval_host.nf" \
    -profile "${PROFILE}" \
    -c "${PROJECT_DIR}/conf/eval_host.config" \
    --input "${SAMPLESHEET}" \
    --outdir "${OUTDIR}" \
    ${EXTRA_ARGS} \
    -resume

echo -e "\n${GREEN}✅ Execution complete! Results are stored in: ${OUTDIR}${NC}"
echo -e "   - Before vs After comparison: ${OUTDIR}/host_removal_comparison.md"
echo -e "   - MultiQC report:             ${OUTDIR}/reporting/multiqc/multiqc_report.html"
echo -e "   - Krona charts (With Host):   ${OUTDIR}/assembly_free/krona/*_with_host.krona.html"
echo -e "   - Krona charts (Clean Host):  ${OUTDIR}/assembly_free/krona/*_clean.krona.html\n"
