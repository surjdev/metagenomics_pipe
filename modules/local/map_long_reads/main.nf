process MAP_LONG_READS {
    tag "$meta.id"
    label 'process_high'
    container 'quay.io/biocontainers/mulled-v2-66534bcbb7031a14fe7b132046fa8ae20b6ab76a:4d9af567ec6a4b13a17e0b5710609b5dbb37c050-0'

    input:
    tuple val(meta), path(contigs), path(long_reads)

    output:
    tuple val(meta), path("*.bam"), path("*.bam.bai"), emit: alignment

    script:
    """
    minimap2 -ax map-ont -t $task.cpus $contigs $long_reads | \\
        samtools sort -@ $task.cpus -o ${meta.id}_mapped.bam -
    
    samtools index -@ $task.cpus ${meta.id}_mapped.bam
    """
}