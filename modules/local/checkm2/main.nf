process CHECKM2 {
    tag "$meta.id"
    label 'process_high'
    container 'quay.io/biocontainers/checkm2:1.0.1--pyh7cba7a3_0'

    input:
    tuple val(meta), path(bins)
    path checkm2_db

    output:
    tuple val(meta), path("${meta.id}_checkm2_out"), emit: report
    tuple val(meta), path("${meta.id}_checkm2_out/quality_report.tsv"), emit: summary_tsv

    script:
    """
    checkm2 predict \\
        --threads $task.cpus \\
        --input $bins \\
        --output-directory ${meta.id}_checkm2_out \\
        --database_path $checkm2_db \\
        -x fa # adjust extension if your bins are .fasta or .fna
    """
}