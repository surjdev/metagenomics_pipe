process PROKKA {
    tag "$meta.id"
    label 'process_high'

    container 'quay.io/biocontainers/prokka:1.14.6--pl5321hdfd78af_5'

    input:
    tuple val(meta), path(fasta)

    output:
    tuple val(meta), path("prokka_out/*.gff"), emit: gff
    tuple val(meta), path("prokka_out/*.faa"), emit: faa
    tuple val(meta), path("prokka_out/*.fna"), emit: fna
    tuple val(meta), path("prokka_out/*.tsv"), emit: tsv
    tuple val(meta), path("prokka_out"),       emit: dir

    script:
    def prefix = task.ext.prefix ?: "${meta.id}"
    """
    mkdir -p prokka_out
    if grep -q "^>" ${fasta} 2>/dev/null; then
        prokka \\
            --outdir prokka_out \\
            --prefix ${prefix} \\
            --cpus $task.cpus \\
            --metagenome \\
            --force \\
            ${fasta} || true
    fi
    touch prokka_out/${prefix}.gff prokka_out/${prefix}.faa prokka_out/${prefix}.fna prokka_out/${prefix}.tsv
    """
}
