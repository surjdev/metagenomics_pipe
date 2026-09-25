#!/usr/bin/env bash
# ==============================================================================
# generate_dags.sh — Generate Workflow DAGs for all Pipeline Stages
# ==============================================================================
# คำสั่งสำหรับสร้างแผนภาพ Workflow (DAG) ทั้งแบบภาพรวมและแยกแต่ละ Phase
# รองรับทั้งไฟล์ .html (Interactive Mermaid/Cytoscape) และ .svg (Vector Image)
# ==============================================================================

set -eo pipefail

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
OUTDIR="${PROJECT_DIR}/docs/workflow_dags"
mkdir -p "${OUTDIR}"

echo -e "\033[0;36m==============================================================================\033[0m"
echo -e "\033[1;34m   📊 Generating Nextflow Workflow DAGs (Dry-run / Preview) 📊   \033[0m"
echo -e "\033[0;36m==============================================================================\033[0m"
echo -e " 📁 Output Directory: ${OUTDIR}\n"

# 1. Pipeline Hybrid (Full Overview)
echo -e "\033[1;33m[1/7] Generating Hybrid Pipeline DAG (Full Overview)...\033[0m"
nextflow run "${PROJECT_DIR}/main.nf" -preview --mode hybrid --input "${PROJECT_DIR}/samplesheet_hybrid.csv" -with-dag "${OUTDIR}/00_pipeline_hybrid.html" > /dev/null 2>&1
nextflow run "${PROJECT_DIR}/main.nf" -preview --mode hybrid --input "${PROJECT_DIR}/samplesheet_hybrid.csv" -with-dag "${OUTDIR}/00_pipeline_hybrid.svg" > /dev/null 2>&1

# 2. Pipeline Assembly-Free (Taxonomic Profiling Overview)
echo -e "\033[1;33m[2/7] Generating Assembly-Free Pipeline DAG...\033[0m"
nextflow run "${PROJECT_DIR}/main.nf" -preview --mode assembly_free --input "${PROJECT_DIR}/samplesheet_meta_npi_smoke.csv" -with-dag "${OUTDIR}/00_pipeline_assembly_free.html" > /dev/null 2>&1
nextflow run "${PROJECT_DIR}/main.nf" -preview --mode assembly_free --input "${PROJECT_DIR}/samplesheet_meta_npi_smoke.csv" -with-dag "${OUTDIR}/00_pipeline_assembly_free.svg" > /dev/null 2>&1

# 3. Phase 1: Preprocessing & QC
echo -e "\033[1;33m[3/7] Generating Phase 1 (Preprocessing & QC) DAG...\033[0m"
nextflow run "${PROJECT_DIR}/test/test_phase1.nf" -preview --input "${PROJECT_DIR}/samplesheet_hybrid.csv" -with-dag "${OUTDIR}/01_phase1_preprocessing.html" > /dev/null 2>&1
nextflow run "${PROJECT_DIR}/test/test_phase1.nf" -preview --input "${PROJECT_DIR}/samplesheet_hybrid.csv" -with-dag "${OUTDIR}/01_phase1_preprocessing.svg" > /dev/null 2>&1

# 4. Phase 2: Assembly & Polishing
echo -e "\033[1;33m[4/7] Generating Phase 2 (Assembly & Polishing) DAG...\033[0m"
nextflow run "${PROJECT_DIR}/test/test_phase2.nf" -preview --input "${PROJECT_DIR}/samplesheet_hybrid.csv" -with-dag "${OUTDIR}/02_phase2_assembly_polishing.html" > /dev/null 2>&1
nextflow run "${PROJECT_DIR}/test/test_phase2.nf" -preview --input "${PROJECT_DIR}/samplesheet_hybrid.csv" -with-dag "${OUTDIR}/02_phase2_assembly_polishing.svg" > /dev/null 2>&1

# 5. Phase 3: Mapping & Binning & MAG QC
echo -e "\033[1;33m[5/7] Generating Phase 3 (Mapping & Binning) DAG...\033[0m"
nextflow run "${PROJECT_DIR}/test/test_phase3.nf" -preview --input "${PROJECT_DIR}/samplesheet_hybrid.csv" -with-dag "${OUTDIR}/03_phase3_mapping_binning.html" > /dev/null 2>&1
nextflow run "${PROJECT_DIR}/test/test_phase3.nf" -preview --input "${PROJECT_DIR}/samplesheet_hybrid.csv" -with-dag "${OUTDIR}/03_phase3_mapping_binning.svg" > /dev/null 2>&1

# 6. Phase 4: Assembly-Free Taxonomic Profiling
echo -e "\033[1;33m[6/7] Generating Phase 4 (Assembly-Free Profiling) DAG...\033[0m"
nextflow run "${PROJECT_DIR}/test/test_phase4.nf" -preview --input "${PROJECT_DIR}/samplesheet_hybrid.csv" -with-dag "${OUTDIR}/04_phase4_assembly_free.html" > /dev/null 2>&1
nextflow run "${PROJECT_DIR}/test/test_phase4.nf" -preview --input "${PROJECT_DIR}/samplesheet_hybrid.csv" -with-dag "${OUTDIR}/04_phase4_assembly_free.svg" > /dev/null 2>&1

# 7. Phase 5: Annotation & Reporting
echo -e "\033[1;33m[7/7] Generating Phase 5 (Annotation & Reporting) DAG...\033[0m"
nextflow run "${PROJECT_DIR}/test/test_phase5.nf" -preview -with-dag "${OUTDIR}/05_phase5_annotation_reporting.html" > /dev/null 2>&1
nextflow run "${PROJECT_DIR}/test/test_phase5.nf" -preview -with-dag "${OUTDIR}/05_phase5_annotation_reporting.svg" > /dev/null 2>&1

echo -e "\n\033[0;32m==============================================================================\033[0m"
echo -e "\033[1;32m ✅ สร้างภาพ DAG ทั้งหมดเสร็จสมบูรณ์เรียบร้อยแล้ว! \033[0m"
echo -e "\033[0;32m==============================================================================\033[0m"
ls -lh "${OUTDIR}"
