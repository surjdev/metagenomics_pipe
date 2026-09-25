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
#   --subjects <ID..> กำหนด Subject IDs ที่ต้องการดึง (ค่าเริ่มต้น: CD22 CD3 TD22 TD3 | ข้าม CD35, TD35 เนื่องจากติดตั้งแล้ว)
#   --skip-subjects   กำหนด Subject IDs ที่ต้องการข้าม (ค่าเริ่มต้น: CD35 TD35)
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
# ข้าม CD35 และ TD35 เนื่องจากผู้ใช้ดาวน์โหลด/ติดตั้งข้อมูลไว้แล้ว
SUBJECTS=("CD22" "CD3" "TD22" "TD3")
SKIPPED_SUBJECTS=("CD35" "TD35")
FROM_SAMPLESHEET=""
USE_PREFETCH=true
KEEP_SRA=false
MAX_SIZE="200G"
SHOW_PROGRESS=true

# ตารางจับคู่ SRA Run Accessions (Long key / Short key) ตาม metadata
declare -A SHORT_KEYS=(
    ["CD35"]="SRR18490939"
    ["CD22"]="SRR18491198"
    ["CD3"]="SRR18491210"
    ["TD35"]="SRR18491055"
    ["TD22"]="SRR18491097"
    ["TD3"]="SRR18491118"
)

declare -A LONG_KEYS=(
    ["CD35"]="SRR18491084"
    ["CD22"]="SRR18491185"
    ["CD3"]="SRR18491206"
    ["TD35"]="SRR18490945"
    ["TD22"]="SRR18491015"
    ["TD3"]="SRR18491036"
)

# สีสำหรับการแสดงผล
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

usage() {
    echo -e "${BOLD}การใช้งาน:${NC} $(basename "$0") [OPTIONS]

${BOLD}Options:${NC}
  --test, -t               ดึงเฉพาะ 50,000 reads แรกต่อตัวอย่าง (-X 50000) เพื่อทดสอบอย่างรวดเร็ว
  --full, -f               ดึงข้อมูลเต็มทุก reads (Full run)
  --subjects <S1 S2...>    ระบุชื่อ Subject ที่ต้องการดึง (default: CD22 CD3 TD22 TD3 | ข้าม CD35, TD35 เนื่องจากติดตั้งแล้ว)
  --skip-subjects <S1..>   ระบุชื่อ Subject ที่ต้องการข้ามเพิ่มเติม (default: CD35 TD35)
  --from-samplesheet <CSV> โหลดรายชื่อ Subjects จากคอลัมน์แรกของ samplesheet ที่ระบุ
  --outdir <DIR>           ระบุโฟลเดอร์ปลายทาง (default: test_data/hybrid_test)
  --threads <N>            จำนวน threads สำหรับ fasterq-dump และ pigz (default: ${THREADS})
  --max-size <SIZE>        ขนาดสูงสุดสำหรับ prefetch (default: 200G)
  --keep-sra               เก็บไฟล์ .sra ดิบไว้ ไม่ลบออกหลังแตก FASTQ เสร็จ (default: ลบออกเพื่อประหยัดเนื้อที่)
  --no-prefetch            ไม่ใช้ prefetch (สั่ง fasterq-dump ดึงตรงจากอินเทอร์เน็ต)
  --no-progress            ปิดการแสดง Progress Bar ของ prefetch และ fasterq-dump
  --samplesheet <CSV>      ระบุไฟล์ samplesheet ปลายทาง (default: samplesheet_hybrid.csv)
  -h, --help               แสดงข้อความช่วยเหลือ

${BOLD}ตัวอย่างคำสั่ง:${NC}
  ./bin/pull_hybrid_data_fasterq.sh --full              # ดาวน์โหลดข้อมูลเต็มผ่าน prefetch + fasterq-dump พร้อมแสดง progress
  ./bin/pull_hybrid_data_fasterq.sh --test              # โหมดทดสอบเร็ว (50,000 reads)
  ./bin/pull_hybrid_data_fasterq.sh --from-samplesheet samplesheet_hybrid.csv --test
  ./bin/pull_hybrid_data_fasterq.sh --subjects CD22 TD22 --keep-sra"
    exit 0
}

# Parse CLI arguments
while [ $# -gt 0 ]; do
    case "$1" in
        --test|-t)
            MAX_SPOTS="50000"
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
        --skip-subjects)
            shift
            SKIPPED_SUBJECTS=()
            while [ $# -gt 0 ] && [[ "$1" != --* ]]; do
                SKIPPED_SUBJECTS+=("$1")
                shift
            done
            continue
            ;;
        --from-samplesheet)
            shift
            FROM_SAMPLESHEET="$1"
            ;;
        --threads)
            shift
            THREADS="$1"
            ;;
        --outdir)
            shift
            OUTDIR="$1"
            ;;
        --max-size)
            shift
            MAX_SIZE="$1"
            ;;
        --keep-sra)
            KEEP_SRA=true
            ;;
        --no-prefetch)
            USE_PREFETCH=false
            ;;
        --no-progress)
            SHOW_PROGRESS=false
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

