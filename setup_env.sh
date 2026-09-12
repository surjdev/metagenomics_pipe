#!/usr/bin/env bash
# ==============================================================================
# setup_env.sh — Setup Conda / Pixi Environment with Nextflow, SRA-Tools & Pixi
# ==============================================================================
# คำอธิบายภาษาไทย (Thai Description):
# สคริปต์นี้เตรียมสภาพแวดล้อมที่จำเป็นสำหรับ Metagenomics Pipeline:
#   1. sra-tools (มีคำสั่ง fasterq-dump, prefetch สำหรับดึงข้อมูล SRA)
#   2. nextflow (สำหรับรัน Pipeline DSL2)
#   3. pixi (Package manager สมัยใหม่สำหรับไบโออินฟอร์มาติกส์)
#   4. pigz (Parallel GZIP สำหรับบีบอัดไฟล์ FASTQ อย่างรวดเร็ว)
#   5. python 3.11 พร้อม pyyaml สำหรับจัดการ samplesheet และ parameters
#
# การใช้งาน (Usage):
#   chmod +x setup_env.sh
#   ./setup_env.sh [conda|pixi|mamba]
# ==============================================================================

set -euo pipefail

MODE="${1:-conda}"
ENV_NAME="metagenomics-pipe"

# สีข้อความ
GREEN='\033[0;32m'
CYAN='\033[0;36m'
YELLOW='\033[1;33m'
BOLD='\033[1m'
NC='\033[0m'

echo -e "${CYAN}==============================================================================${NC}"
echo -e "${BOLD}   🧬 Setting up Metagenomics Environment (Nextflow + SRA-Tools + Pixi) 🧬   ${NC}"
echo -e "${CYAN}==============================================================================${NC}\n"

case "${MODE}" in
    conda)
        echo -e "${YELLOW}📦 กำลังสร้าง/อัปเดต Conda Environment '${ENV_NAME}'...${NC}"
        if command -v conda &> /dev/null; then
            conda create -n "${ENV_NAME}" -c conda-forge -c bioconda \
                nextflow sra-tools pixi pigz python=3.11 pyyaml -y
            echo -e "\n${GREEN}✅ ติดตั้ง Conda Environment เรียบร้อยแล้ว!${NC}"
            echo -e "เปิดใช้งานด้วยคำสั่ง:"
            echo -e "   ${BOLD}conda activate ${ENV_NAME}${NC}\n"
        else
            echo -e "\033[0;31m[ERROR] ไม่พบคำสั่ง 'conda' ในระบบ กรุณาติดตั้ง Miniconda/Anaconda ก่อน\033[0m"
            exit 1
        fi
        ;;
    mamba)
        echo -e "${YELLOW}⚡ กำลังสร้าง Mamba Environment '${ENV_NAME}'...${NC}"
        if command -v mamba &> /dev/null; then
            mamba create -n "${ENV_NAME}" -c conda-forge -c bioconda \
                nextflow sra-tools pixi pigz python=3.11 pyyaml -y
            echo -e "\n${GREEN}✅ ติดตั้ง Mamba Environment เรียบร้อยแล้ว!${NC}"
            echo -e "เปิดใช้งานด้วยคำสั่ง:"
            echo -e "   ${BOLD}conda activate ${ENV_NAME}${NC}\n"
        else
            echo -e "\033[0;31m[ERROR] ไม่พบคำสั่ง 'mamba' ในระบบ\033[0m"
            exit 1
        fi
        ;;
    pixi)
        echo -e "${YELLOW}🚀 กำลังติดตั้งแพ็กเกจด้วย Pixi (ตาม pixi.toml)...${NC}"
        if command -v pixi &> /dev/null; then
            pixi install
            echo -e "\n${GREEN}✅ ติดตั้ง Pixi Dependencies เรียบร้อยแล้ว!${NC}"
            echo -e "รันคำสั่งผ่าน Pixi เช่น:"
            echo -e "   ${BOLD}pixi run nextflow -version${NC}"
            echo -e "   ${BOLD}pixi run fasterq-dump --version${NC}\n"
        else
            echo -e "\033[0;31m[ERROR] ไม่พบคำสั่ง 'pixi' ในระบบ\033[0m"
            exit 1
        fi
        ;;
    *)
        echo "ตัวเลือกที่รองรับ: conda | mamba | pixi"
        exit 1
        ;;
esac
