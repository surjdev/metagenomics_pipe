process OPERA_MS {
    tag "$meta.id"
    label 'process_high'
    container 'quay.io/biocontainers/opera-ms:0.9.0--h516909a_2'

    input:
    tuple val(meta), path(r1), path(r2), path(long_reads)

    output:
    tuple val(meta), path("opera_out/contigs.wrapper.fasta"), emit: contigs
    tuple val(meta), path("opera_out/*.log"),                 emit: log

    script:
    """
    OPERA-MS \\
        --short-read-1 $r1 \\
        --short-read-2 $r2 \\
        --long-read $long_reads \\
        --num-processors $task.cpus \\
        --output-directory opera_out
    """
}