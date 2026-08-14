process NANOPLOT {
    tag "$meta.id"
    label 'process_medium'

    container 'quay.io/biocontainers/nanoplot:1.42.0--pyhdfd78af_0'

    input:
    tuple val(meta), path(reads)

    output:
    tuple val(meta), path("*.html"), emit: html
    tuple val(meta), path("*.txt"),  emit: txt
    tuple val(meta), path("*.png"),  emit: png

    script:
    def prefix = task.ext.prefix ?: "${meta.id}"
    """
    NanoPlot \\
        --fastq $reads \\
        --outdir . \\
        --prefix ${prefix}. \\
        --threads $task.cpus
    """
}
