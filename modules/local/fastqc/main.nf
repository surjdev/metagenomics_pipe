process FASTQC {
    tag "$meta.id"
    label 'process_medium'

    container 'quay.io/biocontainers/fastqc:0.12.1--hdfd78af_0'

    input:
    tuple val(meta), path(reads)

    output:
    tuple val(meta), path("*.html"), emit: html
    tuple val(meta), path("*.zip"),  emit: zip

    script:
    """
    fastqc \\
        --threads $task.cpus \\
        --outdir . \\
        $reads
    """
}
