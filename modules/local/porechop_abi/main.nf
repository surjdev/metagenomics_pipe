process PORECHOP_ABI {
    tag "$meta.id"
    label 'process_medium'

    container 'quay.io/biocontainers/porechop_abi:0.5.0--py39h97f88f2_0'

    input:
    tuple val(meta), path(reads)

    output:
    tuple val(meta), path("*.porechop.fastq.gz"), emit: reads
    tuple val(meta), path("*.log"),               emit: log

    script:
    def prefix = task.ext.prefix ?: "${meta.id}"
    """
    porechop_abi \\
        -i $reads \\
        -o ${prefix}.porechop.fastq.gz \\
        --threads $task.cpus \\
        2> ${prefix}.porechop.log
    """
}
