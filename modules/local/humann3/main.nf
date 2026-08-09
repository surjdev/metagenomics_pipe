process HUMANN3 {
    tag "$meta.id"
    label 'process_high'
    container 'quay.io/biocontainers/humann:3.9--pyh7cba7a3_0'
    
    // Publish results to the final output directory
    publishDir "${params.outdir}/profiling/humann3", mode: 'copy'

    input:
    tuple val(meta), path(reads)
    path nucleotide_db
    path protein_db

    output:
    tuple val(meta), path("*_genefamilies.tsv"), emit: gene_families
    tuple val(meta), path("*_pathabundance.tsv"), emit: path_abundance
    tuple val(meta), path("*_pathcoverage.tsv"), emit: path_coverage
    tuple val(meta), path("*.log"), emit: log

    script:
    // HUMAnN3 expects a single input file; if reads are paired, they should be concatenated first
    """
    humann \\
        --input $reads \\
        --output . \\
        --nucleotide-database $nucleotide_db \\
        --protein-database $protein_db \\
        --threads $task.cpus \\
        --output-basename ${meta.id}

    mv ${meta.id}_humann_temp/${meta.id}.log . || true
    """
}