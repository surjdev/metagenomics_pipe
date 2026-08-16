process GENOMAD {
    tag "$meta.id"
    label 'process_high'

    container 'quay.io/biocontainers/genomad:1.8.1--pyhdfd78af_0'

    input:
    tuple val(meta), path(fasta)
    path  db

    output:
    tuple val(meta), path("genomad_out/*_summary"), emit: summary, optional: true
    tuple val(meta), path("genomad_out"),          emit: dir

    script:
    def prefix = task.ext.prefix ?: "${meta.id}"
    """
    mkdir -p genomad_out
    genomad end-to-end \\
        ${fasta} \\
        genomad_out \\
        ${db} \\
        --threads $task.cpus \\
        --cleanup || true
    """
}
