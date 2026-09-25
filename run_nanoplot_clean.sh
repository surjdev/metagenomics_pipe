#!/usr/bin/env bash
# ==============================================================================
# run_nanoplot_clean.sh — Runner for Clean Long-Read NanoPlot Quality Control
# ==============================================================================
# การใช้งาน:
#   chmod +x run_nanoplot_clean.sh
#   ./run_nanoplot_clean.sh [PROFILE] [EXTRA_ARGS]
#
# ตัวอย่าง:
#   ./run_nanoplot_clean.sh conda
#   ./run_nanoplot_clean.sh singularity
#   ./run_nanoplot_clean.sh docker
#   ./run_nanoplot_clean.sh slurm
# ==============================================================================

set -eo pipefail

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# ตรวจสอบ argument: หากระบุ profile ให้ใช้ค่านั้น หากระบุ option ให้ใช้ conda เป็น default
if [[ "$1" =~ ^(conda|singularity|docker|slurm|test|local)$ ]]; then
    PROFILE="$1"
    EXTRA_ARGS=("${@:2}")
elif [[ "$1" == -* ]]; then
    PROFILE="conda"
    EXTRA_ARGS=("$@")
else
    PROFILE="${1:-conda}"
    EXTRA_ARGS=("${@:2}")
fi

SAMPLESHEET="${SAMPLESHEET:-${PROJECT_DIR}/samplesheet_hybrid_clean.csv}"
OUTDIR="${PROJECT_DIR}/results_hybrid/preprocessing/nanoplot_clean"

# รวม Pixi / Conda environment หากมี
if [ -d "${PROJECT_DIR}/.pixi/envs/default/bin" ]; then
    export PATH="${PROJECT_DIR}/.pixi/envs/default/bin:${PATH}"
fi

# ตรวจสอบการติดตั้ง Nextflow
if ! command -v nextflow &> /dev/null; then
    echo -e "\033[0;31m[ERROR] ไม่พบคำสั่ง 'nextflow' ในระบบ กรุณาเปิดใช้งาน Conda/Pixi หรือติดตั้ง Nextflow ก่อน\033[0m"
    exit 1
fi

# ตรวจสอบไฟล์ Samplesheet
if [ ! -f "${SAMPLESHEET}" ]; then
    echo -e "\033[0;31m[ERROR] ไม่พบไฟล์ Samplesheet ที่: ${SAMPLESHEET}\033[0m"
    exit 1
fi

echo -e "\033[0;36m==============================================================================\033[0m"
echo -e "\033[1;34m   📊 Running NanoPlot Quality Control for Clean Long Reads 📊   \033[0m"
echo -e "\033[0;36m==============================================================================\033[0m"
echo -e " 📂 Project Directory : ${PROJECT_DIR}"
echo -e " 📋 Samplesheet       : ${SAMPLESHEET}"
echo -e " 📁 Output Directory  : ${OUTDIR}"
echo -e " 🐳 Container Profile : \033[1;33m${PROFILE}\033[0m"
echo -e " ⏱️  Start Time        : $(date '+%Y-%m-%d %H:%M:%S')"
echo -e "\033[0;36m==============================================================================\033[0m\n"

# สร้างโฟลเดอร์สำหรับรายงาน Execution info
mkdir -p "${OUTDIR}/pipeline_info"
TIMESTAMP=$(date '+%Y%m%d_%H%M%S')
REPORT_HTML="${OUTDIR}/pipeline_info/execution_report_${TIMESTAMP}.html"
TIMELINE_HTML="${OUTDIR}/pipeline_info/execution_timeline_${TIMESTAMP}.html"
TRACE_TXT="${OUTDIR}/pipeline_info/execution_trace_${TIMESTAMP}.txt"
DAG_SVG="${OUTDIR}/pipeline_info/pipeline_dag_${TIMESTAMP}.html"

# สั่งรัน Nextflow
nextflow run "${PROJECT_DIR}/main_nanoplot_clean.nf" \
    -profile "${PROFILE}" \
    -c "${PROJECT_DIR}/conf/nanoplot_clean.config" \
    --input "${SAMPLESHEET}" \
    --outdir "${OUTDIR}" \
    -resume \
    -with-report "${REPORT_HTML}" \
    -with-timeline "${TIMELINE_HTML}" \
    -with-trace "${TRACE_TXT}" \
    -with-dag "${DAG_SVG}" \
    "${EXTRA_ARGS[@]}"

echo -e "\n\033[0;32m==============================================================================\033[0m"
echo -e "\033[1;32m 🎉 การประมวลผล NanoPlot เสร็จสมบูรณ์! (Finished Successfully) 🎉 \033[0m"
echo -e "\033[0;32m==============================================================================\033[0m"
echo -e " 📁 ตรวจสอบผลลัพธ์ได้ที่: \033[1m${OUTDIR}\033[0m"
echo -e "   ├─ 📊 สรุปภาพรวม QC (MultiQC) : ${OUTDIR}/multiqc/multiqc_report.html"
echo -e "   ├─ 📄 รายงาน NanoPlot HTML   : ${OUTDIR}/nanoplot/*_clean.NanoPlot-report.html"
echo -e "   ├─ 📈 สถิติละเอียด (Stats)   : ${OUTDIR}/nanoplot/*_clean.NanoStats.txt"
echo -e "   └─ ⏱️  รายงานทรัพยากร/เวลา    : ${REPORT_HTML}"
echo -e "\033[0;32m==============================================================================\033[0m\n"
