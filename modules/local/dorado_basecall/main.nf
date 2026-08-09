process DORADO_BASECALL {
    tag "$meta.id"
    label 'process_high'
    container 'ontresearch/dorado:0.5.3'

    input:
    tuple val(meta), path(raw_reads)
    val(model)

    output:
    tuple val(meta), path("*.fastq.gz"), emit: reads
    path "versions.yml",                 emit: versions

    script:
    """
    dorado basecaller $model $raw_reads \\
        --threads $task.cpus > ${meta.id}_basecalled.fastq
        
    gzip ${meta.id}_basecalled.fastq

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        dorado: \$(dorado -v 2>&1 | sed 's/dorado //')
    END_VERSIONS
    """
}