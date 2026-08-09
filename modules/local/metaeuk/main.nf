process METAEUK {
    tag "$meta.id"
    label 'process_high'
    container 'quay.io/biocontainers/metaeuk:6.a5d39d9--h2a3209d_2'

    publishDir "${params.outdir}/bin_annotation/metaeuk", mode: 'copy'

    input:
    tuple val(meta), path(contigs_or_bins)
    path mmseqs_db // The reference database 

    output:
    tuple val(meta), path("*.fas"), emit: fasta
    tuple val(meta), path("*.gff"), emit: gff
    tuple val(meta), path("*.codon.fas"), emit: codon_fasta

    script:
    """
    mkdir -p tmp
    
    metaeuk easy-predict \\
        $contigs_or_bins \\
        $mmseqs_db \\
        ${meta.id}_metaeuk \\
        tmp \\
        --threads $task.cpus
        
    rm -rf tmp
    """
}