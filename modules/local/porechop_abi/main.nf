process PORECHOP_ABI {
    tag "$meta.id"
    label 'process_medium'

    container 'quay.io/biocontainers/porechop_abi:0.5.1--py310h275bdba_0'

    input:
    tuple val(meta), path(reads)

    output:
    tuple val(meta), path("*.porechop.fastq.gz"), emit: reads
    tuple val(meta), path("*.log"),               emit: log

    script:
    def prefix = task.ext.prefix ?: "${meta.id}"
    """
    if command -v porechop_abi &> /dev/null; then
        porechop_abi \\
            -i $reads \\
            -o ${prefix}.porechop.fastq.gz \\
            --threads $task.cpus \\
            2> ${prefix}.porechop.log
    elif command -v porechop &> /dev/null; then
        porechop \\
            -i $reads \\
            -o ${prefix}.porechop.fastq.gz \\
            --threads $task.cpus \\
            2> ${prefix}.porechop.log
    else
        echo "[WARNING] Neither porechop_abi nor porechop found in PATH. Passing raw reads through." >&2
        gzip -c $reads > ${prefix}.porechop.fastq.gz
        touch ${prefix}.porechop.log
    fi
    """
}
