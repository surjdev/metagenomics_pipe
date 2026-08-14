process BOWTIE2_HOST_REMOVAL {
    tag "$meta.id"
    label 'process_high'

    // Image bundles bowtie2 + samtools
    container 'quay.io/biocontainers/mulled-v2-ac74a7f02cebcfbc0119723e2041d6ede773a4b2:a0a54b8eeb4e6b9e9f02dc1a3979dafb5b1dd108-0'

    input:
    tuple val(meta), path(reads)
    path  index

    output:
    tuple val(meta), path("*_nonhost_R{1,2}.fastq.gz"), emit: reads
    tuple val(meta), path("*.flagstat"),                 emit: stats

    script:
    def prefix = task.ext.prefix ?: "${meta.id}"
    """
    # Map reads to host genome; write unmapped pairs to FASTQ
    bowtie2 \\
        -x ${index}/${params.host_index_prefix} \\
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
