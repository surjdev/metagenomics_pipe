process FILTLONG {
    tag "$meta.id"
    label 'process_medium'

    container 'quay.io/biocontainers/filtlong:0.2.1--hdfd78af_1'

    input:
    tuple val(meta), path(reads)

    output:
    tuple val(meta), path("*.filtlong.fastq.gz"), emit: reads

    script:
    def prefix = task.ext.prefix ?: "${meta.id}"
    """
    filtlong \\
        --min_length ${params.min_length_long} \\
        --min_mean_q ${params.min_quality_long} \\
        $reads \\
        | gzip -c > ${prefix}.filtlong.fastq.gz
    """
}
