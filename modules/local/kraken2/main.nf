process KRAKEN2 {
    tag "$meta.id"
    label 'process_high'
    container 'quay.io/biocontainers/kraken2:2.1.3--pl5321hdcf5f25_0'

    input:
    tuple val(meta), path(reads)   
    path kraken_db

    output:
    tuple val(meta), path("*.kraken2.report.txt"), emit: report
    tuple val(meta), path("*.kraken2.out.gz"),     emit: classified
    path "versions.yml",                           emit: versions

    script:
    // Dynamically handle paired-end vs single-end/long-reads
    def paired = meta.single_end ? '' : '--paired'
    """
    kraken2 \\
        --db $kraken_db \\
        --threads $task.cpus $paired \\
        --report ${meta.id}.kraken2.report.txt \\
        --output - $reads | gzip > ${meta.id}.kraken2.out.gz

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        kraken2: \$(kraken2 --version 2>&1 | head -n 1 | sed 's/Kraken version //')
    END_VERSIONS
    """
}