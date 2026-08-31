#!/usr/bin/env bash
# ==============================================================================
# run_meta_npi.sh — Automated Runner for Meta_NPI Metagenomics Dataset
# ==============================================================================
# คำอธิบายภาษาไทย (Thai Description):
# สคริปต์นี้ใช้สำหรับรัน Pipeline Nextflow DSL2 กับชุดข้อมูล Oxford Nanopore (ONT) Meta_NPI
# รองรับทั้งโหมดทดสอบเร็ว (Smoke Test), โหมดประมวลผลเชิงลึก (Benchmark), และแบบเต็มทุก Barcodes (Full)
#
# วิธีการใช้งาน (Usage):
#   chmod +x run_meta_npi.sh
#   ./run_meta_npi.sh [MODE] [PROFILE] [EXTRA_ARGS]
#
# โหมดที่รองรับ (Supported Modes):
#   1) smoke      : รัน Smoke test ด้วย Barcode14 & Barcode16 (~2-5 นาที)
#   2) benchmark  : รัน Benchmark ด้วย Barcode01 & Barcode21 (High-depth samples)
#   3) full       : รันชุดข้อมูลเต็มทั้ง 17 Barcodes
#   4) dry-run    : จำลองการสร้าง DAG workflow โดยไม่รัน process จริง (-preview)
#   5) clean      : ล้างโฟลเดอร์ work/ และ .nextflow/ แคชเก่า
#
# โปรไฟล์รันเนอร์ (Profiles):
#   - docker      : รันผ่าน Docker containers (ค่าเริ่มต้น / แนะนำ)
#   - singularity : รันผ่าน Singularity containers (สำหรับ HPC cluster)
#   - conda       : รันผ่านสภาพแวดล้อม Conda / Pixi
# ==============================================================================

set -eo pipefail

# สีสำหรับการแสดงผลข้อความใน Terminal
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m' # No Color

# ตัวแปรพื้นฐาน
PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MODE="${1:-smoke}"
PROFILE="${2:-docker}"
RESUME_FLAG="-resume"

# รวมสภาพแวดล้อม Pixi เข้ากับ PATH หากมีอยู่
if [ -d "${PROJECT_DIR}/.pixi/envs/default/bin" ]; then
    export PATH="${PROJECT_DIR}/.pixi/envs/default/bin:${PATH}"
fi

print_banner() {
    echo -e "${CYAN}==============================================================================${NC}"
    echo -e "${BOLD}${BLUE}   🧬 Hybrid Metagenomics DSL2 Pipeline — Meta_NPI ONT Runner 🧬   ${NC}"
    echo -e "${CYAN}==============================================================================${NC}"
    echo -e " 📂 Project Directory : ${PROJECT_DIR}"
    echo -e " ⚙️ Execution Mode     : ${YELLOW}${MODE}${NC}"
    echo -e " 🐳 Container Engine  : ${YELLOW}${PROFILE}${NC}"
    echo -e " ⏱️ Timestamp          : $(date '+%Y-%m-%d %H:%M:%S')"
    echo -e "${CYAN}==============================================================================${NC}\n"
}

