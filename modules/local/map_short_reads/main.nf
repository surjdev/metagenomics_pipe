process MAP_SHORT_READS {
    tag "$meta.id"
    label 'process_high'

    // Bundles bowtie2 + samtools
    container 'community.wave.seqera.io/library/bowtie2_htslib_samtools_pigz:edeb13799090a2a6'

    input:
    tuple val(meta), path(contigs), path(reads)

    output:
    tuple val(meta), path("*.sorted.bam"), path("*.sorted.bam.bai"), emit: bam_bai
    tuple val(meta), path("*.sorted.bam"),                          emit: bam
    tuple val(meta), path("*.flagstat"),                            emit: stats

    script:
    def prefix = task.ext.prefix ?: "${meta.id}"
    def input_reads = meta.single_end
        ? "-U ${reads}"
        : "-1 ${reads[0]} -2 ${reads[1]}"
    """
    mkdir -p bt2_idx
    bowtie2-build --threads $task.cpus ${contigs} bt2_idx/${prefix}_contigs

    bowtie2 \\
        -x bt2_idx/${prefix}_contigs \\
        ${input_reads} \\
        --threads $task.cpus \\
        2> ${prefix}.bowtie2_align.log \\
        | samtools sort -@ $task.cpus -o ${prefix}_short.sorted.bam -

    samtools index -@ $task.cpus ${prefix}_short.sorted.bam
    samtools flagstat --threads $task.cpus ${prefix}_short.sorted.bam > ${prefix}_short.flagstat
    """
}
