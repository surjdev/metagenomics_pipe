#!/usr/bin/env bash
# ==============================================================================
# bin/pull_hybrid_data_fasterq.sh — Pull Hybrid Metagenomics Test Data via fasterq-dump
# ==============================================================================
# คำอธิบายภาษาไทย (Thai Description):
# สคริปต์นี้ใช้สำหรับดึงข้อมูล Short reads (Illumina Paired-end) และ Long reads (Nanopore Single-end)
# สำหรับ 2 ตัวอย่าง (เริ่มต้นคือ TD22 และ TD3) จาก short_long_metadata.csv โดยใช้คำสั่ง 'fasterq-dump'
# จากชุดเครื่องมือ SRA Toolkit พร้อมบีบอัดเป็น .fastq.gz และสร้างไฟล์ samplesheet_hybrid.csv อัตโนมัติ
#
# การใช้งาน (Usage):
#   chmod +x bin/pull_hybrid_data_fasterq.sh
#   ./bin/pull_hybrid_data_fasterq.sh [OPTIONS]
#
# ออปชัน:
#   --test, -t        ดึงเฉพาะ 50,000 reads แรกต่อตัวอย่าง (-X 50000) เพื่อทดสอบรัน pipeline อย่างรวดเร็ว
#   --full, -f        ดึงข้อมูลตัวอย่างเต็มทั้งหมด (Full dataset)
#   --subjects <ID..> กำหนด Subject IDs ที่ต้องการดึง (ค่าเริ่มต้น: TD22 TD3)
#   --threads <N>     จำนวน CPU threads สำหรับ fasterq-dump และ pigz (ค่าเริ่มต้น: 4)
#   --outdir <DIR>    โฟลเดอร์สำหรับเก็บไฟล์ FASTQ (ค่าเริ่มต้น: test_data/hybrid_test)
#   -h, --help        แสดงข้อความช่วยเหลือ
# ==============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
METADATA_FILE="${PROJECT_DIR}/short_long_metadata.csv"
SAMPLESHEET_OUT="${PROJECT_DIR}/samplesheet_hybrid.csv"
OUTDIR="${PROJECT_DIR}/test_data/hybrid_test"

# ค่าเริ่มต้น
MAX_SPOTS=""
THREADS=$(nproc 2>/dev/null || echo 4)
SUBJECTS=("TD22" "TD3")

# สีสำหรับการแสดงผล
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

usage() {
    cat <<EOF
${BOLD}การใช้งาน:${NC} $(basename "$0") [OPTIONS]

${BOLD}Options:${NC}
  --test, -t          ดึงเฉพาะ 50,000 reads แรกต่อตัวอย่าง (-X 50000) เพื่อทดสอบอย่างรวดเร็ว
  --full, -f          ดึงข้อมูลเต็มทุก reads (Full run)
  --subjects <S1 S2>  ระบุชื่อ Subject ที่ต้องการดึง (default: TD22 TD3)
  --outdir <DIR>      ระบุโฟลเดอร์ปลายทาง (default: test_data/hybrid_test)
  --threads <N>       จำนวน threads สำหรับ fasterq-dump และ pigz (default: ${THREADS})
  --samplesheet <CSV> ระบุไฟล์ samplesheet ปลายทาง (default: samplesheet_hybrid.csv)
  -h, --help          แสดงข้อความช่วยเหลือ

${BOLD}ตัวอย่างคำสั่ง:${NC}
  ./bin/pull_hybrid_data_fasterq.sh --test              # โหมดทดสอบเร็ว (50k reads)
  ./bin/pull_hybrid_data_fasterq.sh --full              # โหมดข้อมูลเต็ม
  ./bin/pull_hybrid_data_fasterq.sh --subjects TD78 CD35 --test
EOF
    exit 0
}

# ตรวจสอบว่ามี fasterq-dump หรือไม่
if ! command -v fasterq-dump &> /dev/null; then
    echo -e "${RED}[ERROR] ไม่พบคำสั่ง 'fasterq-dump' ในระบบ!${NC}"
    echo -e "${YELLOW}คุณสามารถติดตั้ง sra-tools ผ่าน Conda หรือ Pixi ได้ดังนี้:${NC}"
    echo -e "  conda install -c bioconda -c conda-forge sra-tools pigz -y"
    echo -e " หรือ:"
    echo -e "  pixi add sra-tools pigz\n"
    exit 1
fi

