#!/usr/bin/env nextflow
/*
 * test/test_phase2.nf — Phase 2 integration test
 *
 * Tests: MEGAHIT, FLYE, OPERA_MS, RACON_MEDAKA, NEXTPOLISH, QUAST
 *
 * Run with:
 *   nextflow run test/test_phase2.nf -profile docker,test
 */

nextflow.enable.dsl = 2

include { MEGAHIT       } from '../modules/local/megahit/main.nf'
include { FLYE          } from '../modules/local/flye/main.nf'
include { OPERA_MS      } from '../modules/local/opera_ms/main.nf'
include { RACON_MEDAKA  } from '../modules/local/racon_medaka/main.nf'
include { NEXTPOLISH    } from '../modules/local/nextpolish/main.nf'
include { QUAST         } from '../modules/local/quast/main.nf'

workflow {

    // ── Load short reads ──────────────────────────────────────────────────────
    ch_short = Channel
        .fromPath( params.input )
        .splitCsv( header: true )
        .map { row ->
            def meta = [ id: row.sample, single_end: false ]
            [ meta, [ file(row.fastq_1), file(row.fastq_2) ] ]
        }

    // ── Load long reads ───────────────────────────────────────────────────────
    ch_long = Channel
        .fromPath( params.input )
        .splitCsv( header: true )
        .map { row ->
            def meta = [ id: row.sample, single_end: true ]
            [ meta, file(row.long_reads) ]
        }

    // ── 1. Illumina assembly (MEGAHIT) ────────────────────────────────────────
    MEGAHIT ( ch_short )

    // ── 2. Nanopore assembly (FLYE) ───────────────────────────────────────────
    FLYE ( ch_long )

    // ── 3. Hybrid assembly (OPERA-MS) ─────────────────────────────────────────
    ch_hybrid = ch_short.join(ch_long).map { meta, short_r, long_r -> [ meta, short_r, long_r ] }
    OPERA_MS ( ch_hybrid )

    // ── 4. Polishing ──────────────────────────────────────────────────────────
    ch_racon_in = MEGAHIT.out.contigs.join(ch_long)
    RACON_MEDAKA ( ch_racon_in )

    ch_nextpolish_in = MEGAHIT.out.contigs.join(ch_short)
    NEXTPOLISH ( ch_nextpolish_in )

    // ── 5. Assembly QC (QUAST) ────────────────────────────────────────────────
    QUAST ( MEGAHIT.out.contigs )

    // ── Summary logging ───────────────────────────────────────────────────────
    MEGAHIT.out.contigs.view      { meta, fa   -> "MEGAHIT    ✓  ${meta.id}: ${fa}" }
    FLYE.out.contigs.view         { meta, fa   -> "FLYE       ✓  ${meta.id}: ${fa}" }
    OPERA_MS.out.contigs.view     { meta, fa   -> "OPERA-MS   ✓  ${meta.id}: ${fa}" }
    RACON_MEDAKA.out.contigs.view { meta, fa   -> "RACON      ✓  ${meta.id}: ${fa}" }
    NEXTPOLISH.out.contigs.view   { meta, fa   -> "NEXTPOLISH ✓  ${meta.id}: ${fa}" }
    QUAST.out.html.view           { meta, html -> "QUAST      ✓  ${meta.id}: ${html}" }
}
