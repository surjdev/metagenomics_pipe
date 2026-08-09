process MEGAHIT {
    tag "$meta.id"
    label 'process_high'
    container 'quay.io/biocontainers/megahit:1.2.9--h2e03b76_6'

    input:
    tuple val(meta), path(r1), path(r2)

    output:
    tuple val(meta), path("megahit_out/*.contigs.fa"), emit: contigs
    tuple val(meta), path("megahit_out/*.log"),        emit: log

    script:
    """
    megahit -1 $r1 -2 $r2 -t $task.cpus -o megahit_out --out-prefix ${meta.id}
    """
}