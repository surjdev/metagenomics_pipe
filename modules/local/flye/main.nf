process FLYE {
    tag "$meta.id"
    label 'process_high'

    container 'quay.io/biocontainers/flye:2.9.5--py310h275bdba_2'

    input:
    tuple val(meta), path(reads)

    output:
    tuple val(meta), path("*.flye.fasta"), emit: contigs
    tuple val(meta), path("flye_out"),     emit: dir
    tuple val(meta), path("*.log"),        emit: log, optional: true

    script:
    def prefix     = task.ext.prefix ?: "${meta.id}"
    def mode       = params.flye_mode ?: '--nano-raw'
    def extra_args = params.flye_extra_args ?: '--min-overlap 1000'
    """
    mkdir -p flye_out
    flye \\
        ${mode} ${reads} \\
        ${extra_args} \\
        --out-dir flye_out \\
        --threads $task.cpus || true

    if [ -f flye_out/assembly.fasta ] && [ -s flye_out/assembly.fasta ]; then
        cp flye_out/assembly.fasta ${prefix}.flye.fasta
    else
        touch ${prefix}.flye.fasta
    fi
    cp flye_out/flye.log ${prefix}.flye.log 2>/dev/null || touch ${prefix}.flye.log
    """
}