# ตรวจสอบว่ามี fasterq-dump และ prefetch หรือไม่
MISSING_DEPS=()
if ! command -v fasterq-dump &> /dev/null; then
    MISSING_DEPS+=("fasterq-dump")
fi
if [ "${USE_PREFETCH}" = true ] && ! command -v prefetch &> /dev/null; then
    MISSING_DEPS+=("prefetch")
fi

if [ ${#MISSING_DEPS[@]} -gt 0 ]; then
    echo -e "${RED}[ERROR] ไม่พบคำสั่ง: ${MISSING_DEPS[*]} ในระบบ!${NC}"
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

# หากระบุ --from-samplesheet ให้ดึงรายชื่อ Subjects จาก Samplesheet CSV
if [ -n "${FROM_SAMPLESHEET}" ]; then
    if [ ! -f "${FROM_SAMPLESHEET}" ]; then
        echo -e "${RED}[ERROR] ไม่พบไฟล์ samplesheet: ${FROM_SAMPLESHEET}${NC}"
        exit 1
    fi
    RAW_SUBS=($(awk -F',' 'NR>1 {gsub(/\r/, ""); if ($1 != "") print $1}' "${FROM_SAMPLESHEET}"))
    SUBJECTS=()
    for s in "${RAW_SUBS[@]}"; do
        if [[ " ${SKIPPED_SUBJECTS[*]} " =~ " ${s} " ]]; then
            echo -e "${YELLOW}⏩ ข้าม Subject '${s}' จาก Samplesheet (ติดตั้ง/มีข้อมูลแล้ว)${NC}"
        else
            SUBJECTS+=("${s}")
        fi
    done
    echo -e "${CYAN}ℹ️  Subjects ที่จะดาวน์โหลด: (${#SUBJECTS[@]} subjects: ${SUBJECTS[*]})${NC}"
fi

if [[ "${OUTDIR}" != /* ]]; then
    OUTDIR="${PROJECT_DIR}/${OUTDIR}"
fi
if [[ "${SAMPLESHEET_OUT}" != /* ]]; then
    SAMPLESHEET_OUT="${PROJECT_DIR}/${SAMPLESHEET_OUT}"
fi

mkdir -p "${OUTDIR}"
mkdir -p "${OUTDIR}/tmp"
SRA_DIR="${OUTDIR}/sra"
[ "${USE_PREFETCH}" = true ] && mkdir -p "${SRA_DIR}"

echo -e "${CYAN}==============================================================================${NC}"
echo -e "${BOLD}${BLUE}   🧬 Pull Hybrid Metagenomics Test Data using fasterq-dump 🧬   ${NC}"
echo -e "${CYAN}==============================================================================${NC}"
echo -e " 📂 Project Directory : ${PROJECT_DIR}"
echo -e " 📋 Metadata File     : ${METADATA_FILE}"
echo -e " 🎯 Target Subjects   : ${YELLOW}${SUBJECTS[*]}${NC}"
echo -e " ⏩ Skipped Subjects  : ${CYAN}${SKIPPED_SUBJECTS[*]} (ข้ามเนื่องจากติดตั้งแล้ว)${NC}"
echo -e " 📁 Output Directory  : ${OUTDIR}"
echo -e " 📄 Samplesheet Out   : ${SAMPLESHEET_OUT}"
echo -e " 🧵 Threads           : ${THREADS}"
[ -n "${MAX_SPOTS}" ] && echo -e " ⚡ Mode              : ${GREEN}Quick Test (${MAX_SPOTS} reads)${NC}" || echo -e " ⚡ Mode              : ${BLUE}Full Dataset${NC}"
if [ "${USE_PREFETCH}" = true ]; then
    echo -e " 📥 Prefetch Engine   : ${GREEN}Enabled${NC} (Max Size: ${MAX_SIZE}, Progress: ${SHOW_PROGRESS})"
else
    echo -e " 📥 Prefetch Engine   : ${YELLOW}Disabled${NC} (Direct fasterq-dump stream)"
fi
echo -e "${CYAN}==============================================================================${NC}\n"

# ฟังก์ชันตรวจสอบ argument สำหรับ --progress ของ prefetch (รองรับทั้ง v2.10.x และ v3.x)
get_prefetch_progress_args() {
    if [ "${SHOW_PROGRESS}" = false ]; then
        if prefetch --help 2>&1 | grep -q -- '--progress <value>'; then
            echo "--progress 0"
        fi
        return 0
    fi
    # ใน SRA Toolkit 2.10.x, --progress ต้องการตัวเลขจำนวนนาที (เช่น 1)
    if prefetch --help 2>&1 | grep -q -- '--progress <value>'; then
        echo "--progress 1"
    else
        echo "--progress"
    fi
}

# ฟังก์ชันค้นหาไฟล์ .sra ในระบบหลังการดาวน์โหลด
find_sra_archive() {
    local acc="$1"
    local sra_dir="$2"
    local candidates=(
        "${sra_dir}/${acc}/${acc}.sra"
        "${sra_dir}/${acc}.sra"
        "${HOME}/ncbi/public/sra/${acc}.sra"
        "${HOME}/ncbi/public/sra/${acc}/${acc}.sra"
        "./${acc}/${acc}.sra"
        "./${acc}.sra"
    )
    for c in "${candidates[@]}"; do
        if [ -f "${c}" ] && [ -s "${c}" ]; then
            echo "${c}"
            return 0
        fi
    done
    # ค้นหาไฟล์ .sra ภายในโฟลเดอร์ sra_dir เผื่อ sra-tools เก็บใน subfolder อื่น
    local found
    found=$(find "${sra_dir}" -name "${acc}*.sra" -type f 2>/dev/null | head -n 1 || true)
    if [ -n "${found}" ] && [ -s "${found}" ]; then
        echo "${found}"
        return 0
    fi
    return 1
}

# ฟังก์ชันดาวน์โหลดไฟล์ .sra: ลอง prefetch ก่อน หากไม่ได้จะสลับไป wget/curl จาก AWS S3 อัตโนมัติ
download_sra() {
    local acc="$1"
    local sra_dir="$2"

    # 1. เช็กว่ามีไฟล์ SRA เดิมอยู่แล้วหรือไม่
    local existing
    existing=$(find_sra_archive "${acc}" "${sra_dir}" || true)
    if [ -n "${existing}" ] && [ -f "${existing}" ]; then
        echo -e "${GREEN}  ✓ พบไฟล์ SRA ในเครื่องแล้ว: ${existing} ($(du -h "${existing}" 2>/dev/null | cut -f1 || echo ""))${NC}"
        return 0
    fi

    mkdir -p "${sra_dir}"
    local sra_found=""

    # 2. ลองดาวน์โหลดด้วย prefetch
    if [ "${USE_PREFETCH}" = true ] && command -v prefetch &>/dev/null; then
        echo -e "${CYAN}  ⬇ [1/2: prefetch] กำลังดาวน์โหลดไฟล์ดิบ SRA: ${YELLOW}${acc}${CYAN} (Max Size: ${MAX_SIZE})...${NC}"
        local prefetch_args=("-O" "${sra_dir}" "-X" "${MAX_SIZE}")
        local prog_args=($(get_prefetch_progress_args))
        [ ${#prog_args[@]} -gt 0 ] && prefetch_args+=("${prog_args[@]}")
        if prefetch --help 2>&1 | grep -q -- '--transport'; then
            prefetch_args+=("--transport" "http")
        fi
        prefetch_args+=("${acc}")

        prefetch "${prefetch_args[@]}" || true
        sra_found=$(find_sra_archive "${acc}" "${sra_dir}" || true)
    fi

    # 3. หาก prefetch ล้มเหลวหรือไม่ได้ไฟล์ ให้ Fallback ดาวน์โหลดตรงจาก AWS S3 Open Data ด้วย wget / curl
    if [ -z "${sra_found}" ] || [ ! -f "${sra_found}" ]; then
        echo -e "${YELLOW}  ⚠️ ไม่พบไฟล์ SRA จาก prefetch สลับไปดาวน์โหลดตรงจาก AWS S3 ด้วย wget/curl อัตโนมัติ...${NC}"
        local s3_url="https://sra-pub-run-odp.s3.amazonaws.com/sra/${acc}/${acc}"
        mkdir -p "${sra_dir}/${acc}"
        local direct_file="${sra_dir}/${acc}/${acc}.sra"

        if command -v wget &>/dev/null; then
            echo -e "${CYAN}  ⬇ [Direct Download: wget] กำลังดึงไฟล์ (resume/retry enabled): ${s3_url}${NC}"
            wget -c --tries=10 --timeout=30 "${s3_url}" -O "${direct_file}" || true
        elif command -v curl &>/dev/null; then
            echo -e "${CYAN}  ⬇ [Direct Download: curl] กำลังดึงไฟล์ (resume/retry enabled): ${s3_url}${NC}"
            curl -fSL -C - --retry 10 --connect-timeout 30 "${s3_url}" -o "${direct_file}" || true
        fi

        sra_found=$(find_sra_archive "${acc}" "${sra_dir}" || true)
    fi

    # 4. ตรวจสอบยืนยันว่าได้ไฟล์จริง
    if [ -n "${sra_found}" ] && [ -f "${sra_found}" ] && [ -s "${sra_found}" ]; then
        echo -e "${GREEN}  ✓ ยืนยันพบไฟล์ SRA ในเครื่อง:${NC} ${sra_found} ($(du -h "${sra_found}" 2>/dev/null | cut -f1 || echo ""))"
        return 0
    else
        echo -e "${RED}  ❌ [ERROR] ไม่สามารถดาวน์โหลดไฟล์ SRA สำหรับ ${acc} ได้จากทุกช่องทาง!${NC}"
        return 1
    fi
}

# ฟังก์ชันค้นหาไฟล์ FASTQ ของ Illumina (Paired-End) ที่แตกออกมาจาก fasterq-dump หรือ fastq-dump
locate_illumina_fastqs() {
    local acc="$1"
    local target_dir="$2"
    local r1=""
    local r2=""

    # 1. ค้นหา Read 1 (R1)
    local candidates_r1=(
        "${target_dir}/${acc}_1.fastq"
        "${target_dir}/${acc}.sra_1.fastq"
        "${target_dir}/${acc}.fastq_1.fastq"
        "${PROJECT_DIR}/${acc}_1.fastq"
        "${PROJECT_DIR}/${acc}.sra_1.fastq"
        "${target_dir}/sra/${acc}/${acc}_1.fastq"
        "${target_dir}/sra/${acc}/${acc}.sra_1.fastq"
    )
    for c in "${candidates_r1[@]}"; do
        if [ -f "${c}" ] && [ -s "${c}" ]; then
            r1="${c}"
            break
        fi
    done

    if [ -z "${r1}" ]; then
        r1=$(find "${target_dir}" "${PROJECT_DIR}" -maxdepth 3 -type f \( -name "${acc}*_1.fastq" -o -name "${acc}*.sra_1.fastq" -o -name "${acc}*R1*.fastq" \) 2>/dev/null | head -n 1 || true)
    fi

    # 2. ค้นหา Read 2 (R2)
    local candidates_r2=(
        "${target_dir}/${acc}_2.fastq"
        "${target_dir}/${acc}.sra_2.fastq"
        "${target_dir}/${acc}.fastq_2.fastq"
        "${PROJECT_DIR}/${acc}_2.fastq"
        "${PROJECT_DIR}/${acc}.sra_2.fastq"
        "${target_dir}/sra/${acc}/${acc}_2.fastq"
        "${target_dir}/sra/${acc}/${acc}.sra_2.fastq"
    )
    for c in "${candidates_r2[@]}"; do
        if [ -f "${c}" ] && [ -s "${c}" ]; then
            r2="${c}"
            break
        fi
    done

    if [ -z "${r2}" ]; then
        r2=$(find "${target_dir}" "${PROJECT_DIR}" -maxdepth 3 -type f \( -name "${acc}*_2.fastq" -o -name "${acc}*.sra_2.fastq" -o -name "${acc}*R2*.fastq" \) 2>/dev/null | head -n 1 || true)
    fi

    echo "${r1}|${r2}"
}

# ฟังก์ชันค้นหาไฟล์ FASTQ ของ Nanopore (Single-End)
locate_nanopore_fastq() {
    local acc="$1"
    local target_dir="$2"
    local fq=""

    local candidates=(
        "${target_dir}/${acc}.fastq"
        "${target_dir}/${acc}.sra.fastq"
        "${PROJECT_DIR}/${acc}.fastq"
        "${PROJECT_DIR}/${acc}.sra.fastq"
        "${target_dir}/sra/${acc}/${acc}.fastq"
        "${target_dir}/sra/${acc}/${acc}.sra.fastq"
    )
    for c in "${candidates[@]}"; do
        if [ -f "${c}" ] && [ -s "${c}" ]; then
            fq="${c}"
            break
        fi
    done

    if [ -z "${fq}" ]; then
        fq=$(find "${target_dir}" "${PROJECT_DIR}" -maxdepth 3 -type f -name "${acc}*.fastq" ! -name "*_1.fastq" ! -name "*_2.fastq" ! -name "*.sra_1.fastq" ! -name "*.sra_2.fastq" 2>/dev/null | head -n 1 || true)
    fi

    echo "${fq}"
}

# โหลดข้อมูล samplesheet เดิม (เพื่อรักษาแถวของ CD35, TD35 หรือตัวอย่างที่มีอยู่เดิม)
declare -A EXISTING_SHEET_ROWS
if [ -f "${SAMPLESHEET_OUT}" ]; then
    while IFS=',' read -r s_id f1 f2 lr || [ -n "$s_id" ]; do
        s_id=$(echo "${s_id}" | tr -d '\r\n ')
        if [ -n "${s_id}" ] && [ "${s_id}" != "sample" ]; then
            f1=$(echo "${f1}" | tr -d '\r\n')
            f2=$(echo "${f2}" | tr -d '\r\n')
            lr=$(echo "${lr}" | tr -d '\r\n')
            EXISTING_SHEET_ROWS["${s_id}"]="${s_id},${f1},${f2},${lr}"
        fi
    done < "${SAMPLESHEET_OUT}"
fi

# ตรวจสอบและนำเข้าไฟล์ข้อมูลเดิมของ CD35 / TD35 จาก metagenomic_Long_short อัตโนมัติ (หากมี)
EXISTING_DATA_DIR=""
if [ -d "${PROJECT_DIR}/../metagenomic_Long_short" ]; then
    EXISTING_DATA_DIR="${PROJECT_DIR}/../metagenomic_Long_short"
elif [ -d "/home/koraop/nob_dir/metagenomics/metagenomic_Long_short" ]; then
    EXISTING_DATA_DIR="/home/koraop/nob_dir/metagenomics/metagenomic_Long_short"
fi

if [ -n "${EXISTING_DATA_DIR}" ] && [ -f "${SCRIPT_DIR}/import_existing_hybrid_data.sh" ]; then
    echo -e "${CYAN}🔍 ตรวจพบไฟล์ข้อมูล CD35 / TD35 ที่ติดตั้งไว้แล้วใน: ${YELLOW}${EXISTING_DATA_DIR}${NC}"
    bash "${SCRIPT_DIR}/import_existing_hybrid_data.sh" "${EXISTING_DATA_DIR}" "${OUTDIR}"
fi

for sid in "${SUBJECTS[@]}"; do
    if [[ " ${SKIPPED_SUBJECTS[*]} " =~ " ${sid} " ]]; then
        echo -e "${YELLOW}⏩ ข้ามการดาวน์โหลด Subject: ${sid} (ข้ามเนื่องจากติดตั้งแล้ว)${NC}\n"
        continue
    fi
    echo -e "${BOLD}▶ กำลังค้นหาข้อมูลของ Subject: ${GREEN}${sid}${NC} ใน metadata...${NC}"

    # ดึง Illumina Run
    IL_RUN="${SHORT_KEYS[${sid}]:-}"
    if [ -z "${IL_RUN}" ] && [ -f "${METADATA_FILE}" ]; then
        IL_RUN=$(grep -E ",ILLUMINA," "${METADATA_FILE}" | grep -E "_${sid}," | head -n 1 | cut -d',' -f1 || true)
    fi

    # ดึง Nanopore Run
    ONT_RUN="${LONG_KEYS[${sid}]:-}"
    if [ -z "${ONT_RUN}" ] && [ -f "${METADATA_FILE}" ]; then
        ONT_RUN=$(grep -E ",OXFORD_NANOPORE," "${METADATA_FILE}" | grep -E ",${sid}," | head -n 1 | cut -d',' -f1 || true)
    fi

    if [ -z "${IL_RUN}" ] || [ -z "${ONT_RUN}" ]; then
        echo -e "${RED}[ERROR] ไม่พบข้อมูลคู่ Illumina/ONT ของ Subject '${sid}'${NC}"
        continue
    fi

    echo -e "  • Illumina Run (Short Paired) : ${YELLOW}${IL_RUN}${NC}"
    echo -e "  • Nanopore Run (Long Single)  : ${YELLOW}${ONT_RUN}${NC}"

    # ── 1. ดึง Illumina Paired-End reads ──────────────────────────────────────
    FINAL_R1="${OUTDIR}/${sid}_illumina_1.fastq.gz"
    FINAL_R2="${OUTDIR}/${sid}_illumina_2.fastq.gz"

    if [ -f "${FINAL_R1}" ] && [ -s "${FINAL_R1}" ] && [ -f "${FINAL_R2}" ] && [ -s "${FINAL_R2}" ]; then
        echo -e "${GREEN}  ✓ พบไฟล์ Illumina FASTQ เดิมอยู่แล้ว ข้ามการดาวน์โหลด:${NC} ${FINAL_R1}, ${FINAL_R2}"
    else
        # 1.1 ตรวจสอบว่ามีไฟล์ FASTQ ดิบที่แตกไว้แล้วในเครื่องจากการรันครั้งก่อนหรือไม่
        LOCATED=$(locate_illumina_fastqs "${IL_RUN}" "${OUTDIR}")
        RAW_R1="${LOCATED%%|*}"
        RAW_R2="${LOCATED##*|}"

        if [ -n "${RAW_R1}" ] && [ -f "${RAW_R1}" ] && [ -n "${RAW_R2}" ] && [ -f "${RAW_R2}" ]; then
            echo -e "${GREEN}  ✓ ตรวจพบไฟล์ FASTQ ดิบที่แตกไว้แล้วในเครื่อง!${NC}"
            echo -e "     • R1: ${RAW_R1} ($(du -h "${RAW_R1}" 2>/dev/null | cut -f1))"
            echo -e "     • R2: ${RAW_R2} ($(du -h "${RAW_R2}" 2>/dev/null | cut -f1))"
            echo -e "${CYAN}    ข้ามขั้นตอนแตกไฟล์ และเริ่มบีบอัดทันที...${NC}"
        else
            # 1.2 หากยังไม่มีไฟล์ FASTQ ดิบ ให้เตรียม SRA และแตกไฟล์
            SRA_TARGET=""
            if [ "${USE_PREFETCH}" = true ]; then
                download_sra "${IL_RUN}" "${SRA_DIR}"
                SRA_TARGET=$(find_sra_archive "${IL_RUN}" "${SRA_DIR}" || true)
                if [ -z "${SRA_TARGET}" ] || [ ! -f "${SRA_TARGET}" ]; then
                    echo -e "${RED}  ❌ [ERROR] ไม่พบไฟล์ SRA สำหรับ ${IL_RUN} สคริปต์หยุดทำงานเพื่อป้องกัน Segmentation Fault${NC}"
                    exit 1
                fi
            else
                SRA_TARGET="${IL_RUN}"
            fi

            # ถ้าอยู่ในโหมดทดสอบเร็ว (--test)
            if [ -n "${MAX_SPOTS}" ]; then
                echo -e "${CYAN}  🔄 [2/2: fastq-dump/subsample] กำลังสกัดเฉพาะ ${MAX_SPOTS} reads สำหรับทดสอบ (${IL_RUN})...${NC}"
                if command -v fastq-dump &>/dev/null; then
                    fastq-dump -X "${MAX_SPOTS}" --split-3 -O "${OUTDIR}" "${SRA_TARGET}"
                else
                    DUMP_ARGS=("${SRA_TARGET}" "--split-3" "--outdir" "${OUTDIR}" "--temp" "${OUTDIR}/tmp" "--threads" "${THREADS}")
                    [ "${SHOW_PROGRESS}" = true ] && DUMP_ARGS+=("--progress")
                    fasterq-dump "${DUMP_ARGS[@]}"
                fi
            else
                echo -e "${CYAN}  🔄 [2/2: fasterq-dump] กำลังแตกไฟล์ SRA เป็น Paired-End FASTQ (${IL_RUN})...${NC}"
                DUMP_ARGS=("${SRA_TARGET}" "--split-3" "--outdir" "${OUTDIR}" "--temp" "${OUTDIR}/tmp" "--threads" "${THREADS}")
                [ "${SHOW_PROGRESS}" = true ] && DUMP_ARGS+=("--progress")
                fasterq-dump "${DUMP_ARGS[@]}"
            fi

            # ค้นหาไฟล์ที่เพิ่งแตกออกมา
            LOCATED=$(locate_illumina_fastqs "${IL_RUN}" "${OUTDIR}")
            RAW_R1="${LOCATED%%|*}"
            RAW_R2="${LOCATED##*|}"

            # หากใช้ fasterq-dump ในโหมด test ให้ตัดเฉพาะจำนวน reads ที่ต้องการ
            if [ -n "${MAX_SPOTS}" ] && ! command -v fastq-dump &>/dev/null; then
                if [ -n "${RAW_R1}" ] && [ -f "${RAW_R1}" ]; then
                    head -n $((MAX_SPOTS * 4)) "${RAW_R1}" > "${RAW_R1}.sub" && mv -f "${RAW_R1}.sub" "${RAW_R1}"
                fi
                if [ -n "${RAW_R2}" ] && [ -f "${RAW_R2}" ]; then
                    head -n $((MAX_SPOTS * 4)) "${RAW_R2}" > "${RAW_R2}.sub" && mv -f "${RAW_R2}.sub" "${RAW_R2}"
                fi
            fi
        fi

        if [ -z "${RAW_R1}" ] || [ ! -f "${RAW_R1}" ] || [ -z "${RAW_R2}" ] || [ ! -f "${RAW_R2}" ]; then
            echo -e "${RED}  ❌ [ERROR] ไม่พบไฟล์ FASTQ ที่แตกออกมาสำหรับ ${IL_RUN}${NC}"
            echo -e "${YELLOW}  กำลังแสดงไฟล์ในโฟลเดอร์ ${OUTDIR}:${NC}"
            ls -la "${OUTDIR}"
            exit 1
        fi

        echo -e "${YELLOW}  📦 กำลังบีบอัดไฟล์ Illumina FASTQ ด้วย gzip/pigz...${NC}"
        echo -e "     • R1: $(basename "${RAW_R1}") -> $(basename "${FINAL_R1}")"
        echo -e "     • R2: $(basename "${RAW_R2}") -> $(basename "${FINAL_R2}")"

        if command -v pigz &> /dev/null; then
            pigz -p "${THREADS}" -f "${RAW_R1}"
            pigz -p "${THREADS}" -f "${RAW_R2}"
        else
            gzip -f "${RAW_R1}"
            gzip -f "${RAW_R2}"
        fi

        mv -f "${RAW_R1}.gz" "${FINAL_R1}"
        mv -f "${RAW_R2}.gz" "${FINAL_R2}"

        # ลบไฟล์ orphan singleton (หากมี)
        rm -f "${OUTDIR}/${IL_RUN}.fastq" "${OUTDIR}/${IL_RUN}.sra.fastq" "${OUTDIR}/${IL_RUN}.sra_3.fastq" 2>/dev/null || true
        echo -e "${GREEN}  ✓ Illumina FASTQ พร้อมใช้งาน:${NC} ${FINAL_R1}, ${FINAL_R2}"

        # ลบไฟล์ SRA ดิบหากไม่ได้เปิด --keep-sra และยืนยันว่าได้ไฟล์ FASTQ.gz สำเร็จแล้ว
        if [ "${USE_PREFETCH}" = true ] && [ "${KEEP_SRA}" = false ]; then
            if [ -f "${FINAL_R1}" ] && [ -s "${FINAL_R1}" ] && [ -f "${FINAL_R2}" ] && [ -s "${FINAL_R2}" ]; then
                echo -e "${CYAN}  🧹 ลบไฟล์ SRA ดิบ (${IL_RUN}) เพื่อประหยัดเนื้อที่ดิสก์${NC}"
                [ -n "${SRA_TARGET:-}" ] && [ -f "${SRA_TARGET}" ] && rm -f "${SRA_TARGET}"
                [ -d "${SRA_DIR}/${IL_RUN}" ] && rm -rf "${SRA_DIR}/${IL_RUN}"
            fi
        fi
    fi

    # ── 2. ดึง Nanopore Long reads ─────────────────────────────────────────────
    FINAL_ONT="${OUTDIR}/${sid}_nanopore.fastq.gz"

    if [ -f "${FINAL_ONT}" ] && [ -s "${FINAL_ONT}" ]; then
        echo -e "${GREEN}  ✓ พบไฟล์ Nanopore FASTQ เดิมอยู่แล้ว ข้ามการดาวน์โหลด:${NC} ${FINAL_ONT}"
    else
        # 2.1 ตรวจสอบว่ามีไฟล์ Nanopore FASTQ ดิบอยู่แล้วหรือไม่
        ONT_RAW_FQ=$(locate_nanopore_fastq "${ONT_RUN}" "${OUTDIR}")

        if [ -n "${ONT_RAW_FQ}" ] && [ -f "${ONT_RAW_FQ}" ]; then
            echo -e "${GREEN}  ✓ ตรวจพบไฟล์ Nanopore FASTQ ดิบที่แตกไว้แล้วในเครื่อง!${NC}"
            echo -e "     • ONT: ${ONT_RAW_FQ} ($(du -h "${ONT_RAW_FQ}" 2>/dev/null | cut -f1))"
            echo -e "${CYAN}    ข้ามขั้นตอนแตกไฟล์ และเริ่มบีบอัดทันที...${NC}"
        else
            # 2.2 แตกไฟล์ SRA Nanopore
            SRA_TARGET=""
            if [ "${USE_PREFETCH}" = true ]; then
                download_sra "${ONT_RUN}" "${SRA_DIR}"
                SRA_TARGET=$(find_sra_archive "${ONT_RUN}" "${SRA_DIR}" || true)
                if [ -z "${SRA_TARGET}" ] || [ ! -f "${SRA_TARGET}" ]; then
                    echo -e "${RED}  ❌ [ERROR] ไม่พบไฟล์ SRA สำหรับ ${ONT_RUN} สคริปต์หยุดทำงานเพื่อป้องกัน Segmentation Fault${NC}"
                    exit 1
                fi
            else
                SRA_TARGET="${ONT_RUN}"
            fi

            if [ -n "${MAX_SPOTS}" ]; then
                echo -e "${CYAN}  🔄 [2/2: fastq-dump/subsample] กำลังสกัดเฉพาะ ${MAX_SPOTS} reads สำหรับทดสอบ (${ONT_RUN})...${NC}"
                if command -v fastq-dump &>/dev/null; then
                    fastq-dump -X "${MAX_SPOTS}" -O "${OUTDIR}" "${SRA_TARGET}"
                else
                    DUMP_ARGS=("${SRA_TARGET}" "--outdir" "${OUTDIR}" "--temp" "${OUTDIR}/tmp" "--threads" "${THREADS}")
                    [ "${SHOW_PROGRESS}" = true ] && DUMP_ARGS+=("--progress")
                    fasterq-dump "${DUMP_ARGS[@]}"
                fi
            else
                echo -e "${CYAN}  🔄 [2/2: fasterq-dump] กำลังแตกไฟล์ SRA เป็น Nanopore FASTQ (${ONT_RUN})...${NC}"
                DUMP_ARGS=("${SRA_TARGET}" "--outdir" "${OUTDIR}" "--temp" "${OUTDIR}/tmp" "--threads" "${THREADS}")
                [ "${SHOW_PROGRESS}" = true ] && DUMP_ARGS+=("--progress")
                fasterq-dump "${DUMP_ARGS[@]}"
            fi

            ONT_RAW_FQ=$(locate_nanopore_fastq "${ONT_RUN}" "${OUTDIR}")

            if [ -n "${MAX_SPOTS}" ] && ! command -v fastq-dump &>/dev/null; then
                if [ -n "${ONT_RAW_FQ}" ] && [ -f "${ONT_RAW_FQ}" ]; then
                    head -n $((MAX_SPOTS * 4)) "${ONT_RAW_FQ}" > "${ONT_RAW_FQ}.sub" && mv -f "${ONT_RAW_FQ}.sub" "${ONT_RAW_FQ}"
                fi
            fi
        fi

        if [ -z "${ONT_RAW_FQ}" ] || [ ! -f "${ONT_RAW_FQ}" ]; then
            echo -e "${RED}[ERROR] ไม่พบไฟล์ผลลัพธ์ Nanopore จาก fasterq-dump (${ONT_RUN})${NC}"
            echo -e "${YELLOW}  กำลังแสดงไฟล์ในโฟลเดอร์ ${OUTDIR}:${NC}"
            ls -la "${OUTDIR}"
            exit 1
        fi

        echo -e "${YELLOW}  📦 กำลังบีบอัดไฟล์ Nanopore FASTQ ด้วย gzip/pigz...${NC}"
        echo -e "     • ONT: $(basename "${ONT_RAW_FQ}") -> $(basename "${FINAL_ONT}")"

        if command -v pigz &> /dev/null; then
            pigz -p "${THREADS}" -f "${ONT_RAW_FQ}"
        else
            gzip -f "${ONT_RAW_FQ}"
        fi
        mv -f "${ONT_RAW_FQ}.gz" "${FINAL_ONT}"
        echo -e "${GREEN}  ✓ Nanopore FASTQ พร้อมใช้งาน:${NC} ${FINAL_ONT}"

        if [ "${USE_PREFETCH}" = true ] && [ "${KEEP_SRA}" = false ]; then
            if [ -f "${FINAL_ONT}" ] && [ -s "${FINAL_ONT}" ]; then
                echo -e "${CYAN}  🧹 ลบไฟล์ SRA ดิบ (${ONT_RUN}) เพื่อประหยัดเนื้อที่ดิสก์${NC}"
                [ -n "${SRA_TARGET:-}" ] && [ -f "${SRA_TARGET}" ] && rm -f "${SRA_TARGET}"
                [ -d "${SRA_DIR}/${ONT_RUN}" ] && rm -rf "${SRA_DIR}/${ONT_RUN}"
            fi
        fi
    fi

    # แปลง path ให้เป็น absolute path พร้อมใช้ forward slash สำหรับ Nextflow
    ABS_R1="$(cd "$(dirname "${FINAL_R1}")" && pwd)/$(basename "${FINAL_R1}")"
    ABS_R2="$(cd "$(dirname "${FINAL_R2}")" && pwd)/$(basename "${FINAL_R2}")"
    ABS_ONT="$(cd "$(dirname "${FINAL_ONT}")" && pwd)/$(basename "${FINAL_ONT}")"

    EXISTING_SHEET_ROWS["${sid}"]="${sid},${ABS_R1},${ABS_R2},${ABS_ONT}"
    echo ""
done

# บันทึกข้อมูลกลับลง samplesheet_hybrid.csv โดยคงข้อมูลเดิมและจัดเรียงลำดับมาตรฐาน
echo "sample,fastq_1,fastq_2,long_reads" > "${SAMPLESHEET_OUT}"

ORDERED_SUBS=("CD35" "CD22" "CD3" "TD35" "TD22" "TD3")
for sid in "${ORDERED_SUBS[@]}"; do
    if [ -n "${EXISTING_SHEET_ROWS[${sid}]:-}" ]; then
        echo "${EXISTING_SHEET_ROWS[${sid}]}" >> "${SAMPLESHEET_OUT}"
        unset "EXISTING_SHEET_ROWS[${sid}]"
    elif [ -f "${OUTDIR}/${sid}_illumina_1.fastq.gz" ] && [ -f "${OUTDIR}/${sid}_nanopore.fastq.gz" ]; then
        ABS_R1="$(cd "${OUTDIR}" && pwd)/${sid}_illumina_1.fastq.gz"
        ABS_R2="$(cd "${OUTDIR}" && pwd)/${sid}_illumina_2.fastq.gz"
        ABS_ONT="$(cd "${OUTDIR}" && pwd)/${sid}_nanopore.fastq.gz"
        echo "${sid},${ABS_R1},${ABS_R2},${ABS_ONT}" >> "${SAMPLESHEET_OUT}"
    fi
done

# บันทึก Subject อื่นๆ เพิ่มเติม (ถ้ามี)
for sid in "${!EXISTING_SHEET_ROWS[@]}"; do
    echo "${EXISTING_SHEET_ROWS[${sid}]}" >> "${SAMPLESHEET_OUT}"
done

# ลบโฟลเดอร์ชั่วคราว
rm -rf "${OUTDIR}/tmp"
[ "${USE_PREFETCH}" = true ] && [ "${KEEP_SRA}" = false ] && rmdir "${SRA_DIR}" 2>/dev/null || true

echo -e "${GREEN}==============================================================================${NC}"
echo -e "${BOLD}${GREEN} 🎉 การดึงข้อมูลทดสอบเสร็จสมบูรณ์! พร้อมสำหรับรัน Hybrid Pipeline 🎉 ${NC}"
echo -e "${GREEN}==============================================================================${NC}"
echo -e " 📋 ตรวจสอบ Samplesheet ได้ที่: ${BOLD}${SAMPLESHEET_OUT}${NC}"
cat "${SAMPLESHEET_OUT}"
echo -e "${CYAN}==============================================================================${NC}"
echo -e "\nคุณสามารถสั่งรัน Hybrid Pipeline ได้ทันทีด้วยคำสั่ง:"
echo -e "  ${CYAN}chmod +x run_hybrid.sh${NC}"
echo -e "  ${CYAN}./run_hybrid.sh docker${NC}  หรือ  ${CYAN}./run_hybrid.sh conda${NC}\n"
