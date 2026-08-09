process CAT_BINS {
    tag "$meta.id"
    label 'process_high'
    container 'quay.io/biocontainers/cat:5.2.3--pyhdfd78af_0'

    publishDir "${params.outdir}/bin_taxonomy/cat", mode: 'copy'

    input:
    tuple val(meta), path(bin_fasta)
    path cat_db
    path cat_taxonomy

    output:
    tuple val(meta), path("*.bin2classification.txt"), emit: classification
    tuple val(meta), path("*.ORF2LCA.txt"), emit: orf2lca
    tuple val(meta), path("*.log"), emit: log

    script:
    """
    CAT bin \\
        -b $bin_fasta \\
        -d $cat_db \\
        -t $cat_taxonomy \\
        -n $task.cpus \\
        -o ${meta.id}_BAT

    # Add taxonomic names to the output
    CAT add_names \\
        -i ${meta.id}_BAT.bin2classification.txt \\
        -o ${meta.id}_BAT.bin2classification.names.txt \\
        -t $cat_taxonomy \
        --only_official
    """
}