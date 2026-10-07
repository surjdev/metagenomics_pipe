#!/usr/bin/env bash
# ==============================================================================
# run_chicken.sh — Automated Pipeline Runner for Chicken Nanopore Metagenomics
# ==============================================================================
# วัตถุประสงค์ (Purpose):
#   สคริปต์ควบคุมการประมวลผล Nextflow DSL2 สำหรับชุดข้อมูล Oxford Nanopore Chicken (24 Barcodes)
#   รองรับทั้งโหมดจำแนกสายพันธุ์เร็ว (Read-based / Assembly-free เหมือน wf-metagenomics)
#   และโหมดประกอบจีโนมจุลินทรีย์ (De novo Metagenome Assembly & MAG recovery)
#
# การใช้งาน (Usage):
#   chmod +x run_chicken.sh
#   ./run_chicken.sh [MODE] [PROFILE] [EXTRA_ARGS]
#
# โหมดการทำงาน (Modes):
#   1) profile / assembly_free : (ค่าเริ่มต้น) รัน Kraken2 + Bracken + Krona + BIOM (เหมือน wf-metagenomics)
#   2) assembly                : รัน De novo Flye Assembly + QUAST + MetaBAT2 Binning
#   3) smoke                   : รันด่วน 1 Barcode (barcode01) เพื่อทดสอบความถูกต้องของระบบ
#   4) dry-run                 : จำลอง DAG workflow preview โดยไม่รัน process จริง
#   5) clean                   : ล้างไดเรกทอรี work/ และแคช .nextflow/
#
# โปรไฟล์รันเนอร์ (Profiles):
#   - conda       : รันผ่าน Conda environment (เช่น metagenomics)
#   - singularity : รันผ่าน Singularity containers (แนะนำสำหรับ HPC Cluster)
#   - docker      : รันผ่าน Docker containers
#   - slurm       : กระจายงานเข้าสู่ SLURM scheduler
#
# ตัวอย่างคำสั่ง (Examples):
#   ./run_chicken.sh profile conda             # รัน Read-based profiling ทั้ง 24 ตัวอย่าง
#   ./run_chicken.sh smoke conda               # รัน Smoke test 1 ตัวอย่าง
#   ./run_chicken.sh profile singularity       # รันผ่าน Singularity
#   ./run_chicken.sh profile conda --run_host_removal true  # เปิดโหมดกรองจีโนมไก่เพิ่ม
# ==============================================================================

set -eo pipefail

# รหัสสี ANSI สำหรับ Terminal
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MODE="${1:-profile}"
PROFILE="${2:-conda}"
shift 2 2>/dev/null || true
EXTRA_ARGS=("$@")

print_banner() {
    echo -e "${CYAN}==============================================================================${NC}"
    echo -e "${BOLD}${BLUE}   🐔 Chicken Nanopore Metagenomics Workflow Runner (24 Barcodes) 🧬   ${NC}"
    echo -e "${CYAN}==============================================================================${NC}"
    echo -e " 📂 Project Directory : ${PROJECT_DIR}"
    echo -e " ⚙️ Execution Mode     : ${YELLOW}${MODE}${NC}"
    echo -e " 🐳 Runner Profile    : ${YELLOW}${PROFILE}${NC}"
    echo -e " ⏱️ Timestamp          : $(date '+%Y-%m-%d %H:%M:%S')"
    echo -e "${CYAN}==============================================================================${NC}\n"
}

show_help() {
    echo -e "${BOLD}รูปแบบการใช้งาน:${NC}"
    echo -e "  ./run_chicken.sh [mode: profile|assembly|smoke|dry-run|clean] [profile: conda|singularity|docker|slurm] [options...]\n"
    echo -e "${BOLD}โหมดที่รองรับ:${NC}"
    echo -e "  ${GREEN}profile${NC}       - Assembly-free profiling: Kraken2 + Bracken + Krona + BIOM (เหมือน wf-metagenomics)"
    echo -e "  ${GREEN}assembly${NC}      - De novo Assembly: Flye (--nano-hq --meta) + QUAST + MetaBAT2"
    echo -e "  ${GREEN}smoke${NC}         - ทดสอบด่วน 1 ตัวอย่าง (barcode01) ใช้เวลาไม่กี่นาที"
    echo -e "  ${GREEN}dry-run${NC}       - ตรวจสอบ Channel wiring และ DAG (-preview)"
    echo -e "  ${GREEN}clean${NC}         - ล้างแคช work/ และ .nextflow/\n"
    echo -e "${BOLD}ตัวเลือกเพิ่มเติมยอดนิยม:${NC}"
    echo -e "  --run_host_removal true    : เปิดการกรองโฮสต์ไก่ (Minimap2 กับ GRCg7b reference)"
    echo -e "  --run_preprocessing true   : กรองคุณภาพ reads ซ้ำด้วย Filtlong (Q10+, 300bp+)\n"
}

