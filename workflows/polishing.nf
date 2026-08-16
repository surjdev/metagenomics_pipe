/*
 * workflows/polishing.nf — Assembly Polishing Workflow
 * Polishes assembly contigs using long-read or short-read polishing
 */

include { RACON_MEDAKA } from '../modules/local/racon_medaka/main.nf'
include { NEXTPOLISH   } from '../modules/local/nextpolish/main.nf'

workflow polishing {
    take:
    ch_contigs  // channel: [ meta, contigs ]
    ch_reads    // channel: [ meta, reads ]

    main:
    ch_polished = ch_contigs

    if (params.run_polishing) {
        if (params.polisher == 'racon') {
            ch_input = ch_contigs
                .map { meta, contigs -> [ meta.id, meta, contigs ] }
                .join( ch_reads.map { meta, reads -> [ meta.id, reads ] }, by: 0 )
                .map { id, meta, contigs, reads -> [ meta, contigs, reads ] }

            RACON_MEDAKA( ch_input )
            ch_polished = RACON_MEDAKA.out.contigs
        } else if (params.polisher == 'nextpolish') {
            ch_input = ch_contigs
                .map { meta, contigs -> [ meta.id, meta, contigs ] }
                .join( ch_reads.map { meta, reads -> [ meta.id, reads ] }, by: 0 )
                .map { id, meta, contigs, reads -> [ meta, contigs, reads ] }

            NEXTPOLISH( ch_input )
            ch_polished = NEXTPOLISH.out.contigs
        }
    }

    emit:
    contigs = ch_polished
}
