process FLYE {
    tag "$meta.id"
    label 'process_high'

    container 'quay.io/biocontainers/flye:2.9.5--py310h275bdba_2'

    input:
    tuple val(meta), path(reads)

    output:
    tuple val(meta), path("*.flye.fasta"), emit: contigs
    tuple val(meta), path("flye_out"),     emit: dir

    script:
    def prefix     = task.ext.prefix ?: "${meta.id}"
    def mode       = params.flye_mode ?: '--nano-raw'
    def extra_args = params.flye_extra_args ?: '--min-overlap 1000'
    """
    flye \\
        ${mode} ${reads} \\
        ${extra_args} \\
        --out-dir flye_out \\
        --threads $task.cpus

    cp flye_out/assembly.fasta ${prefix}.flye.fasta
    """
}
