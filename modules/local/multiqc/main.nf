process MULTIQC {
    label 'process_low'
    container 'quay.io/biocontainers/multiqc:1.21--pyhdfd78af_0'
    publishDir "${params.outdir}/multiqc", mode: 'copy'

    input:
    path('*')   // Collects all upstream diagnostic logs globally

    output:
    path "multiqc_report.html", emit: report

    script:
    """
    multiqc . -n multiqc_report.html -c ${projectDir}/assets/multiqc_config.yaml
    """
}