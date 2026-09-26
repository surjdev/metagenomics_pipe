#!/usr/bin/env bash
# ==============================================================================
# bin/generate_samplesheet_assembly_free.sh — Generate Samplesheet for Assembly-Free
# ==============================================================================
# Combines:
# 1. Old (เดิม) samples from metagenomic_Long_short (CD35, TD35)
# 2. New (ใหม่) samples from test_data/hybrid_test (CD22, CD3, TD22, TD3)
#
# Usage:
#   chmod +x bin/generate_samplesheet_assembly_free.sh
#   ./bin/generate_samplesheet_assembly_free.sh [OPTIONS]
# ==============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"

# ค่าเริ่มต้น
OLD_DIR="${PROJECT_DIR}/../metagenomic_Long_short"
if [ ! -d "${OLD_DIR}" ] && [ -d "/home/koraop/nob_dir/metagenomics/metagenomic_Long_short" ]; then
    OLD_DIR="/home/koraop/nob_dir/metagenomics/metagenomic_Long_short"
fi

NEW_DIR="${PROJECT_DIR}/test_data/hybrid_test"
OUT_CSV="${PROJECT_DIR}/samplesheet_compare_assembly_free.csv"
UPDATE_HYBRID=true

# Parse CLI arguments
while [ $# -gt 0 ]; do
    case "$1" in
        --old-dir)
            shift
            OLD_DIR="$1"
            ;;
        --new-dir)
            shift
            NEW_DIR="$1"
            ;;
        --out)
            shift
            OUT_CSV="$1"
            ;;
        --no-update-hybrid)
            UPDATE_HYBRID=false
            ;;
        -h|--help)
            echo "การใช้งาน: $(basename "$0") [--old-dir DIR] [--new-dir DIR] [--out FILE]"
            exit 0
            ;;
        *)
            echo "Unknown option: $1"
            exit 1
            ;;
    esac
    shift
done

GREEN='\033[0;32m'
CYAN='\033[0;36m'
YELLOW='\033[1;33m'
BOLD='\033[1m'
NC='\033[0m'

echo -e "${CYAN}==============================================================================${NC}"
echo -e "${BOLD}${GREEN} 📋 Generate Assembly-Free Samplesheet (Combined Old + New) 📋 ${NC}"
echo -e "${CYAN}==============================================================================${NC}"
echo -e " 📂 โฟลเดอร์ข้อมูลเดิม (Old Dir) : ${YELLOW}${OLD_DIR}${NC}"
echo -e " 📁 โฟลเดอร์ข้อมูลใหม่ (New Dir) : ${YELLOW}${NEW_DIR}${NC}"
echo -e " 📄 ไฟล์ Samplesheet ปลายทาง    : ${GREEN}${OUT_CSV}${NC}"
echo -e "${CYAN}==============================================================================${NC}\n"

# Helper ค้นหาไฟล์
resolve_file() {
    local candidate="$1"
    if [ -f "${candidate}" ]; then
        echo "${candidate}"
        return 0
    fi
    return 1
}

# สร้างหัวตาราง
echo "sample,fastq_1,fastq_2,long_reads" > "${OUT_CSV}"

add_sample() {
    local sid="$1"
    local r1="$2"
    local r2="$3"
    local ont="$4"
    local tag="$5"

    echo "${sid},${r1},${r2},${ont}" >> "${OUT_CSV}"
    echo -e "  ✓ [${tag}] เพิ่ม Subject: ${BOLD}${sid}${NC}"
    echo -e "      • Short R1: ${r1}"
    echo -e "      • Short R2: ${r2}"
    echo -e "      • Long ONT: ${ont}\n"
}

# ── 1. เพิ่มข้อมูลเดิม (Old: CD35, TD35) ──────────────────────────────────────
# ตรวจสอบว่าใน NEW_DIR มีไฟล์บีบอัดอยู่แล้วหรือไม่ ถ้าไม่มีให้ชี้ตรงไป OLD_DIR
if [ -f "${NEW_DIR}/CD35_illumina_1.fastq.gz" ] && [ -f "${NEW_DIR}/CD35_nanopore.fastq.gz" ]; then
    add_sample "CD35" "${NEW_DIR}/CD35_illumina_1.fastq.gz" "${NEW_DIR}/CD35_illumina_2.fastq.gz" "${NEW_DIR}/CD35_nanopore.fastq.gz" "OLD/Compressed"
else
    add_sample "CD35" "${OLD_DIR}/Short/SRR18490939_1.fastq" "${OLD_DIR}/Short/SRR18490939_2.fastq" "${OLD_DIR}/Long/SRR18491084.fastq" "OLD/Raw"
fi

if [ -f "${NEW_DIR}/TD35_illumina_1.fastq.gz" ] && [ -f "${NEW_DIR}/TD35_nanopore.fastq.gz" ]; then
    add_sample "TD35" "${NEW_DIR}/TD35_illumina_1.fastq.gz" "${NEW_DIR}/TD35_illumina_2.fastq.gz" "${NEW_DIR}/TD35_nanopore.fastq.gz" "OLD/Compressed"
else
    add_sample "TD35" "${OLD_DIR}/Short/SRR18491055_1.fastq" "${OLD_DIR}/Short/SRR18491055_2.fastq" "${OLD_DIR}/Long/SRR18490945.fastq" "OLD/Raw"
fi

# ── 2. เพิ่มข้อมูลใหม่ (New: CD22, CD3, TD22, TD3) ───────────────────────────
NEW_SAMPLES=("CD22" "CD3" "TD22" "TD3")
for sid in "${NEW_SAMPLES[@]}"; do
    r1="${NEW_DIR}/${sid}_illumina_1.fastq.gz"
    r2="${NEW_DIR}/${sid}_illumina_2.fastq.gz"
    ont="${NEW_DIR}/${sid}_nanopore.fastq.gz"
    add_sample "${sid}" "${r1}" "${r2}" "${ont}" "NEW"
done

if [ "${UPDATE_HYBRID}" = true ]; then
    cp -f "${OUT_CSV}" "${PROJECT_DIR}/samplesheet_hybrid.csv"
    echo -e "${GREEN}✓ อัปเดตไฟล์ samplesheet_hybrid.csv ให้ตรงกันเรียบร้อยแล้ว${NC}"
fi

echo -e "\n${GREEN}==============================================================================${NC}"
echo -e "${BOLD}${GREEN} 🎉 สร้าง Samplesheet สำเร็จเรียบร้อย! 🎉 ${NC}"
echo -e "${GREEN}==============================================================================${NC}"
cat "${OUT_CSV}"
echo -e "${CYAN}==============================================================================${NC}"
