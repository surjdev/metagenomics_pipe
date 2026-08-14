process DORADO_BASECALL {
    tag "$meta.id"
    label 'process_high_gpu'

    container 'ontresearch/dorado:sha447c4e6e65ca6c79a7e24db8f78e0440a30cfa5'

    input:
    tuple val(meta), path(pod5_dir)

    output:
    tuple val(meta), path("*.fastq.gz"), emit: reads
    tuple val(meta), path("*.log"),      emit: log

    script:
    def prefix = task.ext.prefix ?: "${meta.id}"
    """
    dorado basecaller \\
        ${params.dorado_model} \\
        ${pod5_dir} \\
        --device cuda:all \\
        > ${prefix}.fastq \\
        2> ${prefix}.dorado.log

    gzip ${prefix}.fastq
    """
}
