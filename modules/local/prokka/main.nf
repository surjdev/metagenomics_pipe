process PROKKA {
    tag "${meta.id}.${bin_fasta.baseName}"
    label 'process_medium'
    container 'quay.io/biocontainers/prokka:1.14.6--pl5321hdfd78af_4'

    input:
    tuple val(meta), path(bin_fasta)

    output:
    tuple val(meta), path("${bin_fasta.baseName}_prokka/*.faa"), emit: faa
    tuple val(meta), path("${bin_fasta.baseName}_prokka/*.gff"), emit: gff

    script:
    """
    prokka \\
        --outdir ${bin_fasta.baseName}_prokka \\
        --prefix ${bin_fasta.baseName} \\
        --cpus $task.cpus \\
        $bin_fasta
    """
}