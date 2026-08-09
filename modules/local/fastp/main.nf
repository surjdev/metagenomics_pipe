process FASTP {
    tag "$meta.id"
    label 'process_medium'
    container 'quay.io/biocontainers/fastp:0.23.4--h5f740d0_0'
    publishDir "${params.outdir}/qc/fastp/${meta.id}", mode: 'copy'

    input:
    tuple val(meta), path(reads)

    output:
    tuple val(meta), path("*_trimmed_R1.fastq.gz"), path("*_trimmed_R2.fastq.gz"), emit: reads
    tuple val(meta), path("*.json"), emit: json
    tuple val(meta), path("*.html"), emit: html
    path "versions.yml",             emit: versions

    script:
    """
    fastp \\
        -i ${reads[0]} -I ${reads[1]} \\
        -o ${meta.id}_trimmed_R1.fastq.gz -O ${meta.id}_trimmed_R2.fastq.gz \\
        --json ${meta.id}.fastp.json --html ${meta.id}.fastp.html \\
        --thread $task.cpus

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        fastp: \$(fastp --version 2>&1 | sed 's/fastp //' )
    END_VERSIONS
    """

    stub:
    """
    touch ${meta.id}_trimmed_R1.fastq.gz ${meta.id}_trimmed_R2.fastq.gz
    touch ${meta.id}.fastp.json ${meta.id}.fastp.html
    touch versions.yml
    """
}