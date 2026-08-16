/*
 * workflows/assembly_qc.nf — Assembly QC Workflow
 * Evaluates assembled contigs quality using QUAST
 */

include { QUAST } from '../modules/local/quast/main.nf'

workflow assembly_qc {
    take:
    ch_contigs  // channel: [ meta, contigs ]

    main:
    ch_html = Channel.empty()
    ch_tsv  = Channel.empty()
    ch_dir  = Channel.empty()

    if (params.run_quast) {
        QUAST( ch_contigs )
        ch_html = QUAST.out.html
        ch_tsv  = QUAST.out.tsv
        ch_dir  = QUAST.out.dir
    }

    emit:
    html = ch_html
    tsv  = ch_tsv
    dir  = ch_dir
}
