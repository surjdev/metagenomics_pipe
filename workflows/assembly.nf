/*
 * workflows/assembly.nf — Assembly Orchestrator Workflow
 * Selects MEGAHIT, Flye, or Opera-MS based on params.assembler
 */

include { MEGAHIT  } from '../modules/local/megahit/main.nf'
include { FLYE     } from '../modules/local/flye/main.nf'
include { OPERA_MS } from '../modules/local/opera_ms/main.nf'

workflow assembly {
    take:
    ch_short_reads  // channel: [ meta, [ r1, r2 ] ]
    ch_long_reads   // channel: [ meta, long_reads ]

    main:
    ch_contigs = Channel.empty()

    if (params.assembler == 'megahit') {
        MEGAHIT( ch_short_reads )
        ch_contigs = MEGAHIT.out.contigs
    }
    else if (params.assembler == 'flye') {
        FLYE( ch_long_reads )
        ch_contigs = FLYE.out.contigs
    }
    else if (params.assembler == 'opera_ms') {
        ch_hybrid = ch_short_reads
            .join( ch_long_reads, by: 0 )
            .map { meta, short_r, long_r -> [ meta, short_r, long_r ] }

        OPERA_MS( ch_hybrid )
        ch_contigs = OPERA_MS.out.contigs
    }

    emit:
    contigs = ch_contigs
}
