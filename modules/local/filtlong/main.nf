process FILTLONG {
    tag "$meta.id"
    label 'process_medium'

    container 'quay.io/biocontainers/filtlong:0.2.1--hdcf5f25_4'

    input:
    tuple val(meta), path(reads)

    output:
    tuple val(meta), path("*.filtlong.fastq.gz"), emit: reads
    tuple val(meta), path("*.filtlong.log"),      emit: log

    script:
    def prefix = task.ext.prefix ?: "${meta.id}"
    """
    filtlong \\
        --min_length ${params.min_length_long} \\
        --min_mean_q ${params.min_quality_long} \\
        $reads \\
        2> ${prefix}.filtlong.log \\
        | gzip -c > ${prefix}.filtlong.fastq.gz
    """
}
