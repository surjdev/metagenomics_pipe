process FASTP {
    tag "$meta.id"
    label 'process_medium'

    container 'quay.io/biocontainers/fastp:0.23.4--hadf994f_2'

    input:
    tuple val(meta), path(reads)

    output:
    tuple val(meta), path("*.fastp.fastq.gz"), emit: reads
    tuple val(meta), path("*.fastp.json"),     emit: json
    tuple val(meta), path("*.fastp.html"),     emit: html

    script:
    def prefix    = task.ext.prefix ?: "${meta.id}"
    def in_reads  = meta.single_end
        ? "-i ${reads}"
        : "-i ${reads[0]} -I ${reads[1]}"
    def out_reads = meta.single_end
        ? "-o ${prefix}.fastp.fastq.gz"
        : "-o ${prefix}_R1.fastp.fastq.gz -O ${prefix}_R2.fastp.fastq.gz"
    """
    fastp \\
        ${in_reads} \\
        ${out_reads} \\
        --json ${prefix}.fastp.json \\
        --html ${prefix}.fastp.html \\
        --thread $task.cpus \\
        --qualified_quality_phred ${params.min_quality} \\
        --length_required ${params.min_length}
    """
}
