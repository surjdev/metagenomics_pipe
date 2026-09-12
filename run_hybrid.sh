#!/usr/bin/env bash
# ==============================================================================
# run_hybrid.sh — Runner for Hybrid (Illumina + Nanopore) Metagenomics Pipeline
# ==============================================================================
# การใช้งาน:
#   chmod +x run_hybrid.sh
#   ./run_hybrid.sh [PROFILE] [EXTRA_ARGS]
#
# ตัวอย่าง:
#   ./run_hybrid.sh singularity
#   ./run_hybrid.sh docker
#   ./run_hybrid.sh conda
#   ./run_hybrid.sh slurm
# ==============================================================================

set -eo pipefail

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# ตรวจสอบ argument: หากระบุ profile (เช่น conda, docker) ให้ใช้ค่านั้น หากส่ง flag (--option) ให้ใช้ conda เป็น default
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

SAMPLESHEET="${PROJECT_DIR}/samplesheet_hybrid.csv"
OUTDIR="${PROJECT_DIR}/results_hybrid"
PARAMS_FILE="${PROJECT_DIR}/params/hybrid.yaml"

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
    echo -e "\033[1;33m💡 คำแนะนำ:\033[0m คุณสามารถดึงข้อมูลตัวอย่างทดสอบ 2 คน (Short + Long) และสร้าง Samplesheet อัตโนมัติได้ด้วยคำสั่ง:"
    echo -e "   \033[1;32m./bin/pull_hybrid_test_data.sh smoke\033[0m   (โหมดทดสอบเร็ว ~5 นาที)"
    echo -e " หรือ:"
    echo -e "   \033[1;32m./bin/pull_hybrid_test_data.sh full\033[0m    (โหมดข้อมูลเต็ม)\n"
    exit 1
fi



echo -e "\033[0;36m==============================================================================\033[0m"
echo -e "\033[1;34m   🧬 Running Hybrid (Illumina + Nanopore) Metagenomics Pipeline 🧬   \033[0m"
echo -e "\033[0;36m==============================================================================\033[0m"
echo -e " 📂 Project Directory : ${PROJECT_DIR}"
echo -e " 📋 Samplesheet       : ${SAMPLESHEET}"
echo -e " ⚙️  Params Preset     : ${PARAMS_FILE}"
echo -e " 📁 Output Directory  : ${OUTDIR}"
echo -e " 🧩 Assembler         : \033[1;32mmetaSPAdes (Hybrid)\033[0m"
echo -e " 🐳 Runtime Profile   : \033[1;33m${PROFILE}\033[0m"
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
nextflow run "${PROJECT_DIR}/main.nf" \
    -profile "${PROFILE}" \
    -params-file "${PARAMS_FILE}" \
    --input "${SAMPLESHEET}" \
    --outdir "${OUTDIR}" \
    --platform "hybrid" \
    --mode "hybrid" \
    --assembler "metaspades" \
    -resume \
    -with-report "${REPORT_HTML}" \
    -with-timeline "${TIMELINE_HTML}" \
    -with-trace "${TRACE_TXT}" \
    -with-dag "${DAG_SVG}" \
    "${EXTRA_ARGS[@]}"

echo -e "\n\033[0;32m==============================================================================\033[0m"
echo -e "\033[1;32m 🎉 การประมวลผล Hybrid Pipeline เสร็จสมบูรณ์! (Finished Successfully) 🎉 \033[0m"
echo -e "\033[0;32m==============================================================================\033[0m"
echo -e " 📁 ตรวจสอบผลลัพธ์ได้ที่: \033[1m${OUTDIR}\033[0m"
echo -e "   ├─ 📊 สรุปภาพรวม QC (MultiQC)   : ${OUTDIR}/reporting/multiqc/multiqc_report.html"
echo -e "   ├─ 📄 รายงาน Pipeline          : ${OUTDIR}/reporting/pipeline_report.html"
echo -e "   ├─ 🧬 Hybrid Contigs (metaSPAdes): ${OUTDIR}/assembly/metaspades/"
echo -e "   ├─ 🧩 คุณภาพ Contigs (QUAST)    : ${OUTDIR}/assembly_qc/quast/"
echo -e "   ├─ 🗺️  Read Mapping (BAM/Depth) : ${OUTDIR}/mapping/"
echo -e "   ├─ 📦 MAG Bins (Multi-binner)   : ${OUTDIR}/binning/"
echo -e "   └─ 📈 รายงานทรัพยากร/เวลา       : ${REPORT_HTML}"
echo -e "\033[0;32m==============================================================================\033[0m\n"
