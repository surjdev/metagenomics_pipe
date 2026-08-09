process KRONA {
    tag "$meta.id"
    label 'process_low'
    container 'quay.io/biocontainers/krona:2.8.1--pl5321hdfd78af_1'
    publishDir "${params.outdir}/assembly_free/krona", mode: 'copy'

    input:
    tuple val(meta), path(kraken_report)

    output:
    tuple val(meta), path("*.krona.html"), emit: html

    script:
    """
    ktImportTaxonomy -q 1 -t 5 -m 3 -o ${meta.id}.krona.html $kraken_report
    """
}