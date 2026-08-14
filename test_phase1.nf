#!/usr/bin/env nextflow
/*
 * test_phase1.nf — Phase 1 integration test
 *
 * Tests: FASTQC, FASTP, NANOPLOT, PORECHOP_ABI, FILTLONG
 * (Dorado skipped — requires GPU; Bowtie2/Minimap2 skipped — require host index build)
 *
 * Run with:
 *   nextflow run test_phase1.nf -profile docker,test
 */

nextflow.enable.dsl = 2

include { FASTQC       } from './modules/local/fastqc/main.nf'
include { FASTP        } from './modules/local/fastp/main.nf'
include { NANOPLOT     } from './modules/local/nanoplot/main.nf'
include { PORECHOP_ABI } from './modules/local/porechop_abi/main.nf'
include { FILTLONG     } from './modules/local/filtlong/main.nf'

workflow {

    // ── Load short reads from samplesheet ─────────────────────────────────────
    ch_short = Channel
        .fromPath( params.input )
        .splitCsv( header: true )
        .map { row ->
            def meta = [ id: row.sample, single_end: false ]
            [ meta, [ file(row.fastq_1), file(row.fastq_2) ] ]
        }

    // ── Load long reads from samplesheet ──────────────────────────────────────
    ch_long = Channel
        .fromPath( params.input )
        .splitCsv( header: true )
        .map { row ->
            def meta = [ id: row.sample, single_end: true ]
            [ meta, file(row.long_reads) ]
        }

    // ── Phase 1 module tests ──────────────────────────────────────────────────
    FASTQC       ( ch_short )
    FASTP        ( ch_short )
    NANOPLOT     ( ch_long  )
    PORECHOP_ABI ( ch_long  )
    FILTLONG     ( ch_long  )

    // ── Print summary ─────────────────────────────────────────────────────────
    FASTQC.out.html.view       { meta, html -> "FASTQC  \u2713  ${meta.id}: ${html}" }
    FASTP.out.reads.view       { meta, reads -> "FASTP   \u2713  ${meta.id}: ${reads}" }
    NANOPLOT.out.txt.view      { meta, txt  -> "NANOPLOT\u2713  ${meta.id}: ${txt}" }
    PORECHOP_ABI.out.reads.view{ meta, reads -> "PORECHOP\u2713  ${meta.id}: ${reads}" }
    FILTLONG.out.reads.view    { meta, reads -> "FILTLONG\u2713  ${meta.id}: ${reads}" }
}
