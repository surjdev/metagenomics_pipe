process FILTLONG {
    tag "$meta.id"
    label 'process_medium'
    container 'quay.io/biocontainers/filtlong:0.2.1--he4a0461_0'

    input:
    tuple val(meta), path(long_reads)

    output:
    tuple val(meta), path("*_filtered.fastq.gz"), emit: reads
    tuple val(meta), path("*.log"),               emit: log
    path "versions.yml",                          emit: versions

    script:
    """
    filtlong \\
        --min_length ${params.min_loop_length ?: 1000} \\
        --keep_percent ${params.keep_percent ?: 90} \\
        $long_reads 2> ${meta.id}_filtlong.log | gzip > ${meta.id}_filtered.fastq.gz

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        filtlong: \$(filtlong --version | sed 's/Filtlong //')
    END_VERSIONS
    """
}