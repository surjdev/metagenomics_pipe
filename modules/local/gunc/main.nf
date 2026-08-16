process GUNC {
    tag "$meta.id"
    label 'process_high'

    container 'quay.io/biocontainers/gunc:1.1.1--pyhdfd78af_0'

    input:
    tuple val(meta), path(bins_dir)
    path  db

    output:
    tuple val(meta), path("gunc_out/*maxCSS_level.tsv"), emit: report, optional: true
    tuple val(meta), path("gunc_out"),                  emit: dir

    script:
    def prefix = task.ext.prefix ?: "${meta.id}"
    """
    mkdir -p gunc_out

    n_bins=\$(find ${bins_dir} -type f -name "*.fa" -o -name "*.fasta" | wc -l)
    if [ "\$n_bins" -gt 0 ]; then
        gunc run \\
            --input_dir ${bins_dir} \\
            --file_suffix .fa \\
            -r ${db} \\
            --out_dir gunc_out \\
            --threads $task.cpus || true
    fi
    """
}
