#!/usr/bin/env nextflow
/*
 * =============================================================================
 * main_nanoplot_clean.nf — Dedicated NanoPlot QC for Clean Long Reads
 * =============================================================================
 * Purpose:
 *   Evaluates quality statistics of cleaned / host-removed Oxford Nanopore reads:
 *   1. Generates NanoPlot interactive HTML reports and statistics per sample.
 *   2. Aggregates all samples into a consolidated MultiQC report.
 * =============================================================================
 */

nextflow.enable.dsl = 2

// ── Include Modules ───────────────────────────────────────────────────────────
include { NANOPLOT } from './modules/local/nanoplot/main.nf'
include { MULTIQC  } from './modules/local/multiqc/main.nf'

workflow {

    log.info """
    =============================================================================
       📊 NanoPlot QC Pipeline for Clean Long Reads (Nextflow DSL2) 📊
    =============================================================================
     Samplesheet        : ${params.input}
     Output Directory   : ${params.outdir}
    =============================================================================
    """.stripIndent()

    if (!params.input) {
        error "ERROR: Please provide --input <samplesheet.csv>"
    }

    // ── 1. Read & Parse Samplesheet ───────────────────────────────────────────
    ch_reads = Channel
        .fromPath( params.input )
        .splitCsv( header: true )
        .map { row ->
            def id = row.sample
            def fq = row.long_reads ?: row.long_fastq ?: row.fastq
            if (!fq) {
                error "Missing long_reads path for sample ${id} in ${params.input}"
            }
            def meta = [ id: "${id}_clean", single_end: true, platform: 'nanopore' ]
            [ meta, file(fq) ]
        }

    // ── 2. Run NanoPlot on Clean Long Reads ───────────────────────────────────
    NANOPLOT ( ch_reads )

    // ── 3. Aggregate Reports with MultiQC ─────────────────────────────────────
    ch_qc_files = NANOPLOT.out.txt.map { meta, txt -> txt }
    MULTIQC ( ch_qc_files.collect() )
}
