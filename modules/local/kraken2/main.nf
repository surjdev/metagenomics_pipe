process KRAKEN2 {
    tag "$meta.id"
    label 'process_high'

    container 'quay.io/biocontainers/kraken2:2.1.6--pl5321h077b44d_0'

    input:
    tuple val(meta), path(reads)
    path  db

    output:
    tuple val(meta), path("*_kraken2_report.txt"), emit: report
    tuple val(meta), path("*_kraken2_output.txt"), emit: output, optional: true

    script:
    def prefix = task.ext.prefix ?: "${meta.id}"
    def input_reads = meta.single_end
        ? "${reads}"
        : "--paired ${reads[0]} ${reads[1]}"
    """
    kraken2 \\
        --db ${db} \\
        --threads $task.cpus \\
        --report ${prefix}_kraken2_report.txt \\
        --output ${prefix}_kraken2_output.txt \\
        ${input_reads}
    """
}
