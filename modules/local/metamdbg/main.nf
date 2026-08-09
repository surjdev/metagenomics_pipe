process METAMDBG {
    tag "$meta.id"
    label 'process_high'
    container 'quay.io/biocontainers/metamdbg:1.3.0--h9a82719_0'

    input:
    tuple val(meta), path(long_reads)

    output:
    tuple val(meta), path("${meta.id}_metamdbg_contigs.fasta"), emit: contigs

    script:
    """
    metaMDBG asm \\
        --in $long_reads \\
        --out ${meta.id}_metamdbg \\
        --threads $task.cpus

    # Extract the contigs to standard fasta for downstream compatibility
    gunzip -c ${meta.id}_metamdbg/contigs.fasta.gz > ${meta.id}_metamdbg_contigs.fasta
    """
}