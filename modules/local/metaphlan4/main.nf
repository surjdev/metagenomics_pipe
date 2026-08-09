process METAPHLAN4 {
    tag "$meta.id"
    label 'process_medium'
    container 'quay.io/biocontainers/metaphlan:4.0.6--pyhdfd78af_0'

    input:
    tuple val(meta), path(reads)
    path metaphlan_db

    output:
    tuple val(meta), path("*_profile.tsv"), emit: profile
    tuple val(meta), path("*.bowtie2out.txt"), emit: bt2_out

    script:
    def input_type = meta.single_end ? "$reads" : "${reads[0]},${reads[1]}"
    """
    metaphlan $input_type \\
        --bowtie2out ${meta.id}.bowtie2out.txt \\
        --nproc $task.cpus \\
        --input_type fastq \\
        --bowtie2db $metaphlan_db \\
        -o ${meta.id}_profile.tsv
    """
}