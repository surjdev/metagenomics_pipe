process ALIGN_READS_TO_CONTIGS {
    tag "$meta.id"
    label 'process_medium'

    container 'quay.io/biocontainers/metabat2:2.18--h38e344b_2'

    input:
    tuple val(meta), path(bams), path(bais)

    output:
    tuple val(meta), path("*_depth.txt"), emit: depth

    script:
    def prefix = task.ext.prefix ?: "${meta.id}"
    """
    jgi_summarize_bam_contig_depths \\
        --outputDepth ${prefix}_depth.txt \\
        ${bams}
    """
}
