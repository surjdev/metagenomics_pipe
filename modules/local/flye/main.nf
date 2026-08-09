process FLYE {
    tag "$meta.id"
    label 'process_high'
    container 'quay.io/biocontainers/flye:2.9.3--py310h2b25ed5_0'

    input:
    tuple val(meta), path(long_reads)

    output:
    tuple val(meta), path("flye_out/assembly.fasta"), emit: contigs
    tuple val(meta), path("flye_out/flye.log"),       emit: log

    script:
    """
    flye \\
        --nano-hq $long_reads \\
        -t $task.cpus \\
        -o flye_out \\
        --meta
    """
}