process GTDBTK {
    tag "$meta.id"
    label 'process_high'

    container 'quay.io/biocontainers/gtdbtk:2.7.2--pyhdfd78af_1'

    input:
    tuple val(meta), path(bins_dir)
    path  db

    output:
    tuple val(meta), path("gtdbtk_out/gtdbtk.*.summary.tsv"), emit: summary, optional: true
    tuple val(meta), path("gtdbtk_out"),                     emit: dir

    script:
    def prefix = task.ext.prefix ?: "${meta.id}"
    """
    mkdir -p gtdbtk_out

    n_bins=\$(find ${bins_dir} -type f -name "*.fa" -o -name "*.fasta" | wc -l)
    if [ "\$n_bins" -gt 0 ]; then
        export GTDBTK_DATA_PATH=${db}
        gtdbtk classify_wf \\
            --genome_dir ${bins_dir} \\
            --out_dir gtdbtk_out \\
            --cpus $task.cpus \\
            --extension fa || true
    fi
    """
}
