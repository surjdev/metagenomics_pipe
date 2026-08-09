process BRACKEN {
    tag "$meta.id"
    label 'process_low'
    container 'quay.io/biocontainers/bracken:2.9--py310h590efa1_0'

    input:
    tuple val(meta), path(kraken_report)
    path bracken_db

    output:
    tuple val(meta), path("*.bracken.tsv"),        emit: abundances
    tuple val(meta), path("*.bracken_report.txt"), emit: report
    path "versions.yml",                           emit: versions

    script:
    """
    bracken \\
        -d $bracken_db \\
        -i $kraken_report \\
        -o ${meta.id}.bracken.tsv \\
        -w ${meta.id}.bracken_report.txt \\
        -r 150 \\
        -l S 

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        bracken: \$(bracken -v 2>&1 | sed 's/Bracken //')
    END_VERSIONS
    """
}