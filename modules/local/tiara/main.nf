process TIARA {
    tag "$meta.id"
    label 'process_medium'
    container 'quay.io/biocontainers/tiara:1.0.3--pyhdfd78af_0'

    input:
    tuple val(meta), path(contigs)

    output:
    tuple val(meta), path("*_prokaryote.fasta"), emit: prokaryote_contigs
    tuple val(meta), path("*.txt"),              emit: report

    script:
    """
    tiara \\
        -i $contigs \\
        -o ${meta.id}_tiara_classification.txt \\
        --prokaryote ${meta.id}_prokaryote.fasta \\
        --threads $task.cpus
    """
}