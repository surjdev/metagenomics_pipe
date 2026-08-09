process GENOMAD {
    tag "$meta.id"
    label 'process_high'
    container 'quay.io/biocontainers/genomad:1.8.0--pyhdfd78af_0'

    publishDir "${params.outdir}/assembly_annotation/genomad", mode: 'copy'

    input:
    tuple val(meta), path(contigs)
    path genomad_db

    output:
    tuple val(meta), path("${meta.id}_genomad_output/*_virus.fasta"), optional:true, emit: viruses
    tuple val(meta), path("${meta.id}_genomad_output/*_plasmid.fasta"), optional:true, emit: plasmids
    tuple val(meta), path("${meta.id}_genomad_output/*_summary.tsv"), emit: summary

    script:
    """
    genomad end-to-end \\
        --cleanup \\
        --threads $task.cpus \\
        $contigs \\
        ${meta.id}_genomad_output \\
        $genomad_db
    """
}