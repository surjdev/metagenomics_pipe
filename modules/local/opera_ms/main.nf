process OPERA_MS {
    tag "$meta.id"
    label 'process_high'

    container 'quay.io/biocontainers/megahit:1.2.9--haf24da9_8'

    input:
    tuple val(meta), path(short_reads), path(long_reads)

    output:
    tuple val(meta), path("*.operams.fasta"), emit: contigs
    tuple val(meta), path("opera_out"),       emit: dir

    script:
    def prefix = task.ext.prefix ?: "${meta.id}"
    """
    mkdir -p opera_out
    megahit \\
        -1 ${short_reads[0]} -2 ${short_reads[1]} \\
        -t $task.cpus \\
        -o opera_out/megahit \\
        --out-prefix ${prefix}

    cp opera_out/megahit/${prefix}.contigs.fa ${prefix}.operams.fasta
    """
}
