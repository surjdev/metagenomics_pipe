process ALIGN_READS_TO_CONTIGS {
    tag "$meta.id"
    label 'process_high'
    // Same mulled minimap2+samtools image already used by minimap2_host_removal
    container 'quay.io/biocontainers/mulled-v2-66534bcbb7031a14fe7b132046fa8ae20b6ab76a:4d9af567ec6a4b13a17e0b5710609b5dbb37c050-0'

    input:
    tuple val(meta), path(contigs), path(reads)
    // reads: a 2-item list [r1, r2] for short/paired reads, or a single file for long reads

    output:
    tuple val(meta), path("*.sorted.bam"), path("*.sorted.bam.bai"), emit: bam

    script:
    // minimap2's short-read preset ('sr') is used for paired reads, 'map-ont' for
    // long reads. This is deliberately based on the *shape* of `reads` rather than
    // meta.input_type, since input_type is only meaningful for the long-read arm.
    def preset    = (reads instanceof List) ? 'sr' : 'map-ont'
    def reads_arg = (reads instanceof List) ? reads.join(' ') : reads
    """
    minimap2 -ax ${preset} -t $task.cpus $contigs $reads_arg \\
        | samtools sort -@ $task.cpus -o ${meta.id}.sorted.bam -
    samtools index ${meta.id}.sorted.bam
    """

    stub:
    """
    touch ${meta.id}.sorted.bam ${meta.id}.sorted.bam.bai
    """
}