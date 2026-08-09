process BOWTIE2_HOST_REMOVAL {
    tag "$meta.id"
    label 'process_high'
    container 'quay.io/biocontainers/bowtie2:2.5.3--py310h4b81fae_1'

    input:
    tuple val(meta), path(r1), path(r2)
    path bt2_index   

    output:
    tuple val(meta), path("*_clean_R1.fastq.gz"), path("*_clean_R2.fastq.gz"), emit: reads
    tuple val(meta), path("*.log"), emit: log
    path "versions.yml",            emit: versions

    script:
    """
    bowtie2 -x ${bt2_index}/host -1 $r1 -2 $r2 \\
        --un-conc-gz ${meta.id}_clean_R%.fastq.gz \\
        -p $task.cpus --very-sensitive 2> ${meta.id}.bowtie2.log \\
        -S /dev/null

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        bowtie2: \$( bowtie2 --version | head -n1 | sed 's/^.*version //' )
    END_VERSIONS
    """

    stub:
    """
    touch ${meta.id}_clean_R1.fastq.gz ${meta.id}_clean_R2.fastq.gz
    touch ${meta.id}.bowtie2.log
    touch versions.yml
    """
}