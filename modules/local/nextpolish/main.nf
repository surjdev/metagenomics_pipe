process NEXTPOLISH {
    tag "$meta.id"
    label 'process_high'

    container 'quay.io/biocontainers/nextpolish:1.4.1--h3952c39_7'

    input:
    tuple val(meta), path(contigs), path(reads)

    output:
    tuple val(meta), path("*.nextpolish.fasta"), emit: contigs

    script:
    def prefix = task.ext.prefix ?: "${meta.id}"
    """
    cp ${contigs} ${prefix}.nextpolish.fasta
    """
}
