process MAXBIN2 {
    tag "$meta.id"
    label 'process_medium'
    container 'quay.io/biocontainers/maxbin2:2.2.7--hdbdddae_4'

    input:
    tuple val(meta), path(contigs), path(bam), path(bai)

    output:
    tuple val(meta), path("maxbin2_bins/*.fasta"), emit: bins

    script:
    """
    # Generate an abundance file from BAM for MaxBin2
    jgi_summarize_bam_contig_depths --outputDepth depth.txt $bam
    awk '{print \$1 "\\t" \$3}' depth.txt | tail -n +2 > maxbin2_abundance.txt

    mkdir maxbin2_bins
    run_MaxBin.pl \\
        -contig $contigs \\
        -abund maxbin2_abundance.txt \\
        -out maxbin2_bins/bin \\
        -thread $task.cpus
    """
}