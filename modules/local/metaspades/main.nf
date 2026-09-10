process METASPADES {
    tag "$meta.id"
    label 'process_high'

    container 'quay.io/biocontainers/spades:3.15.5--h95f258a_1'

    input:
    tuple val(meta), path(short_reads), path(long_reads)

    output:
    tuple val(meta), path("*.metaspades.fasta"), emit: contigs
    tuple val(meta), path("spades_out"),         emit: dir
    tuple val(meta), path("*.log"),              emit: log, optional: true

    script:
    def prefix  = task.ext.prefix ?: "${meta.id}"
    def max_mem = task.memory ? task.memory.toGiga() : (params.max_memory ? params.max_memory.toString().replaceAll(/[^0-9]/, '') : 64)
    def ont_arg = (long_reads && long_reads.name != 'NO_FILE' && file(long_reads).exists() && file(long_reads).size() > 0) ? "--nanopore ${long_reads}" : ""
    """
    if command -v metaspades.py &> /dev/null; then
        SPADES_CMD="metaspades.py"
    elif command -v spades.py &> /dev/null; then
        SPADES_CMD="spades.py --meta"
    else
        SPADES_CMD="metaspades.py"
    fi

    \$SPADES_CMD \\
        -1 ${short_reads[0]} -2 ${short_reads[1]} \\
        ${ont_arg} \\
        -o spades_out \\
        -t $task.cpus \\
        -m ${max_mem}

    if [ -f spades_out/scaffolds.fasta ] && [ -s spades_out/scaffolds.fasta ]; then
        cp spades_out/scaffolds.fasta ${prefix}.metaspades.fasta
    elif [ -f spades_out/contigs.fasta ] && [ -s spades_out/contigs.fasta ]; then
        cp spades_out/contigs.fasta ${prefix}.metaspades.fasta
    else
        touch ${prefix}.metaspades.fasta
    fi

    cp spades_out/spades.log ${prefix}.metaspades.log 2>/dev/null || touch ${prefix}.metaspades.log
    """
}
