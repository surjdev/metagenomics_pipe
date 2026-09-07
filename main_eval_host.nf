#!/usr/bin/env nextflow
/*
 * =============================================================================
 * main_eval_host.nf — Dedicated Host Removal & Krona Evaluation Pipeline
 * =============================================================================
 * Purpose:
 *   Evaluates the direct impact of host removal on Oxford Nanopore metagenomics data:
 *   1. Compares taxonomic profiling (Kraken2) and Krona Before vs After Host Removal.
 *   2. Adheres strictly to Oxford Nanopore EPI2ME (wf-metagenomics) quality thresholds:
 *      - Filtlong: min_quality >= 10, min_length >= 300 bp
 *      - Minimap2: -ax map-ont against host reference
 *      - Kraken2: optional confidence threshold for long reads
 *   3. Operates independently from main.nf to prevent modifying primary architecture.
 * =============================================================================
 */

nextflow.enable.dsl = 2

// ── Include Script Helpers ───────────────────────────────────────────────────
include { Samplesheet } from './lib/Samplesheet.groovy'

// ── Include Modules with DSL2 Aliases ─────────────────────────────────────────
include { NANOPLOT as NANOPLOT_RAW   } from './modules/local/nanoplot/main.nf'
include { FILTLONG                   } from './modules/local/filtlong/main.nf'
include { MINIMAP2_HOST_REMOVAL      } from './modules/local/minimap2_host_removal/main.nf'
include { NANOPLOT as NANOPLOT_CLEAN } from './modules/local/nanoplot/main.nf'
include { KRAKEN2 as KRAKEN2_RAW     } from './modules/local/kraken2/main.nf'
include { KRAKEN2 as KRAKEN2_CLEAN   } from './modules/local/kraken2/main.nf'
include { KRONA as KRONA_RAW         } from './modules/local/krona/main.nf'
include { KRONA as KRONA_CLEAN       } from './modules/local/krona/main.nf'
include { EVAL_HOST_SUMMARY          } from './modules/local/eval_host_summary/main.nf'
include { MULTIQC                    } from './modules/local/multiqc/main.nf'

workflow {

    log.info """
    =============================================================================
       🔬 Host Removal & Krona Evaluation Pipeline (EPI2ME Standard) 🔬
    =============================================================================
     Samplesheet        : ${params.input}
     Output Directory   : ${params.outdir}
     Host Genome        : ${params.host_genome}
     Kraken2 Database   : ${params.kraken2_db}
     Kraken2 Confidence : ${params.kraken2_confidence ?: '0.0 (default)'}
     Min Read Length    : ${params.min_length_long ?: 300} bp
     Min Read Quality   : Q${params.min_quality_long ?: 10}
    =============================================================================
    """.stripIndent()

    // ── 0. Validate required database parameters ──────────────────────────────
    if (!params.host_genome || params.host_genome == 'null') {
        error "ERROR: --host_genome path must be provided for host removal evaluation!"
    }
    if (!params.kraken2_db || params.kraken2_db == 'null') {
        error "ERROR: --kraken2_db path must be provided for Kraken2 profiling!"
    }

    ch_host_genome = file(params.host_genome)
    ch_kraken2_db  = file(params.kraken2_db)

    // ── 1. Read & Parse Samplesheet ───────────────────────────────────────────
    ch_reads = Channel
        .fromPath( params.input )
        .splitCsv( header: true )
        .map { row -> Samplesheet.parseRow(row) }
        .filter { row -> row.long_fastq || row.long_reads }
        .map { row ->
            def meta = [ id: row.sample, single_end: true, platform: 'nanopore' ]
            def fq = row.long_fastq ?: row.long_reads
            [ meta, file(fq) ]
        }

    // ── 2. Stage 1: Raw QC (NanoPlot on raw reads) ────────────────────────────
    ch_raw_prefixed = ch_reads.map { meta, reads ->
        [ meta + [ id: "${meta.id}_raw" ], reads ]
    }
    NANOPLOT_RAW( ch_raw_prefixed )

    // ── 3. Stage 2: Quality Filtering (Filtlong EPI2ME Standard) ──────────────
    FILTLONG( ch_reads )
    ch_filtered_reads = FILTLONG.out.reads

    // ── 4. Branch A: WITHOUT Host Removal (Filtered Reads with Host DNA) ──────
    ch_with_host = ch_filtered_reads.map { meta, reads ->
        [ meta + [ id: "${meta.id}_with_host" ], reads ]
    }
    KRAKEN2_RAW( ch_with_host, ch_kraken2_db )
    KRONA_RAW( KRAKEN2_RAW.out.report )

    // ── 5. Branch B: WITH Host Removal (Minimap2 against Host Reference) ──────
    MINIMAP2_HOST_REMOVAL( ch_filtered_reads, ch_host_genome )
    ch_clean_reads = MINIMAP2_HOST_REMOVAL.out.reads

    ch_clean_prefixed = ch_clean_reads.map { meta, reads ->
        [ meta + [ id: "${meta.id}_clean" ], reads ]
    }
    NANOPLOT_CLEAN( ch_clean_prefixed )
    KRAKEN2_CLEAN( ch_clean_prefixed, ch_kraken2_db )
    KRONA_CLEAN( KRAKEN2_CLEAN.out.report )

    // ── 6. Stage 3: Summary Comparison Table (Before vs After Host Removal) ───
    ch_all_flagstats = MINIMAP2_HOST_REMOVAL.out.stats.map { meta, s -> s }.collect()
    ch_all_raw_reps  = KRAKEN2_RAW.out.report.map { meta, r -> r }.collect()
    ch_all_clean_reps= KRAKEN2_CLEAN.out.report.map { meta, r -> r }.collect()

    EVAL_HOST_SUMMARY(
        ch_all_flagstats,
        ch_all_raw_reps,
        ch_all_clean_reps
    )

    // ── 7. Stage 4: MultiQC Consolidated Quality Report ───────────────────────
    ch_multiqc_files = Channel.empty()
        .mix( NANOPLOT_RAW.out.txt.map { meta, txt -> txt } )
        .mix( NANOPLOT_CLEAN.out.txt.map { meta, txt -> txt } )
        .mix( FILTLONG.out.log.map { meta, log -> log } )
        .mix( MINIMAP2_HOST_REMOVAL.out.stats.map { meta, s -> s } )
        .mix( MINIMAP2_HOST_REMOVAL.out.log.map { meta, log -> log } )
        .mix( KRAKEN2_RAW.out.report.map { meta, rep -> rep } )
        .mix( KRAKEN2_CLEAN.out.report.map { meta, rep -> rep } )

    MULTIQC( ch_multiqc_files.collect() )
}
