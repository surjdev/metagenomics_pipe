process MAP_LONG_READS {
    tag "$meta.id"
    label 'process_high'

    // Bundles minimap2 + samtools
    container 'community.wave.seqera.io/library/minimap2_samtools:b09096fc890429ce'

    input:
    tuple val(meta), path(contigs), path(reads)

    output:
    tuple val(meta), path("*.sorted.bam"), path("*.sorted.bam.bai"), emit: bam_bai
    tuple val(meta), path("*.sorted.bam"),                          emit: bam
    tuple val(meta), path("*.flagstat"),                            emit: stats

    script:
    def prefix = task.ext.prefix ?: "${meta.id}"
    """
    minimap2 \\
        -ax map-ont \\
        -t $task.cpus \\
        ${contigs} \\
        ${reads} \\
        2> ${prefix}.minimap2_align.log \\
        | samtools sort -@ $task.cpus -o ${prefix}_long.sorted.bam -

    samtools index -@ $task.cpus ${prefix}_long.sorted.bam
    samtools flagstat --threads $task.cpus ${prefix}_long.sorted.bam > ${prefix}_long.flagstat
    """
}
