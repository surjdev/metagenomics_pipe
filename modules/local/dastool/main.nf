process DASTOOL {
    tag "$meta.id"
    label 'process_medium'
    container 'quay.io/biocontainers/das_tool:1.1.6--r43hdfd78af_0'

    input:
    tuple val(meta), path(contigs)
    path(metabat2_bins)
    path(maxbin2_bins)
    path(concoct_bins)
    path(semibin2_bins)

    output:
    tuple val(meta), path("${meta.id}_DASTool_bins/*.fa"), emit: bins
    tuple val(meta), path("*.tsv"),                        emit: summary

    script:
    """
    # Convert bin fasta collections into DASTool coordinate TSV files
    Fasta_to_Contig2Bin.sh -i . -e fa > metabat2.c2b || true
    Fasta_to_Contig2Bin.sh -i . -e fasta > maxbin2.c2b || true
    
    # Build comma-separated input strings based on available c2b conversions
    LABELS=""
    C2B_FILES=""
    
    if [ -f metabat2.c2b ]; then LABELS="MetaBAT2"; C2B_FILES="metabat2.c2b"; fi
    if [ -f maxbin2.c2b ]; then LABELS="\${LABELS},MaxBin2"; C2B_FILES="\${C2B_FILES},maxbin2.c2b"; fi
    
    # Run DASTool optimization
    DAS_Tool \\
        -i \$C2B_FILES \\
        -l \$LABELS \\
        -c $contigs \\
        -o ${meta.id} \\
        --write_bins \\
        --threads $task.cpus
    """
}