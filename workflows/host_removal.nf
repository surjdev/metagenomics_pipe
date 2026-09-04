include { BOWTIE2_HOST_REMOVAL  } from '../modules/local/bowtie2_host_removal/main.nf'
include { MINIMAP2_HOST_REMOVAL } from '../modules/local/minimap2_host_removal/main.nf'

workflow host_removal {

    take:
    ch_clean_short  // channel: [ meta, [ fastq_1, fastq_2 ] ]
    ch_clean_long   // channel: [ meta, fastq ]

    main:
    ch_host_stats  = Channel.empty()
    ch_micro_short = ch_clean_short
    ch_micro_long  = ch_clean_long

    if (params.host_genome) {
        // Build a value channel for the genome file only when the param is set.
        // Using Channel.value() here avoids calling file(null) at DAG construction
        // time, which is the root cause of "Argument of file() cannot be null".
        ch_host_genome = Channel.value( file(params.host_genome) )

        // ── Short reads → Bowtie2 ────────────────────────────────────────────────
        BOWTIE2_HOST_REMOVAL (
            ch_clean_short,
            ch_host_genome
        )
        ch_micro_short = BOWTIE2_HOST_REMOVAL.out.reads
        ch_host_stats  = ch_host_stats.mix( BOWTIE2_HOST_REMOVAL.out.stats )

        // ── Long reads → Minimap2 ────────────────────────────────────────────────
        MINIMAP2_HOST_REMOVAL (
            ch_clean_long,
            ch_host_genome
        )
        ch_micro_long = MINIMAP2_HOST_REMOVAL.out.reads
        ch_host_stats = ch_host_stats.mix( MINIMAP2_HOST_REMOVAL.out.stats )
    }

    emit:
    short_reads  = ch_micro_short        // [ meta, [ fq1, fq2 ] ] — microbial only
    long_reads   = ch_micro_long         // [ meta, fastq ] — microbial only
    host_stats   = ch_host_stats
}
