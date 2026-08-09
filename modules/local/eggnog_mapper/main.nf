process EGGNOG_MAPPER {
    tag "${meta.id}.${faa.baseName}"
    label 'process_high'
    container 'quay.io/biocontainers/eggnog-mapper:2.1.9--pyhdfd78af_0'
    publishDir "${params.outdir}/annotation/${meta.id}/eggnog", mode: 'copy'

    input:
    tuple val(meta), path(faa)
    path eggnog_db

    output:
    tuple val(meta), path("*.emapper.annotations"), emit: annotations

    script:
    """
    emapper.py \\
        -i $faa \\
        --output ${faa.baseName} \\
        --cpu $task.cpus \\
        --data_dir $eggnog_db \\
        -m diamond
    """
}