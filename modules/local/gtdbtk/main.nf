process GTDBTK {
    tag "$meta.id"
    label 'process_high'
    container 'quay.io/biocontainers/gtdbtk:2.3.2--pyhdfd78af_0'
    publishDir "${params.outdir}/taxonomy/${meta.id}/gtdbtk", mode: 'copy'

    input:
    tuple val(meta), path(bins_dir)
    path gtdbtk_db

    output:
    tuple val(meta), path("gtdbtk_output/*"), emit: results
    tuple val(meta), path("gtdbtk_output/*.summary.tsv"), emit: summary

    script:
    """
    # Tell GTDB-Tk where the mounted database is located
    export GTDBTK_DATA_PATH=${gtdbtk_db}
    
    gtdbtk classify_wf \\
        --genome_dir $bins_dir \\
        --extension fa \\
        --out_dir gtdbtk_output \\
        --cpus $task.cpus
    """
}