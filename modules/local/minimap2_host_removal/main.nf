process MINIMAP2_HOST_REMOVAL {
    tag "$meta.id"
    label 'process_high'

    // Image bundles minimap2 + samtools
    container 'community.wave.seqera.io/library/minimap2_samtools:b09096fc890429ce'

    input:
    tuple val(meta), path(reads)
    path  reference

    output:
    tuple val(meta), path("*_nonhost.fastq.gz"), emit: reads
    tuple val(meta), path("*.flagstat"),          emit: stats

    script:
    def prefix = task.ext.prefix ?: "${meta.id}"
    """
    # Map long reads to host; extract unmapped reads
    minimap2 \\
        -ax map-ont \\
        -t $task.cpus \\
        ${reference} \\
        ${reads} \\
        | samtools sort -@ $task.cpus -o ${prefix}.host.bam

    samtools flagstat \\
        --threads $task.cpus \\
        ${prefix}.host.bam \\
        > ${prefix}.flagstat

    # Extract unmapped reads (flag 4 = read unmapped)
    samtools view -f 4 -b ${prefix}.host.bam \\
        | samtools fastq \\
        | gzip -c > ${prefix}_nonhost.fastq.gz

    rm ${prefix}.host.bam
    """
}
