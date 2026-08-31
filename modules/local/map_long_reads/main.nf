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
    if grep -q "^>" ${contigs} 2>/dev/null; then
        minimap2 \\
            -ax map-ont \\
            -t $task.cpus \\
            ${contigs} \\
            ${reads} \\
            2> ${prefix}.minimap2_align.log \\
            | samtools sort -@ $task.cpus -o ${prefix}_long.sorted.bam -

        samtools index -@ $task.cpus ${prefix}_long.sorted.bam || true
        samtools flagstat --threads $task.cpus ${prefix}_long.sorted.bam > ${prefix}_long.flagstat
    else
        printf "@HD\\tVN:1.6\\tSO:coordinate\\n@SQ\\tSN:dummy\\tLN:100\\n" > sam_header.sam
        samtools view -h -b -o ${prefix}_long.sorted.bam sam_header.sam
        samtools index ${prefix}_long.sorted.bam || true
        touch ${prefix}_long.flagstat
    fi
    touch ${prefix}_long.sorted.bam.bai
    """
}
