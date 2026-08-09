process CONCOCT {
    tag "$meta.id"
    label 'process_high'
    container 'quay.io/biocontainers/concoct:1.1.0--py310h26a3dcf_6'

    input:
    tuple val(meta), path(contigs), path(bam), path(bai)

    output:
    tuple val(meta), path("concoct_bins/*.fa"), emit: bins

    script:
    """
    # Cut contigs and generate coverage table
    cut_up_fasta.py $contigs -c 10000 -o 0 --merge_last > contigs_10k.fa
    concoct_coverage_table.py contigs_10k.fa $bam > coverage_table.tsv

    # Run CONCOCT clustering
    concoct \\
        --composition_file contigs_10k.fa \\
        --coverage_file coverage_table.tsv \\
        -b concoct_output/ \\
        -t $task.cpus

    # Merge cut-up clusters back to original contigs
    merge_cutup_clustering.py concoct_output/clustering_gt1000.csv > merged_clustering.csv
    
    mkdir concoct_bins
    extract_fasta_bins.py $contigs merged_clustering.csv --output_path concoct_bins/
    
    # Rename extension to .fa if required for consistency
    cd concoct_bins && for f in *.fa; do mv "\$f" "bin_\$f"; done
    """
}