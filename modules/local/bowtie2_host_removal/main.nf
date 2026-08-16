process BOWTIE2_HOST_REMOVAL {
    tag "$meta.id"
    label 'process_high'

    // Image bundles bowtie2 + samtools
    container 'community.wave.seqera.io/library/bowtie2_htslib_samtools_pigz:edeb13799090a2a6'

    input:
    tuple val(meta), path(reads)
    path  index

    output:
    tuple val(meta), path("*_nonhost_R{1,2}.fastq.gz"), emit: reads
    tuple val(meta), path("*.flagstat"),                 emit: stats

    script:
    def prefix = task.ext.prefix ?: "${meta.id}"
    """
    if [ -d "${index}" ]; then
        idx_prefix="${index}/${params.host_index_prefix}"
    elif [ -f "${index}" ] && [[ "${index}" == *.bt2 ]]; then
        idx_prefix="\$(echo "${index}" | sed 's/\\.[0-9]\\.bt2//')"
    else
        bowtie2-build --threads $task.cpus "${index}" host_idx
        idx_prefix="host_idx"
    fi

    # Map reads to host genome; write unmapped pairs to FASTQ
    bowtie2 \\
        -x \${idx_prefix} \\
        -1 ${reads[0]} \\
        -2 ${reads[1]} \\
        --threads $task.cpus \\
        --un-conc-gz ${prefix}_nonhost_R%.fastq.gz \\
        -S ${prefix}.host.sam \\
        2> ${prefix}.bowtie2.log

    samtools flagstat \\
        --threads $task.cpus \\
        ${prefix}.host.sam \\
        > ${prefix}.flagstat

    rm ${prefix}.host.sam
    """
}
