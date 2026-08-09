process METABAT2 {
    tag "$meta.id"
    label 'process_medium'
    container 'quay.io/biocontainers/metabat2:2.15--h5670f2d_1'

    input:
    tuple val(meta), path(contigs), path(bam), path(bai)

    output:
    tuple val(meta), path("metabat2_bins/*.fa"), emit: bins
    tuple val(meta), path("*.depth.txt"),        emit: depth

    script:
    """
    # Calculate depth from BAM
    jgi_summarize_bam_contig_depths \\
        --outputDepth ${meta.id}.depth.txt \\
        $bam

    mkdir metabat2_bins
    metabat2 \\
        -i $contigs \\
        -a ${meta.id}.depth.txt \\
        -o metabat2_bins/bin \\
        -t $task.cpus
    """
}