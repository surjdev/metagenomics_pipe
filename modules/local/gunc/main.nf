process GUNC {
    tag "$meta.id"
    label 'process_medium'
    container 'quay.io/biocontainers/gunc:1.0.5--pyhdfd78af_0'

    input:
    tuple val(meta), path(bins)
    path gunc_db // GUNC requires a reference database (e.g., proGenomes)

    output:
    tuple val(meta), path("${meta.id}_gunc_out"), emit: report
    tuple val(meta), path("${meta.id}_gunc_out/GUNC.progenomes_genomes.maxCSS_level.tsv"), emit: summary_tsv

    script:
    """
    gunc run \\
        --input_dir $bins \\
        --out_dir ${meta.id}_gunc_out \\
        --threads $task.cpus \\
        --db_file $gunc_db
    """
}