#!/usr/bin/env bash
# ==============================================================================
# run_short_reads.sh — Runner for Illumina Short-Read Metagenomics Dataset
# ==============================================================================
# การใช้งาน:
#   chmod +x run_short_reads.sh
#   ./run_short_reads.sh [PROFILE] [EXTRA_ARGS]
#
# ตัวอย่าง:
#   ./run_short_reads.sh docker
#   ./run_short_reads.sh conda
#   ./run_short_reads.sh singularity
# ==============================================================================

set -eo pipefail

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROFILE="${1:-docker}"
SAMPLESHEET="${PROJECT_DIR}/samplesheet_short_reads.csv"
OUTDIR="${PROJECT_DIR}/results_short_reads"

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
echo -e "\033[1;34m   🧬 Running Illumina Paired-End Metagenomics Pipeline 🧬   \033[0m"
echo -e "\033[0;36m==============================================================================\033[0m"
echo -e " 📂 Project Directory : ${PROJECT_DIR}"
echo -e " 📋 Samplesheet       : ${SAMPLESHEET}"
echo -e " 📁 Output Directory  : ${OUTDIR}"
echo -e " 🐳 Container Profile : \033[1;33m${PROFILE}\033[0m"
echo -e " ⏱️ Start Time        : $(date '+%Y-%m-%d %H:%M:%S')"
echo -e "\033[0;36m==============================================================================\033[0m\n"

# สร้างโฟลเดอร์สำหรับรายงาน Execution info
mkdir -p "${OUTDIR}/pipeline_info"
TIMESTAMP=$(date '+%Y%m%d_%H%M%S')
REPORT_HTML="${OUTDIR}/pipeline_info/execution_report_${TIMESTAMP}.html"
TIMELINE_HTML="${OUTDIR}/pipeline_info/execution_timeline_${TIMESTAMP}.html"
TRACE_TXT="${OUTDIR}/pipeline_info/execution_trace_${TIMESTAMP}.txt"
DAG_SVG="${OUTDIR}/pipeline_info/pipeline_dag_${TIMESTAMP}.html"

# สั่งรัน Nextflow
nextflow run "${PROJECT_DIR}/main.nf" \
    -profile "${PROFILE}" \
    --input "${SAMPLESHEET}" \
    --outdir "${OUTDIR}" \
    --assembler "megahit" \
    --run_metabat2 true \
    --run_kraken2 false \
    -resume \
    -with-report "${REPORT_HTML}" \
    -with-timeline "${TIMELINE_HTML}" \
    -with-trace "${TRACE_TXT}" \
    -with-dag "${DAG_SVG}" \
    "${@:2}"

echo -e "\n\033[0;32m==============================================================================\033[0m"
echo -e "\033[1;32m 🎉 การประมวลผล Pipeline เสร็จสมบูรณ์! (Finished Successfully) 🎉 \033[0m"
echo -e "\033[0;32m==============================================================================\033[0m"
echo -e " 📁 ตรวจสอบผลลัพธ์ได้ที่: \033[1m${OUTDIR}\033[0m"
echo -e "   ├─ 📊 สรุปภาพรวม QC (MultiQC) : ${OUTDIR}/reporting/multiqc/multiqc_report.html"
echo -e "   ├─ 📄 รายงาน Pipeline        : ${OUTDIR}/reporting/pipeline_report.html"
echo -e "   ├─ 🧩 คุณภาพ Contigs (QUAST)  : ${OUTDIR}/assembly_qc/quast/"
echo -e "   ├─ 📦 MAG Bins (MetaBAT2)     : ${OUTDIR}/binning/metabat2/"
echo -e "   └─ 📈 รายงานทรัพยากร/เวลา     : ${REPORT_HTML}"
echo -e "\033[0;32m==============================================================================\033[0m\n"
