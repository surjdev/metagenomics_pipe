#!/usr/bin/env nextflow
/*
 * main.nf — Hybrid Metagenomics Pipeline Entry Point
 * Layer: Application Layer
 * Strictly orchestrates workflow modules only.
 */

nextflow.enable.dsl = 2

// ── Workflows ─────────────────────────────────────────────────────────────────
include { preprocessing } from './workflows/preprocessing.nf'
include { host_removal  } from './workflows/host_removal.nf'
include { assembly      } from './workflows/assembly.nf'
include { polishing     } from './workflows/polishing.nf'
include { assembly_qc   } from './workflows/assembly_qc.nf'
include { mapping       } from './workflows/mapping.nf'
include { binning       } from './workflows/binning.nf'
include { mag_qc        } from './workflows/mag_qc.nf'
include { assembly_free } from './workflows/assembly_free.nf'
include { annotation    } from './workflows/annotation.nf'
include { reporting     } from './workflows/reporting.nf'

workflow {

    // ── Pre-flight Checks ─────────────────────────────────────────────────────
    log.info Utils.headerBanner()
    Validation.run(params)

    // ── Input Channels from Samplesheet ───────────────────────────────────────
    ch_samplesheet = Channel
        .fromPath( params.input )
        .splitCsv( header: true )
        .map { row -> Samplesheet.parseRow(row) }

    ch_short_reads = ch_samplesheet
        .filter { row -> row.fastq_1 && row.fastq_2 }
        .map { row ->
            def meta = [ id: row.sample, single_end: false, platform: 'illumina' ]
            [ meta, [ file(row.fastq_1), file(row.fastq_2) ] ]
        }

    ch_long_reads = ch_samplesheet
        .filter { row -> row.long_fastq || row.long_reads }
        .map { row ->
            def meta = [ id: row.sample, single_end: true, platform: 'nanopore' ]
            def fq = row.long_fastq ?: row.long_reads
            [ meta, file(fq) ]
        }

    // ── 1. Preprocessing ──────────────────────────────────────────────────────
    preprocessing( ch_short_reads, ch_long_reads )

    // ── 2. Host Removal ───────────────────────────────────────────────────────
    host_removal(
        preprocessing.out.short_reads,
        preprocessing.out.long_reads
    )

    ch_clean_short = host_removal.out.short_reads
    ch_clean_long  = host_removal.out.long_reads

    // ── 3. Assembly ───────────────────────────────────────────────────────────
    assembly( ch_clean_short, ch_clean_long )

    // ── 4. Polishing ──────────────────────────────────────────────────────────
    // Polisher selects either long or short reads depending on params.polisher
    ch_polishing_reads = (params.polisher == 'nextpolish') ? ch_clean_short : ch_clean_long

    polishing(
        assembly.out.contigs,
        ch_polishing_reads
    )

    // ── 5. Assembly QC ────────────────────────────────────────────────────────
    assembly_qc( polishing.out.contigs )

    // ── 6. Read Mapping & Contig Coverage ─────────────────────────────────────
    mapping(
        polishing.out.contigs,
        ch_clean_short,
        ch_clean_long
    )

    // ── 7. MAG Reconstruction / Binning ───────────────────────────────────────
    binning(
        polishing.out.contigs,
        mapping.out.bam,
        mapping.out.bai,
        mapping.out.depth
    )

    // ── 8. MAG Quality Control & Taxonomy ─────────────────────────────────────
    mag_qc( binning.out.bins_dir )

    // ── 9. Read-Based Taxonomic & Functional Profiling ────────────────────────
    assembly_free( ch_clean_short )

    // ── 10. Functional & Structural Annotation ────────────────────────────────
    annotation( polishing.out.contigs )

    // ── 11. Quality Aggregation & Reporting ───────────────────────────────────
    ch_qc_reports = preprocessing.out.qc_reports
        .mix( assembly_qc.out.tsv.map { meta, rep -> rep } )

    reporting(
        ch_qc_reports,
        assembly_qc.out.tsv,
        binning.out.summary,
        assembly_free.out.kraken_report
    )
}
