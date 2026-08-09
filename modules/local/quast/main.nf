process QUAST {
    tag "$meta.id"
    label 'process_medium'
    container 'quay.io/biocontainers/quast:5.2.0--py39pl5321h2edd5ef_7'

    input:
    tuple val(meta), path(contigs)

    output:
    tuple val(meta), path("quast_out/report.tsv"), emit: tsv
    tuple val(meta), path("quast_out/report.html"), emit: html

    script:
    """
    quast.py $contigs \\
        -o quast_out \\
        -t $task.cpus \\
        --meta
    """
}

process QUAST_BINS {
    tag "$meta.id"
    label 'process_medium'
    container 'quay.io/biocontainers/quast:5.2.0--py39pl5321h2edd5ef_7'

    input:
    tuple val(meta), path(bins)

    output:
    tuple val(meta), path("${meta.id}_quast_out"), emit: report
    tuple val(meta), path("${meta.id}_quast_out/transposed_report.tsv"), emit: tsv

    script:
    """
    quast.py ${bins}/* \\
        -o ${meta.id}_quast_out \\
        -t $task.cpus \\
        --min-contig 500
    """
}