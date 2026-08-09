process MULTIQC {
    label 'process_low'
    container 'quay.io/biocontainers/multiqc:1.21--pyhdfd78af_0'
    publishDir "${params.outdir}/multiqc", mode: 'copy'

    input:
    path('*')           // รวบรวมไฟล์ Log จากท่อส่งต้นน้ำทั้งหมด
    path multiqc_config // เพิ่มอินพุตสำหรับรับไฟล์คอนฟิกโดยเฉพาะ

    output:
    path "multiqc_report.html", emit: report

    script:
    """
    # เรียกใช้ไฟล์คอนฟิกผ่านชื่อตัวแปรอินพุตโดยตรง (ไม่ต้องมี projectDir)
    multiqc . -n multiqc_report.html -c $multiqc_config
    """
}