# ตรวจสอบคำสั่ง Nextflow
check_prerequisites() {
    # ค้นหา Conda หรือ Pixi environment หาก Nextflow ยังไม่อยู่ใน PATH
    if ! command -v nextflow &> /dev/null; then
        if [ -d "${PROJECT_DIR}/.pixi/envs/default/bin" ]; then
            export PATH="${PROJECT_DIR}/.pixi/envs/default/bin:${PATH}"
        elif [ -f "$HOME/miniconda3/etc/profile.d/conda.sh" ]; then
            source "$HOME/miniconda3/etc/profile.d/conda.sh"
            conda activate metagenomics 2>/dev/null || true
        elif [ -f "$HOME/anaconda3/etc/profile.d/conda.sh" ]; then
            source "$HOME/anaconda3/etc/profile.d/conda.sh"
            conda activate metagenomics 2>/dev/null || true
        fi
    fi

    if ! command -v nextflow &> /dev/null; then
        echo -e "${RED}[ERROR] ไม่พบคำสั่ง 'nextflow' ใน PATH! กรุณา activate Conda environment เช่น 'conda activate metagenomics'${NC}"
        exit 1
    fi
}

# ล้าง work cache
clean_workspace() {
    echo -e "${YELLOW}🧹 กำลังล้างไฟล์ชั่วคราว (work directory และ .nextflow)...${NC}"
    read -p "ยืนยันการลบ ${PROJECT_DIR}/work และ .nextflow ? (y/N): " confirm
    if [[ "$confirm" =~ ^[Yy]$ ]]; then
        rm -rf "${PROJECT_DIR}/work" "${PROJECT_DIR}/.nextflow" "${PROJECT_DIR}/.nextflow.log"*
        echo -e "${GREEN}✅ ล้างไฟล์ชั่วคราวเรียบร้อยแล้ว${NC}"
    else
        echo -e "${BLUE}ยกเลิกการล้างไฟล์${NC}"
    fi
    exit 0
}

# กำหนด scratch directory ป้องกันโควต้าดิสก์ /home เต็มบน HPC
setup_work_dir() {
    if [ -z "${NXF_WORK_DIR}" ]; then
        if [ -L "${PROJECT_DIR}/work" ]; then
            export NXF_WORK_DIR="${PROJECT_DIR}/work"
        elif [ ! -e "${PROJECT_DIR}/work" ] && [ -d "/scratch" ]; then
            SCRATCH_DIR="/scratch/${USER:-koraop}/nextflow_work_chicken"
            if mkdir -p "${SCRATCH_DIR}" 2>/dev/null; then
                ln -s "${SCRATCH_DIR}" "${PROJECT_DIR}/work"
                export NXF_WORK_DIR="${PROJECT_DIR}/work"
                echo -e " 💾 Work Directory linked to Scratch: ${GREEN}${SCRATCH_DIR}${NC}"
            fi
        fi
    fi
}

# แยกการทำงานตามโหมด
case "${MODE}" in
    help|--help|-h)
        print_banner
        show_help
        exit 0
        ;;
    clean)
        clean_workspace
        ;;
    dry-run)
        print_banner
        check_prerequisites
        echo -e "${YELLOW}🔍 [Dry-Run] กำลังจำลอง DAG Execution...${NC}"
        nextflow run "${PROJECT_DIR}/main.nf" \
            -profile "${PROFILE}" \
            -c "${PROJECT_DIR}/conf/chicken.config" \
            --input "${PROJECT_DIR}/samplesheet_chicken_smoke.csv" \
            -preview
        echo -e "${GREEN}✅ ตรวจสอบโครงสร้าง DAG สำเร็จ!${NC}"
        exit 0
        ;;
    smoke)
        PIPELINE_MODE="assembly_free"
        SAMPLESHEET="${PROJECT_DIR}/samplesheet_chicken_smoke.csv"
        OUTDIR="${PROJECT_DIR}/results_chicken_smoke"
        DESC="Smoke Test (1 Barcode: barcode01 - ทดสอบความพร้อมด่วน)"
        ;;
    profile|assembly_free)
        PIPELINE_MODE="assembly_free"
        SAMPLESHEET="${PROJECT_DIR}/samplesheet_chicken.csv"
        OUTDIR="${PROJECT_DIR}/results_chicken_profile"
        DESC="Assembly-Free Profiling (24 Barcodes: Kraken2 + Bracken + Krona + BIOM)"
        ;;
    assembly|mag)
        PIPELINE_MODE="assembly"
        SAMPLESHEET="${PROJECT_DIR}/samplesheet_chicken.csv"
        OUTDIR="${PROJECT_DIR}/results_chicken_assembly"
        DESC="De Novo Metagenome Assembly (24 Barcodes: Flye + QUAST + MetaBAT2)"
        ;;
    *)
        echo -e "${RED}[ERROR] ไม่รู้จักโหมด: '${MODE}'${NC}"
        echo -e "ตัวเลือกที่ใช้ได้: profile | assembly | smoke | dry-run | clean | help"
        exit 1
        ;;
