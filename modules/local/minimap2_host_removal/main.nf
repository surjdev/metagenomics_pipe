process MINIMAP2_HOST_REMOVAL {
    tag "$meta.id"
    label 'process_high'
    container 'quay.io/biocontainers/mulled-v2-66534bcbb7031a14fe7b132046fa8ae20b6ab76a:4d9af567ec6a4b13a17e0b5710609b5dbb37c050-0'

    input:
    tuple val(meta), path(long_reads)
    path host_fasta

    output:
    tuple val(meta), path("*_clean.fastq.gz"), emit: reads
    path "versions.yml",                       emit: versions

    script:
    """
    minimap2 -ax map-ont -t $task.cpus $host_fasta $long_reads \\
        | samtools fastq -f 4 -@ $task.cpus - \\
        | gzip > ${meta.id}_clean.fastq.gz

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        minimap2: \$(minimap2 --version)
        samtools: \$(samtools --version | head -n 1 | sed 's/samtools //')
    END_VERSIONS
    """
}