process GENERATE_REPORTS {
    label 'process_low'
    container 'quay.io/biocontainers/pandas:1.5.3' // **โน้ตเสริมด้านล่างเกี่ยวกับตัวนี้**
    publishDir "${params.outdir}/summary", mode: 'copy'

    input:
    path profiling_out
    path bin_qc_out
    path bin_annot_out

    output:
    path "aggregated_bin_summary.tsv",    emit: bin_summary
    path "merged_profiling_abundances.tsv", emit: profiling_summary
    path "final_metagenomics_report.html",  emit: html_report

    script:
    """
    # 1. เรียกใช้ได้โดยตรงเพราะ Nextflow Map โฟลเดอร์ bin/ เข้า $/PATH ให้แล้ว
    bin_summary.py \\
        dastool_summary.tsv \\
        checkm2_summary.tsv \\
        gtdbtk_summary.tsv \\
        aggregated_bin_summary.tsv

    merge_profile_tables.R \\
        . \\
        merged_profiling_abundances.tsv

    build_final_report.py \\
        aggregated_bin_summary.tsv \\
        merged_profiling_abundances.tsv \\
        final_metagenomics_report.html
    """
}