process QUAST {
    tag "$meta.id"
    label 'process_medium'

    container 'quay.io/biocontainers/quast:5.3.0--py313pl5321h5ca1c30_2'

    input:
    tuple val(meta), path(contigs)

    output:
    tuple val(meta), path("quast_out"),             emit: dir
    tuple val(meta), path("quast_out/report.tsv"),  emit: tsv
    tuple val(meta), path("quast_out/report.html"), emit: html

    script:
    def prefix = task.ext.prefix ?: "${meta.id}"
    """
    quast.py \\
        ${contigs} \\
        -o quast_out \\
        -t $task.cpus
    """
}
