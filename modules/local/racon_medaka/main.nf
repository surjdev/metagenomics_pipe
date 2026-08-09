process RACON_MEDAKA {
    tag "$meta.id"
    label 'process_high'
    // Uses Conda to combine tools, bypassing the need for a custom multi-tool Docker image
    conda "bioconda::minimap2=2.28 bioconda::racon=1.5.0 bioconda::medaka=1.11.3"

    input:
    tuple val(meta), path(assembly), path(long_reads)

    output:
    tuple val(meta), path("${meta.id}_polished/consensus.fasta"), emit: polished_contigs

    script:
    """
    # 1. Map reads to the draft assembly for Racon
    minimap2 -x map-ont -t $task.cpus $assembly $long_reads > overlaps.paf

    # 2. Polish with Racon
    racon -t $task.cpus $long_reads overlaps.paf $assembly > ${meta.id}_racon.fasta

    # 3. Polish with Medaka
    medaka_consensus -i $long_reads -d ${meta.id}_racon.fasta -o ${meta.id}_polished -t $task.cpus
    """
}