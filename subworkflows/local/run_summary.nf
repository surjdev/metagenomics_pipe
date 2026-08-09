// ดึงโมดูล MultiQC เข้ามาใช้งาน
include { MULTIQC } from '../../modules/local/multiqc/main'

// ==========================================
// Process 1: รวบรวมข้อมูลฝั่ง Python (Pandas)
// ==========================================
process GENERATE_PYTHON_REPORTS {
    label 'process_low'
    container 'quay.io/biocontainers/pandas:1.5.3'
    publishDir "${params.outdir}/summary", mode: 'copy'

    input:
    path bin_qc_out
    path bin_annot_out

    output:
    path "aggregated_bin_summary.tsv", emit: bin_summary

    script:
    """
    # รันสคริปต์รวมข้อมูลถัง (Bin Summary Aggregation)
    bin_summary.py \\
        dastool_summary.tsv \\
        checkm2_summary.tsv \\
        gtdbtk_summary.tsv \\
        aggregated_bin_summary.tsv
    """
}

// ==========================================
// Process 2: รวบรวมข้อมูลฝั่ง R (Tidyverse)
// ==========================================
process GENERATE_R_REPORTS {
    label 'process_low'
    // เปลี่ยนไปใช้ Container ที่มีทั้ง R Base และแพ็กเกจกลุ่ม Tidyverse/Phyloseq ตามที่สคริปต์ต้องการ
    container 'quay.io/biocontainers/mulled-v2-b2d83e7ff769d023348ea6d45e43a9cc3737b8b4:a0005a91ee5fa7e9e54a377d6eeef93ef85970c6-0'
    publishDir "${params.outdir}/summary", mode: 'copy'

    input:
    path profiling_out

    output:
    path "merged_profiling_abundances.tsv", emit: profiling_summary

    script:
    """
    # รันสคริปต์ควบรวมตาราง Abundance
    merge_profile_tables.R \\
        . \\
        merged_profiling_abundances.tsv
    """
}

// ==========================================
// Process 3: ประกอบร่างสร้าง HTML Report (Python)
// ==========================================
process BUILD_HTML_REPORT {
    label 'process_low'
    container 'quay.io/biocontainers/pandas:1.5.3'
    publishDir "${params.outdir}/summary", mode: 'copy'

    input:
    path bin_summary
    path profiling_summary

    output:
    path "final_metagenomics_report.html", emit: html_report

    script:
    """
    # สร้างรายงาน HTML สุดท้าย
    build_final_report.py \\
        $bin_summary \\
        $profiling_summary \\
        final_metagenomics_report.html
    """
}

// ==========================================
// MAIN WORKFLOW: RUN_SUMMARY
// ==========================================
workflow RUN_SUMMARY {
    take:
    qc_logs        // Channel คลังเก็บ log ต่างๆ (FastQC, NanoPlot, QUAST)
    profiling_out  // Channel ผลลัพธ์จากการทำ Profile สายพันธุ์/ฟังก์ชัน
    bin_qc_out     // Channel ผลลัพธ์ของ DASTool/CheckM2/GTDB-Tk
    bin_annot_out  // Channel ผลลัพธ์ของ PROKKA/eggNOG

    main:
    // -----------------------------------------------------------------
    // Station 1: สั่งรัน MultiQC (ส่งค่าครบ 2 arguments แก้ไข Error ตัวเก่า)
    // -----------------------------------------------------------------
    ch_multiqc_config = channel.fromPath("${projectDir}/assets/multiqc_config.yaml", checkIfExists: true)
    
    MULTIQC(
        qc_logs.collect(),
        ch_multiqc_config
    )

    // -----------------------------------------------------------------
    // Stations 2, 3, & 4: รันระบบรายงานแยกตาม Container
    // -----------------------------------------------------------------
    
    // 1. จัดการฝั่ง Python Summary
    GENERATE_PYTHON_REPORTS(
        bin_qc_out.collect(),
        bin_annot_out.collect()
    )

    // 2. จัดการฝั่ง R Merge Table
    GENERATE_R_REPORTS(
        profiling_out.collect()
    )

    // 3. รวมร่างออก Report HTML ตัวจริง
    BUILD_HTML_REPORT(
        GENERATE_PYTHON_REPORTS.out.bin_summary,
        GENERATE_R_REPORTS.out.profiling_summary
    )

    emit:
    multiqc_html = MULTIQC.out.report
    final_report = BUILD_HTML_REPORT.out.html_report
}