# ตรวจสอบไฟล์ metadata
if [ ! -f "${METADATA_FILE}" ]; then
    echo -e "${RED}[ERROR] ไม่พบไฟล์ metadata: ${METADATA_FILE}${NC}"
    exit 1
fi

# Parse CLI arguments
while [ $# -gt 0 ]; do
    case "$1" in
        --test|-t)
            MAX_SPOTS="-X 50000"
            ;;
        --full|-f)
            MAX_SPOTS=""
            ;;
        --subjects)
            shift
            SUBJECTS=()
            while [ $# -gt 0 ] && [[ "$1" != --* ]]; do
                SUBJECTS+=("$1")
                shift
            done
            continue
            ;;
        --threads)
            shift
            THREADS="$1"
            ;;
        --outdir)
            shift
            OUTDIR="$1"
            ;;
        --samplesheet)
            shift
            SAMPLESHEET_OUT="$1"
            ;;
        -h|--help)
            usage
            ;;
        *)
            echo -e "${RED}[ERROR] Unknown option: $1${NC}"
            usage
            ;;
    esac
    shift
done

mkdir -p "${OUTDIR}"
mkdir -p "${OUTDIR}/tmp"

echo -e "${CYAN}==============================================================================${NC}"
echo -e "${BOLD}${BLUE}   🧬 Pull Hybrid Metagenomics Test Data using fasterq-dump 🧬   ${NC}"
echo -e "${CYAN}==============================================================================${NC}"
echo -e " 📂 Project Directory : ${PROJECT_DIR}"
echo -e " 📋 Metadata File     : ${METADATA_FILE}"
echo -e " 🎯 Target Subjects   : ${YELLOW}${SUBJECTS[*]}${NC}"
echo -e " 📁 Output Directory  : ${OUTDIR}"
echo -e " 📄 Samplesheet Out   : ${SAMPLESHEET_OUT}"
echo -e " 🧵 Threads           : ${THREADS}"
[ -n "${MAX_SPOTS}" ] && echo -e " ⚡ Mode              : ${GREEN}Quick Test (${MAX_SPOTS})${NC}" || echo -e " ⚡ Mode              : ${BLUE}Full Dataset${NC}"
echo -e "${CYAN}==============================================================================${NC}\n"

# สร้างไฟล์ samplesheet_hybrid.csv พร้อม header
echo "sample,fastq_1,fastq_2,long_reads" > "${SAMPLESHEET_OUT}"

