process CHECKM2 {
    tag "$meta.id"
    label 'process_high'

    container 'quay.io/biocontainers/checkm2:1.1.0--pyh7e72e81_1'

    input:
    tuple val(meta), path(bins_dir)
    path  db

    output:
    tuple val(meta), path("checkm2_out/quality_report.tsv"), emit: report, optional: true
    tuple val(meta), path("checkm2_out"),                   emit: dir

    script:
    def prefix = task.ext.prefix ?: "${meta.id}"
    """
    mkdir -p checkm2_out

    # Check if there are any fasta files in bins_dir
    n_bins=\$(find ${bins_dir} -type f -name "*.fa" -o -name "*.fasta" | wc -l)
    if [ "\$n_bins" -gt 0 ]; then
        checkm2 predict \\
            --threads $task.cpus \\
            --input ${bins_dir} \\
            -x fa \\
            --output-directory checkm2_out \\
            --database_path ${db} || true
    fi
    """
}
