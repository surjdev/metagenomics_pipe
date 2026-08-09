process SEMIBIN2 {
    tag "$meta.id"
    label 'process_high'
    container 'quay.io/biocontainers/semibin:2.1.0--py310h30d9df9_0'

    input:
    tuple val(meta), path(contigs), path(bam), path(bai)

    output:
    tuple val(meta), path("semibin2_bins/*.fa"), emit: bins

    script:
    """
    SemiBin2 single_easy_bin \\
        -i $contigs \\
        -b $bam \\
        -o semibin2_output \\
        -t $task.cpus \\
        --environment human_gut # Defaulting environment; parameterize as needed
        
    mkdir semibin2_bins
    mv semibin2_output/output_bins/*.fa semibin2_bins/
    """
}