show_help() {
    echo -e "${BOLD}การใช้งาน:${NC}"
    echo -e "  ./run_meta_npi.sh [โหมด: smoke|benchmark|full|dry-run|clean] [โปรไฟล์: docker|singularity|conda] [อาร์กิวเมนต์เพิ่มเติม]\n"
    echo -e "${BOLD}ตัวอย่างคำสั่ง:${NC}"
    echo -e "  ${GREEN}./run_meta_npi.sh smoke${NC}               # รัน Smoke test ด้วย Docker (รวดเร็ว)"
    echo -e "  ${GREEN}./run_meta_npi.sh benchmark${NC}           # รัน Barcode01 & Barcode21 ทดสอบ Assembly & Binning เต็มรูปแบบ"
    echo -e "  ${GREEN}./run_meta_npi.sh full docker${NC}         # รันทั้ง 17 Barcodes ด้วย Docker"
    echo -e "  ${GREEN}./run_meta_npi.sh dry-run${NC}             # ตรวจสอบการต่อสาย Workflow Channel (DAG preview)"
    echo -e "  ${GREEN}./run_meta_npi.sh clean${NC}               # ล้างไฟล์ชั่วคราว work/ และ .nextflow/"
    echo ""
    echo -e "${BOLD}ขั้นตอนการทำงานของ Workflow ใน Pipeline (11 Stages):${NC}"
    echo -e "  1. ${BOLD}Preprocessing${NC}  : NanoPlot (สถิติคุณภาพ), Filtlong (กรอง Q10+, >300bp)"
    echo -e "  2. ${BOLD}Host Removal${NC}   : Minimap2 (กำจัด Host DNA โดยเทียบกับ host_ref.fasta)"
    echo -e "  3. ${BOLD}Assembly${NC}       : Flye (--nano-hq --meta สำหรับ ONT Dorado SUP reads)"
    echo -e "  4. ${BOLD}Polishing${NC}      : Racon / Medaka (ข้ามได้สำหรับ Dorado Q17+ SUP)"
    echo -e "  5. ${BOLD}Assembly QC${NC}    : QUAST (ประเมิน N50, ความยาว Contig รวม, GC%)"
    echo -e "  6. ${BOLD}Mapping${NC}        : Minimap2 (Align long reads กลับหา Contigs คำนวณ Depth/Coverage)"
    echo -e "  7. ${BOLD}MAG Binning${NC}    : MetaBAT2 & SemiBin2 (รวมกลุ่ม Contigs แยกสปีชีส์ MAGs)"
    echo -e "  8. ${BOLD}MAG QC${NC}         : CheckM2, GUNC, GTDB-Tk (ประเมิน Completeness & Taxonomy)"
    echo -e "  9. ${BOLD}Read Profiling${NC} : Kraken2 & Krona (ระบุสปีชีส์จุลชีพจาก Raw reads + Interactive Pie Chart)"
    echo -e " 10. ${BOLD}Annotation${NC}     : Prokka (ทำนายตำแหน่งยีนและโปรตีน CDS, tRNA, rRNA)"
    echo -e " 11. ${BOLD}Reporting${NC}      : MultiQC & Custom HTML/MD Report (สรุปผลลัพธ์ภาพรวม)"
    echo ""
}

# ตรวจสอบว่ามี Nextflow ติดตั้งอยู่หรือไม่
check_prerequisites() {
    if ! command -v nextflow &> /dev/null; then
        echo -e "${RED}[ERROR] ไม่พบคำสั่ง 'nextflow' ในระบบ! กรุณาติดตั้ง Nextflow หรือเปิดใช้งาน Conda/Pixi environment${NC}"
        exit 1
    fi
}

# ฟังก์ชันทำความสะอาดไฟล์แคช
clean_workspace() {
    echo -e "${YELLOW}🧹 กำลังล้างไฟล์ชั่วคราว (work directory และ .nextflow cache)...${NC}"
    read -p "คุณแน่ใจหรือไม่ว่าต้องการลบ work/ และ .nextflow/ ? (y/N): " confirm
    if [[ "$confirm" =~ ^[Yy]$ ]]; then
        rm -rf "${PROJECT_DIR}/work" "${PROJECT_DIR}/.nextflow" "${PROJECT_DIR}/.nextflow.log"*
        echo -e "${GREEN}✅ ล้างไฟล์ชั่วคราวเรียบร้อยแล้ว!${NC}"
    else
        echo -e "${BLUE}ยกเลิกการล้างไฟล์${NC}"
    fi
    exit 0
}

# ประมวลผลคำสั่งตามโหมดที่เลือก
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
        echo -e "${YELLOW}🔍 [Dry-Run] กำลังตรวจสอบความถูกต้องของ DAG และ Configuration...${NC}"
        nextflow run "${PROJECT_DIR}/main.nf" \
            -profile "${PROFILE},test" \
            -c "${PROJECT_DIR}/conf/meta_npi.config" \
            --input "${PROJECT_DIR}/samplesheet_meta_npi_smoke.csv" \
            -preview
        echo -e "${GREEN}✅ ตรวจสอบโครงสร้าง Workflow เรียบร้อย (ไม่มีข้อผิดพลาดด้าน Channel wiring)${NC}"
        exit 0
        ;;
    smoke)
        SAMPLESHEET="${PROJECT_DIR}/samplesheet_meta_npi_smoke.csv"
        OUTDIR="${PROJECT_DIR}/results_meta_npi_smoke"
        RUN_PROFILE="${PROFILE},test"
        CONFIG_FILE="${PROJECT_DIR}/conf/meta_npi.config"
        DESCRIPTION="Smoke Test (Barcode14 & Barcode16 — รวดเร็ว < 5 นาที)"
        ;;
    benchmark)
        SAMPLESHEET="${PROJECT_DIR}/samplesheet_meta_npi_benchmark.csv"
        OUTDIR="${PROJECT_DIR}/results_meta_npi_benchmark"
        RUN_PROFILE="${PROFILE}"
        CONFIG_FILE="${PROJECT_DIR}/conf/meta_npi.config"
        DESCRIPTION="Benchmark Test (Barcode01 & Barcode21 — High-Depth Metagenome Assembly)"
        ;;
    full)
        SAMPLESHEET="${PROJECT_DIR}/samplesheet_meta_npi_full.csv"
        OUTDIR="${PROJECT_DIR}/results_meta_npi_full"
        RUN_PROFILE="${PROFILE}"
        CONFIG_FILE="${PROJECT_DIR}/conf/meta_npi.config"
        DESCRIPTION="Full Analysis (All 17 Barcodes in Meta_NPI)"
        ;;
    *)
        echo -e "${RED}[ERROR] ไม่รู้จักโหมด: '${MODE}'${NC}"
        echo -e "ตัวเลือกที่สามารถใช้ได้: smoke | benchmark | full | dry-run | clean | help"
        exit 1
        ;;
