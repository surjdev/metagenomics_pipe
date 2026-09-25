#!/usr/bin/env bash
# ==============================================================================
# bin/import_existing_hybrid_data.sh — Import and compress CD35 & TD35 FASTQ files
# ==============================================================================
# สคริปต์นี้ใช้สำหรับนำเข้าไฟล์ FASTQ เดิมของ CD35 และ TD35 ที่อยู่ในโฟลเดอร์
# metagenomic_Long_short มาบีบอัดเป็น .fastq.gz และจัดเก็บใน test_data/hybrid_test
# ตามโครงสร้างที่ samplesheet_hybrid.csv ใช้งาน
#
# การใช้งาน:
#   chmod +x bin/import_existing_hybrid_data.sh
#   ./bin/import_existing_hybrid_data.sh [SRC_DIR] [DEST_DIR]
# ==============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"

# พาธเริ่มต้นของโฟลเดอร์ต้นทาง metagenomic_Long_short
SRC_DIR="${1:-${PROJECT_DIR}/../metagenomic_Long_short}"
if [ ! -d "${SRC_DIR}" ] && [ -d "/home/koraop/nob_dir/metagenomics/metagenomic_Long_short" ]; then
    SRC_DIR="/home/koraop/nob_dir/metagenomics/metagenomic_Long_short"
fi

DEST_DIR="${2:-${PROJECT_DIR}/test_data/hybrid_test}"
THREADS=$(nproc 2>/dev/null || echo 4)

GREEN='\033[0;32m'
CYAN='\033[0;36m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BOLD='\033[1m'
NC='\033[0m'

echo -e "${CYAN}==============================================================================${NC}"
echo -e "${BOLD}${GREEN} 📦 Import & Compress Existing Hybrid Data (CD35 & TD35) 📦 ${NC}"
echo -e "${CYAN}==============================================================================${NC}"
echo -e " 📂 โฟลเดอร์ต้นทาง (Source) : ${YELLOW}${SRC_DIR}${NC}"
echo -e " 📁 โฟลเดอร์ปลายทาง (Dest)  : ${YELLOW}${DEST_DIR}${NC}"
echo -e " 🧵 จำนวน CPU Threads       : ${THREADS}"
echo -e "${CYAN}==============================================================================${NC}\n"

if [ ! -d "${SRC_DIR}" ]; then
    echo -e "${RED}[ERROR] ไม่พบโฟลเดอร์ต้นทาง: ${SRC_DIR}${NC}"
    echo -e "กรุณาระบุพาธที่ถูกต้อง เช่น: ./bin/import_existing_hybrid_data.sh /home/koraop/nob_dir/metagenomics/metagenomic_Long_short"
    exit 1
fi

mkdir -p "${DEST_DIR}"

compress_and_place() {
    local src_file="$1"
    local dest_gz="$2"
    local label="$3"

    if [ -f "${dest_gz}" ] && [ -s "${dest_gz}" ]; then
        echo -e "${GREEN}  ✓ พบไฟล์ปลายทางอยู่แล้ว ข้ามการประมวลผล:${NC} $(basename "${dest_gz}")"
        return 0
    fi

    if [ -f "${src_file}" ]; then
        echo -e "${CYAN}  ⏳ กำลังบีบอัด ${label}:${NC} $(basename "${src_file}") -> $(basename "${dest_gz}")..."
        if command -v pigz &> /dev/null; then
            pigz -c -p "${THREADS}" "${src_file}" > "${dest_gz}"
        else
            gzip -c "${src_file}" > "${dest_gz}"
        fi
        echo -e "${GREEN}  ✓ เสร็จสมบูรณ์:${NC} ${dest_gz}"
    elif [ -f "${src_file}.gz" ]; then
        echo -e "${CYAN}  🔗 พบไฟล์ .gz ต้นทาง กำลังคัดลอก/เชื่อมโยง:${NC} $(basename "${src_file}.gz") -> $(basename "${dest_gz}")..."
        cp -f "${src_file}.gz" "${dest_gz}"
        echo -e "${GREEN}  ✓ เสร็จสมบูรณ์:${NC} ${dest_gz}"
    else
        echo -e "${RED}  ❌ ไม่พบไฟล์ต้นทาง:${NC} ${src_file}"
        return 1
    fi
}

# ── 1. นำเข้า CD35 ────────────────────────────────────────────────────────────
echo -e "${BOLD}▶ นำเข้าข้อมูลตัวอย่าง: ${GREEN}CD35${NC} (SRR18490939 Short, SRR18491084 Long)...${NC}"
compress_and_place "${SRC_DIR}/Short/SRR18490939_1.fastq" "${DEST_DIR}/CD35_illumina_1.fastq.gz" "CD35 Illumina R1"
compress_and_place "${SRC_DIR}/Short/SRR18490939_2.fastq" "${DEST_DIR}/CD35_illumina_2.fastq.gz" "CD35 Illumina R2"
compress_and_place "${SRC_DIR}/Long/SRR18491084.fastq"    "${DEST_DIR}/CD35_nanopore.fastq.gz"   "CD35 Nanopore Long"
echo ""

# ── 2. นำเข้า TD35 ────────────────────────────────────────────────────────────
echo -e "${BOLD}▶ นำเข้าข้อมูลตัวอย่าง: ${GREEN}TD35${NC} (SRR18491055 Short, SRR18490945 Long)...${NC}"
compress_and_place "${SRC_DIR}/Short/SRR18491055_1.fastq" "${DEST_DIR}/TD35_illumina_1.fastq.gz" "TD35 Illumina R1"
compress_and_place "${SRC_DIR}/Short/SRR18491055_2.fastq" "${DEST_DIR}/TD35_illumina_2.fastq.gz" "TD35 Illumina R2"
compress_and_place "${SRC_DIR}/Long/SRR18490945.fastq"    "${DEST_DIR}/TD35_nanopore.fastq.gz"   "TD35 Nanopore Long"
echo ""

echo -e "${GREEN}==============================================================================${NC}"
echo -e "${BOLD}${GREEN} 🎉 การนำเข้าและบีบอัด CD35 และ TD35 สำเร็จเรียบร้อย! 🎉 ${NC}"
echo -e "${GREEN}==============================================================================${NC}"
ls -lh "${DEST_DIR}"/CD35* "${DEST_DIR}"/TD35* 2>/dev/null || true
echo -e "${CYAN}==============================================================================${NC}\n"
