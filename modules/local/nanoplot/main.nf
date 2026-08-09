process NANOPLOT {
    tag "$meta.id"
    label 'process_low'
    container 'quay.io/biocontainers/nanoplot:1.42.0--pyhdfd78af_0'

    input:
    tuple val(meta), path(long_reads)
    val(suffix) 

    output:
    tuple val(meta), path("${meta.id}_nanoplot_${suffix}"), emit: report_dir
    path "versions.yml",                                    emit: versions

    script:
    """
    NanoPlot \\
        --fastq $long_reads \\
        --threads $task.cpus \\
        --output ${meta.id}_nanoplot_${suffix}

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        nanoplot: \$(NanoPlot --version | sed 's/NanoPlot //')
    END_VERSIONS
    """
}