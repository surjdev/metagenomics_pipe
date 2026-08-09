process PRODIGAL {
    tag "$meta.id"
    label 'process_medium'
    container 'quay.io/biocontainers/prodigal:2.6.3--h031d066_7'

    input:
    tuple val(meta), path(contigs)

    output:
    tuple val(meta), path("${meta.id}_genes.gff"), emit: gff
    tuple val(meta), path("${meta.id}_genes.faa"), emit: faa
    tuple val(meta), path("${meta.id}_genes.fna"), emit: fna

    script:
    """
    prodigal \\
        -i $contigs \\
        -o ${meta.id}_genes.gff -f gff \\
        -a ${meta.id}_genes.faa \\
        -d ${meta.id}_genes.fna \\
        -p meta
    """
}