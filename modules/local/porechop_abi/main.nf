process PORECHOP_ABI {
    tag "$meta.id"
    label 'process_medium'
    container 'quay.io/biocontainers/porechop_abi:0.5.0--py310h19ad5d1_1'

    input:
    tuple val(meta), path(long_reads)

    output:
    tuple val(meta), path("*_trimmed.fastq.gz"), emit: reads
    tuple val(meta), path("*.log"),              emit: log
    path "versions.yml",                         emit: versions

    script:
    """
    porechop_abi \\
        -i $long_reads \\
        -o ${meta.id}_trimmed.fastq.gz \\
        --threads $task.cpus > ${meta.id}_porechop.log 2>&1

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        porechop_abi: \$(porechop_abi --version)
    END_VERSIONS
    """
}