esac

# ตรวจสอบความพร้อมของ Samplesheet
if [ ! -f "${SAMPLESHEET}" ]; then
    echo -e "${YELLOW}⚠️  ไม่พบไฟล์ Samplesheet: ${SAMPLESHEET}${NC}"
    echo -e "${BLUE}ℹ️  กำลังสร้างไฟล์ Samplesheet อัตโนมัติด้วย bin/generate_samplesheet_meta_npi.py ...${NC}"
    python3 "${PROJECT_DIR}/bin/generate_samplesheet_meta_npi.py"
fi

print_banner
check_prerequisites

echo -e "${BOLD}📋 รายละเอียดการรัน:${NC}"
echo -e " • โหมด           : ${GREEN}${DESCRIPTION}${NC}"
echo -e " • Samplesheet    : ${SAMPLESHEET}"
echo -e " • Config File    : ${CONFIG_FILE}"
echo -e " • Output Dir     : ${OUTDIR}"
echo -e " • Nextflow Exec  : $(which nextflow)"
echo -e " • Trace Reports  : ${OUTDIR}/pipeline_info/"
echo ""

# สร้างโฟลเดอร์สำหรับรายงาน Pipeline execution info
mkdir -p "${OUTDIR}/pipeline_info"

# กำหนดชื่อไฟล์รายงานผลลัพธ์ Nextflow
TIMESTAMP=$(date '+%Y%m%d_%H%M%S')
REPORT_HTML="${OUTDIR}/pipeline_info/execution_report_${TIMESTAMP}.html"
TIMELINE_HTML="${OUTDIR}/pipeline_info/execution_timeline_${TIMESTAMP}.html"
TRACE_TXT="${OUTDIR}/pipeline_info/execution_trace_${TIMESTAMP}.txt"
DAG_SVG="${OUTDIR}/pipeline_info/pipeline_dag_${TIMESTAMP}.html"

echo -e "${CYAN}🚀 เริ่มต้นการประมวลผล Nextflow Pipeline...${NC}\n"

# สั่งรัน Nextflow พร้อมส่งพารามิเตอร์ครบถ้วน
nextflow run "${PROJECT_DIR}/main.nf" \
    -profile "${RUN_PROFILE}" \
    -c "${CONFIG_FILE}" \
    --input "${SAMPLESHEET}" \
    --outdir "${OUTDIR}" \
    ${RESUME_FLAG} \
    -with-report "${REPORT_HTML}" \
    -with-timeline "${TIMELINE_HTML}" \
    -with-trace "${TRACE_TXT}" \
    -with-dag "${DAG_SVG}" \
    "${@:3}"

echo -e "\n${GREEN}==============================================================================${NC}"
echo -e "${BOLD}${GREEN} 🎉 การประมวลผล Pipeline เสร็จสมบูรณ์! (Completed Successfully) 🎉 ${NC}"
echo -e "${GREEN}==============================================================================${NC}"
echo -e " 📁 ตรวจสอบผลลัพธ์ได้ที่: ${BOLD}${OUTDIR}${NC}"
echo -e "   ├─ 📊 สรุปภาพรวม MultiQC    : ${OUTDIR}/reporting/multiqc/multiqc_report.html"
echo -e "   ├─ 📄 รายงานผล Pipeline     : ${OUTDIR}/reporting/pipeline_report.html"
echo -e "   ├─ 🦠 การจำแนกสปีชีส์ Krona : ${OUTDIR}/assembly_free/krona/"
echo -e "   ├─ 🧩 คุณภาพ Contigs QUAST   : ${OUTDIR}/assembly_qc/quast/"
echo -e "   ├─ 📦 MAG Bins (MetaBAT2)   : ${OUTDIR}/binning/metabat2/"
echo -e "   └─ 📈 รายงานเวลาและทรัพยากร : ${REPORT_HTML}"
echo -e "${GREEN}==============================================================================${NC}\n"
