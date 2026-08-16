process MEGAHIT {
    tag "$meta.id"
    label 'process_high'

    container 'quay.io/biocontainers/megahit:1.2.9--haf24da9_8'

    input:
    tuple val(meta), path(reads)

    output:
    tuple val(meta), path("*.contigs.fa"), emit: contigs
    tuple val(meta), path("megahit_out"),  emit: dir

    script:
    def prefix = task.ext.prefix ?: "${meta.id}"
    def input_reads = meta.single_end
        ? "-r ${reads}"
        : "-1 ${reads[0]} -2 ${reads[1]}"
    """
    megahit \\
        ${input_reads} \\
        -t $task.cpus \\
        -o megahit_out \\
        --out-prefix ${prefix}

    mv megahit_out/${prefix}.contigs.fa .
    """
}
