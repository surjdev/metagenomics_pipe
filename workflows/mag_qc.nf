/*
 * workflows/mag_qc.nf — MAG Quality Assessment & Taxonomy Workflow
 * Evaluates completeness/contamination with CheckM2, chimerism with GUNC, and taxonomy with GTDB-Tk.
 */

include { CHECKM2 } from '../modules/local/checkm2/main.nf'
include { GUNC    } from '../modules/local/gunc/main.nf'
include { GTDBTK  } from '../modules/local/gtdbtk/main.nf'

workflow mag_qc {
    take:
    ch_bins_dir  // channel: [ meta, bins_dir ]

    main:
    ch_checkm2_report = Channel.empty()
    ch_gunc_report    = Channel.empty()
    ch_gtdbtk_summary = Channel.empty()

    // ── 1. CheckM2 Quality Evaluation ─────────────────────────────────────────
    if (params.run_checkm2 && params.checkm2_db) {
        CHECKM2( ch_bins_dir, file(params.checkm2_db) )
        ch_checkm2_report = CHECKM2.out.report
    }

    // ── 2. GUNC Chimerism Detection ───────────────────────────────────────────
    if (params.run_gunc && params.gunc_db) {
        GUNC( ch_bins_dir, file(params.gunc_db) )
        ch_gunc_report = GUNC.out.report
    }

    // ── 3. GTDB-Tk Taxonomy Assignment ────────────────────────────────────────
    if (params.run_gtdbtk && params.gtdbtk_db) {
        GTDBTK( ch_bins_dir, file(params.gtdbtk_db) )
        ch_gtdbtk_summary = GTDBTK.out.summary
    }

    emit:
    checkm2_report = ch_checkm2_report
    gunc_report    = ch_gunc_report
    gtdbtk_summary = ch_gtdbtk_summary
}
