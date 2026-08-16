/*
 * workflows/annotation.nf — Functional & Structural Annotation Workflow
 * Orchestrates Prokka prokaryotic annotation and geNomad viral/plasmid detection.
 */

include { PROKKA  } from '../modules/local/prokka/main.nf'
include { GENOMAD } from '../modules/local/genomad/main.nf'

workflow annotation {
    take:
    ch_contigs  // channel: [ meta, contigs ]

    main:
    ch_gff             = Channel.empty()
    ch_faa             = Channel.empty()
    ch_fna             = Channel.empty()
    ch_tsv             = Channel.empty()
    ch_genomad_summary = Channel.empty()

    // ── 1. Prokka Gene Prediction & Annotation ────────────────────────────────
    if (params.run_prokka) {
        PROKKA( ch_contigs )
        ch_gff = PROKKA.out.gff
        ch_faa = PROKKA.out.faa
        ch_fna = PROKKA.out.fna
        ch_tsv = PROKKA.out.tsv
    }

    // ── 2. geNomad Viral & Plasmid Identification ─────────────────────────────
    if (params.run_genomad && params.genomad_db) {
        GENOMAD( ch_contigs, file(params.genomad_db) )
        ch_genomad_summary = GENOMAD.out.summary
    }

    emit:
    gff             = ch_gff
    faa             = ch_faa
    fna             = ch_fna
    tsv             = ch_tsv
    genomad_summary = ch_genomad_summary
}
