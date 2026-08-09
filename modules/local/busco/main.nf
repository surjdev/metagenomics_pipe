process BUSCO {
    tag "$meta.id"
    label 'process_medium'
    container 'quay.io/biocontainers/busco:5.7.0--pyhdfd78af_0'

    input:
    tuple val(meta), path(bins)
    val busco_lineage // e.g., 'bacteria_odb10' or passed as a parameter

    output:
    tuple val(meta), path("${meta.id}_busco_out"), emit: report

    script:
    """
    # Note: BUSCO usually runs per-bin, so we use a bash loop here to process the directory, 
    # or you could map the channel to process each bin in a separate Nextflow task. 
    # Grouping them in a bash loop keeps the DAG simpler per sample.
    
    mkdir -p ${meta.id}_busco_out
    
    for bin in ${bins}/*; do
        bin_name=\$(basename \$bin)
        busco \\
            -i \$bin \\
            -o \${bin_name}_busco \\
            -l $busco_lineage \\
            -m geno \\
            -c $task.cpus \\
            --out_path ${meta.id}_busco_out
    done
    """
}