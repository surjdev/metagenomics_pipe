process BBNORM {
    tag "$meta.id"
    label 'process_medium'
    container 'quay.io/biocontainers/bbmap:39.06--h92535d8_0'

    input:
    tuple val(meta), path(r1), path(r2)

    output:
    tuple val(meta), path("*_norm_R1.fastq.gz"), path("*_norm_R2.fastq.gz"), emit: reads
    tuple val(meta), path("*.log"), emit: log
    path "versions.yml",           emit: versions

    script:
    """
    bbnorm.sh \\
        in1=$r1 in2=$r2 \\
        out1=${meta.id}_norm_R1.fastq.gz out2=${meta.id}_norm_R2.fastq.gz \\
        target=100 min=5 \\
        threads=$task.cpus \\
        -Xmx${task.memory.toGiga()}g \\
        > ${meta.id}.bbnorm.log 2>&1

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        bbmap: \$( bbnorm.sh --version 2>&1 | grep -i "BBMap version" | sed 's/.*version //' )
    END_VERSIONS
    """

    stub:
    """
    touch ${meta.id}_norm_R1.fastq.gz ${meta.id}_norm_R2.fastq.gz
    touch ${meta.id}.bbnorm.log
    touch versions.yml
    """
}