for sid in "${SUBJECTS[@]}"; do
    echo -e "${BOLD}▶ กำลังค้นหาข้อมูลของ Subject: ${GREEN}${sid}${NC} ใน metadata...${NC}"

    # ดึง Illumina Run
    IL_RUN=$(grep -E ",ILLUMINA," "${METADATA_FILE}" | grep -E "_${sid}," | head -n 1 | cut -d',' -f1 || true)
    # ดึง Nanopore Run
    ONT_RUN=$(grep -E ",OXFORD_NANOPORE," "${METADATA_FILE}" | grep -E ",${sid}," | head -n 1 | cut -d',' -f1 || true)

    if [ -z "${IL_RUN}" ] || [ -z "${ONT_RUN}" ]; then
        echo -e "${RED}[ERROR] ไม่พบข้อมูลคู่ Illumina/ONT ของ Subject '${sid}' ใน ${METADATA_FILE}${NC}"
        continue
    fi

    echo -e "  • Illumina Run (Short Paired) : ${YELLOW}${IL_RUN}${NC}"
    echo -e "  • Nanopore Run (Long Single)  : ${YELLOW}${ONT_RUN}${NC}"

    # ── 1. ดึง Illumina Paired-End reads ──────────────────────────────────────
    FINAL_R1="${OUTDIR}/${sid}_illumina_1.fastq.gz"
    FINAL_R2="${OUTDIR}/${sid}_illumina_2.fastq.gz"

    if [ -f "${FINAL_R1}" ] && [ -f "${FINAL_R2}" ]; then
        echo -e "${GREEN}  ✓ พบไฟล์ Illumina FASTQ เดิมอยู่แล้ว ข้ามการดาวน์โหลด${NC}"
    else
        echo -e "${CYAN}  ⬇ กำลังรัน fasterq-dump สำหรับ Illumina (${IL_RUN})...${NC}"
        fasterq-dump "${IL_RUN}" \
            --split-files \
            --outdir "${OUTDIR}" \
            --temp "${OUTDIR}/tmp" \
            --threads "${THREADS}" \
            ${MAX_SPOTS}

        echo -e "${YELLOW}  📦 กำลังบีบอัดไฟล์ Illumina FASTQ ด้วย gzip/pigz...${NC}"
        if command -v pigz &> /dev/null; then
            pigz -p "${THREADS}" -f "${OUTDIR}/${IL_RUN}_1.fastq"
            pigz -p "${THREADS}" -f "${OUTDIR}/${IL_RUN}_2.fastq"
        else
            gzip -f "${OUTDIR}/${IL_RUN}_1.fastq"
            gzip -f "${OUTDIR}/${IL_RUN}_2.fastq"
        fi

        mv -f "${OUTDIR}/${IL_RUN}_1.fastq.gz" "${FINAL_R1}"
        mv -f "${OUTDIR}/${IL_RUN}_2.fastq.gz" "${FINAL_R2}"
        echo -e "${GREEN}  ✓ Illumina FASTQ พร้อมใช้งาน:${NC} ${FINAL_R1}, ${FINAL_R2}"
    fi

    # ── 2. ดึง Nanopore Long reads ─────────────────────────────────────────────
    FINAL_ONT="${OUTDIR}/${sid}_nanopore.fastq.gz"

    if [ -f "${FINAL_ONT}" ]; then
        echo -e "${GREEN}  ✓ พบไฟล์ Nanopore FASTQ เดิมอยู่แล้ว ข้ามการดาวน์โหลด${NC}"
    else
        echo -e "${CYAN}  ⬇ กำลังรัน fasterq-dump สำหรับ Nanopore (${ONT_RUN})...${NC}"
        fasterq-dump "${ONT_RUN}" \
            --outdir "${OUTDIR}" \
            --temp "${OUTDIR}/tmp" \
            --threads "${THREADS}" \
            ${MAX_SPOTS}

        echo -e "${YELLOW}  📦 กำลังบีบอัดไฟล์ Nanopore FASTQ ด้วย gzip/pigz...${NC}"
        ONT_RAW_FQ=$(ls "${OUTDIR}/${ONT_RUN}"*.fastq 2>/dev/null | head -n 1)
        if [ -n "${ONT_RAW_FQ}" ] && [ -f "${ONT_RAW_FQ}" ]; then
            if command -v pigz &> /dev/null; then
                pigz -p "${THREADS}" -f "${ONT_RAW_FQ}"
            else
                gzip -f "${ONT_RAW_FQ}"
            fi
            mv -f "${ONT_RAW_FQ}.gz" "${FINAL_ONT}"
            echo -e "${GREEN}  ✓ Nanopore FASTQ พร้อมใช้งาน:${NC} ${FINAL_ONT}"
        else
            echo -e "${RED}[ERROR] ไม่พบไฟล์ผลลัพธ์ Nanopore จาก fasterq-dump${NC}"
        fi
    fi

    # แปลง path ให้เป็น absolute path พร้อมใช้ forward slash สำหรับ Nextflow
    ABS_R1="$(cd "$(dirname "${FINAL_R1}")" && pwd)/$(basename "${FINAL_R1}")"
    ABS_R2="$(cd "$(dirname "${FINAL_R2}")" && pwd)/$(basename "${FINAL_R2}")"
    ABS_ONT="$(cd "$(dirname "${FINAL_ONT}")" && pwd)/$(basename "${FINAL_ONT}")"

    echo "${sid},${ABS_R1},${ABS_R2},${ABS_ONT}" >> "${SAMPLESHEET_OUT}"
    echo ""
done

# ลบโฟลเดอร์ชั่วคราว
rm -rf "${OUTDIR}/tmp"

echo -e "${GREEN}==============================================================================${NC}"
echo -e "${BOLD}${GREEN} 🎉 การดึงข้อมูลทดสอบเสร็จสมบูรณ์! พร้อมสำหรับรัน Hybrid Pipeline 🎉 ${NC}"
echo -e "${GREEN}==============================================================================${NC}"
echo -e " 📋 ตรวจสอบ Samplesheet ได้ที่: ${BOLD}${SAMPLESHEET_OUT}${NC}"
cat "${SAMPLESHEET_OUT}"
echo -e "${CYAN}==============================================================================${NC}"
echo -e "\nคุณสามารถสั่งรัน Hybrid Pipeline ได้ทันทีด้วยคำสั่ง:"
echo -e "  ${CYAN}chmod +x run_hybrid.sh${NC}"
echo -e "  ${CYAN}./run_hybrid.sh docker${NC}  หรือ  ${CYAN}./run_hybrid.sh conda${NC}\n"