esac

# ตรวจสอบไฟล์ samplesheet
if [ ! -f "${SAMPLESHEET}" ]; then
    echo -e "${RED}[ERROR] ไม่พบไฟล์ Samplesheet: ${SAMPLESHEET}${NC}"
    exit 1
fi

print_banner
check_prerequisites
setup_work_dir

CONFIG_FILE="${PROJECT_DIR}/conf/chicken.config"
TIMESTAMP=$(date '+%Y%m%d_%H%M%S')
LOGS_DIR="${OUTDIR}/pipeline_info"
mkdir -p "${LOGS_DIR}"

REPORT_HTML="${LOGS_DIR}/execution_report_${TIMESTAMP}.html"
TIMELINE_HTML="${LOGS_DIR}/execution_timeline_${TIMESTAMP}.html"
TRACE_TXT="${LOGS_DIR}/execution_trace_${TIMESTAMP}.txt"
DAG_HTML="${LOGS_DIR}/pipeline_dag_${TIMESTAMP}.html"

echo -e "${BOLD}📋 ข้อมูลการประมวลผล:${NC}"
echo -e " • คำอธิบาย      : ${GREEN}${DESC}${NC}"
echo -e " • โหมด Pipeline : ${YELLOW}${PIPELINE_MODE}${NC}"
echo -e " • Samplesheet    : ${SAMPLESHEET}"
echo -e " • Config File    : ${CONFIG_FILE}"
echo -e " • Output Dir     : ${OUTDIR}"
echo -e " • Nextflow Exec  : $(which nextflow)"
echo -e " • Execution Logs : ${LOGS_DIR}"
echo ""

echo -e "${CYAN}🚀 กำลังเริ่มรัน Nextflow Pipeline...${NC}\n"

nextflow run "${PROJECT_DIR}/main.nf" \
    -profile "${PROFILE}" \
    -c "${CONFIG_FILE}" \
    --mode "${PIPELINE_MODE}" \
    --input "${SAMPLESHEET}" \
    --outdir "${OUTDIR}" \
    -resume \
    -with-report "${REPORT_HTML}" \
    -with-timeline "${TIMELINE_HTML}" \
    -with-trace "${TRACE_TXT}" \
    -with-dag "${DAG_HTML}" \
    "${EXTRA_ARGS[@]}"

echo -e "\n${GREEN}==============================================================================${NC}"
echo -e "${BOLD}${GREEN} 🎉 การประมวลผลเสร็จสิ้นสมบูรณ์! (Completed Successfully) 🎉 ${NC}"
echo -e "${GREEN}==============================================================================${NC}"
echo -e " 📁 ตรวจสอบผลลัพธ์ได้ที่: ${BOLD}${OUTDIR}${NC}"
if [ "${PIPELINE_MODE}" = "assembly_free" ]; then
    echo -e "   ├─ 🦠 Kraken2 Reports       : ${OUTDIR}/kraken2/"
    echo -e "   ├─ 📊 Bracken Abundances    : ${OUTDIR}/bracken/"
    echo -e "   ├─ 🥧 Krona Interactive Pie : ${OUTDIR}/krona/"
    echo -e "   ├─ 📦 BIOM Tables           : ${OUTDIR}/kraken_biom/"
    echo -e "   └─ 📈 MultiQC Report        : ${OUTDIR}/multiqc/multiqc_report.html"
else
    echo -e "   ├─ 🧬 Contigs (Flye)        : ${OUTDIR}/flye/"
    echo -e "   ├─ 🧩 QUAST Contig Stats    : ${OUTDIR}/quast/"
    echo -e "   ├─ 📦 MAG Bins (MetaBAT2)   : ${OUTDIR}/metabat2/"
    echo -e "   └─ 📈 MultiQC Report        : ${OUTDIR}/multiqc/multiqc_report.html"
fi
echo -e "   └─ 📋 Pipeline Execution Rep: ${REPORT_HTML}"
echo -e "${GREEN}==============================================================================${NC}\n"
