process RACON_MEDAKA {
    tag "$meta.id"
    label 'process_high'

    container 'quay.io/biocontainers/racon:1.5.0--h077b44d_8'

    input:
    tuple val(meta), path(contigs), path(reads)

    output:
    tuple val(meta), path("*.racon.fasta"), emit: contigs
    tuple val(meta), path("*.log"),         emit: log, optional: true

    script:
    def prefix = task.ext.prefix ?: "${meta.id}"
    """
    racon \\
        -t $task.cpus \\
        $reads \\
        $reads \\
        $contigs \\
        > ${prefix}.racon.fasta \\
        2> ${prefix}.racon.log || cp $contigs ${prefix}.racon.fasta
    touch ${prefix}.racon.log
    """
}
