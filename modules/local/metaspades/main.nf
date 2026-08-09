process METASPADES {
    tag "$meta.id"
    label 'process_high'
    container 'quay.io/biocontainers/spades:3.15.5--h95f258a_1'

    input:
    tuple val(meta), path(r1), path(r2)

    output:
    tuple val(meta), path("${meta.id}_metaspades/scaffolds.fasta"), emit: contigs
    tuple val(meta), path("${meta.id}_metaspades/spades.log"),      emit: log

    script:
    """
    spades.py \\
        --meta \\
        -1 $r1 -2 $r2 \\
        -o ${meta.id}_metaspades \\
        -t $task.cpus \\
        -m ${task.memory.toGiga()}
    """
}