#!/usr/bin/env bash
# ==============================================================================
# bin/pull_hybrid_test_data.sh — Runner wrapper for pull_hybrid_test_data.py
# ==============================================================================
# คำอธิบายภาษาไทย (Thai Description):
# สคริปต์นี้ใช้สำหรับดึงข้อมูลคู่ Short (Illumina) + Long (Nanopore) จาก short_long_metadata.csv
# สำหรับ 2 ตัวอย่างเพื่อทดสอบ run_hybrid.sh
#
# การใช้งาน (Usage):
#   chmod +x bin/pull_hybrid_test_data.sh
#   ./bin/pull_hybrid_test_data.sh [MODE: smoke|full|dry-run] [EXTRA_ARGS]
#
# โหมด:
#   1) smoke   : สตรีมดึงเฉพาะ Subset (50,000 short read pairs, 10,000 long reads)
#                รวดเร็ว ใช้เนื้อที่น้อยมาก เหมาะสำหรับทดสอบ pipeline end-to-end (~5 นาที)
#   2) full    : ดาวน์โหลดไฟล์ตัวอย่างเต็ม (~6.2 GB) สำหรับ Benchmark คุณภาพสูง
#   3) dry-run : จำลองตรวจสอบ URL และตัวอย่าง โดยยังไม่เริ่มดาวน์โหลดไฟล์
# ==============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
PYTHON_EXEC=""
if command -v python3 &> /dev/null && python3 --version &> /dev/null; then
    PYTHON_EXEC="python3"
elif command -v python &> /dev/null && python --version &> /dev/null; then
    PYTHON_EXEC="python"
elif command -v py &> /dev/null && py -3 --version &> /dev/null; then
    PYTHON_EXEC="py -3"
else
    echo -e "\033[0;31m[ERROR] ไม่พบ Python 3 ที่ใช้งานได้ในระบบ กรุณาเปิดใช้งาน Conda/Pixi หรือติดตั้ง Python 3 ก่อน\033[0m"
    exit 1
fi

# รวม Pixi environment หากมี
if [ -d "${PROJECT_DIR}/.pixi/envs/default/bin" ]; then
    export PATH="${PROJECT_DIR}/.pixi/envs/default/bin:${PATH}"
fi

MODE="${1:-smoke}"

case "${MODE}" in
    smoke)
        echo -e "\033[1;33m⚡ รันในโหมด Smoke Test (ดาวน์โหลดเฉพาะ Subset เพื่อทดสอบความถูกต้องอย่างรวดเร็ว)\033[0m"
        "${PYTHON_EXEC}" "${PROJECT_DIR}/bin/pull_hybrid_test_data.py" \
            --mode smoke \
            --short-reads 50000 \
            --long-reads 10000 \
            "${@:2}"
        ;;
    full)
        echo -e "\033[1;34m📥 รันในโหมด Full Dataset (ดาวน์โหลดข้อมูลเต็มทั้ง 2 คน)\033[0m"
        "${PYTHON_EXEC}" "${PROJECT_DIR}/bin/pull_hybrid_test_data.py" \
            --mode full \
            "${@:2}"
        ;;
    dry-run)
        echo -e "\033[1;36m🔍 รันในโหมด Dry-Run (ตรวจสอบการจับคู่และ URL เท่านั้น)\033[0m"
        "${PYTHON_EXEC}" "${PROJECT_DIR}/bin/pull_hybrid_test_data.py" \
            --dry-run \
            "${@:2}"
        ;;
    -h|--help|help)
        "${PYTHON_EXEC}" "${PROJECT_DIR}/bin/pull_hybrid_test_data.py" --help
        exit 0
        ;;
    *)
        # ส่ง arguments ต่อไปยัง python script โดยตรง
        "${PYTHON_EXEC}" "${PROJECT_DIR}/bin/pull_hybrid_test_data.py" "$@"
        ;;
esac
