#!/usr/bin/env nextflow
/*
 * =============================================================================
 * main_compare_assembly_free.nf — Short vs Long Metagenomics Comparison Pipeline
 * =============================================================================
 * Purpose:
 *   Performs assembly-free taxonomic and abundance profiling on paired:
 *   - Short Reads (Illumina paired-end)
 *   - Long Reads (Oxford Nanopore)
 *   And executes side-by-side comparative benchmarking:
 *   1. Classification rate & taxonomic yield
 *   2. Shared / Unique species and Jaccard similarity index
 *   3. Pearson & Spearman correlation on relative abundances
 *   4. Top differential taxa abundance matrix
 *   5. Interactive HTML dashboard, Markdown summary, TSV exports, and MultiQC.
 * =============================================================================
 */

nextflow.enable.dsl = 2

// ── Include Modules ───────────────────────────────────────────────────────────
include { FASTP                 } from './modules/local/fastp/main.nf'
include { FILTLONG              } from './modules/local/filtlong/main.nf'
include { BOWTIE2_HOST_REMOVAL  } from './modules/local/bowtie2_host_removal/main.nf'
include { MINIMAP2_HOST_REMOVAL } from './modules/local/minimap2_host_removal/main.nf'
include { KRAKEN2 as KRAKEN2_SHORT } from './modules/local/kraken2/main.nf'
include { KRAKEN2 as KRAKEN2_LONG  } from './modules/local/kraken2/main.nf'
include { BRACKEN as BRACKEN_SHORT } from './modules/local/bracken/main.nf'
include { KRONA as KRONA_SHORT     } from './modules/local/krona/main.nf'
include { KRONA as KRONA_LONG      } from './modules/local/krona/main.nf'
include { COMPARE_ASSEMBLY_FREE    } from './modules/local/compare_assembly_free/main.nf'
include { MULTIQC                  } from './modules/local/multiqc/main.nf'

workflow {

    log.info """
    =============================================================================
       🔬 Assembly-Free Comparison Pipeline: Short Reads vs Long Reads 🔬
    =============================================================================
     Samplesheet        : ${params.input}
     Output Directory   : ${params.outdir}
     Run Preprocessing  : ${params.run_preprocessing}
     Run Host Removal   : ${params.run_host_removal}
     Kraken2 Database   : ${params.kraken2_db}
     Kraken2 Confidence : ${params.kraken2_confidence ?: '0.0 (default)'}
     Run Bracken        : ${params.run_bracken}
     Run Krona          : ${params.run_krona}
    =============================================================================
    """.stripIndent()

    // ── 0. Sanity Checks ──────────────────────────────────────────────────────
    if (!params.kraken2_db || params.kraken2_db == 'null') {
        error "ERROR: --kraken2_db path must be specified for taxonomic classification!"
    }
    def run_host = (params.run_host_removal != false && params.run_host_removal != 'false')
    if (run_host && (!params.host_genome || params.host_genome == 'null')) {
        error "ERROR: --host_genome path must be specified when --run_host_removal is true!"
    }

    ch_kraken2_db = file(params.kraken2_db)
    ch_host_genome = run_host ? file(params.host_genome) : null

    // ── 1. Read & Parse Samplesheet ───────────────────────────────────────────
    ch_samplesheet = Channel
        .fromPath( params.input )
        .splitCsv( header: true )
        .map { row -> Samplesheet.parseRow(row) }

    ch_short_raw = ch_samplesheet
        .filter { row -> row.fastq_1 && row.fastq_2 }
        .map { row ->
            def meta = [ id: "${row.sample}_short", sample: row.sample, single_end: false, platform: 'illumina' ]
            [ meta, [ file(row.fastq_1), file(row.fastq_2) ] ]
        }

    ch_long_raw = ch_samplesheet
        .filter { row -> row.long_fastq || row.long_reads }
        .map { row ->
            def meta = [ id: "${row.sample}_long", sample: row.sample, single_end: true, platform: 'nanopore' ]
            def fq = row.long_fastq ?: row.long_reads
            [ meta, file(fq) ]
        }

    // ── 2. Stage 1: Optional Preprocessing ────────────────────────────────────
    def run_preproc = (params.run_preprocessing != false && params.run_preprocessing != 'false')
    ch_short_preproc = ch_short_raw
    ch_long_preproc  = ch_long_raw
    ch_qc_logs       = Channel.empty()

    if (run_preproc) {
        FASTP( ch_short_raw )
        ch_short_preproc = FASTP.out.reads
        ch_qc_logs = ch_qc_logs.mix( FASTP.out.json.map { meta, j -> j } )

        FILTLONG( ch_long_raw )
        ch_long_preproc = FILTLONG.out.reads
        ch_qc_logs = ch_qc_logs.mix( FILTLONG.out.log.map { meta, l -> l } )
    }

    // ── 3. Stage 2: Optional Host Removal ─────────────────────────────────────
    ch_short_clean = ch_short_preproc
    ch_long_clean  = ch_long_preproc

    if (run_host) {
        BOWTIE2_HOST_REMOVAL( ch_short_preproc, ch_host_genome )
        ch_short_clean = BOWTIE2_HOST_REMOVAL.out.reads
        ch_qc_logs = ch_qc_logs
            .mix( BOWTIE2_HOST_REMOVAL.out.stats.map { meta, s -> s } )
            .mix( BOWTIE2_HOST_REMOVAL.out.log.map { meta, l -> l } )

        MINIMAP2_HOST_REMOVAL( ch_long_preproc, ch_host_genome )
        ch_long_clean = MINIMAP2_HOST_REMOVAL.out.reads
        ch_qc_logs = ch_qc_logs
            .mix( MINIMAP2_HOST_REMOVAL.out.stats.map { meta, s -> s } )
            .mix( MINIMAP2_HOST_REMOVAL.out.log.map { meta, l -> l } )
    }

    // ── 4. Stage 3: Dual-Branch Assembly-Free Profiling ───────────────────────
    // Branch A: Short Reads (Illumina)
    KRAKEN2_SHORT( ch_short_clean, ch_kraken2_db )
    ch_short_k2_reports = KRAKEN2_SHORT.out.report
    ch_qc_logs = ch_qc_logs.mix( ch_short_k2_reports.map { meta, r -> r } )

    ch_short_bracken_reports = Channel.value([])
    if (params.run_bracken in [true, 'true']) {
        BRACKEN_SHORT( KRAKEN2_SHORT.out.report, ch_kraken2_db )
        ch_short_bracken_reports = BRACKEN_SHORT.out.report.map { meta, r -> r }.collect().ifEmpty([])
    }

    if (params.run_krona in [true, 'true']) {
        KRONA_SHORT( KRAKEN2_SHORT.out.report )
    }

    // Branch B: Long Reads (Oxford Nanopore)
    KRAKEN2_LONG( ch_long_clean, ch_kraken2_db )
    ch_long_k2_reports = KRAKEN2_LONG.out.report
    ch_qc_logs = ch_qc_logs.mix( ch_long_k2_reports.map { meta, r -> r } )

    if (params.run_krona in [true, 'true']) {
        KRONA_LONG( KRAKEN2_LONG.out.report )
    }

    // ── 5. Stage 4: Comparative Benchmarking Analysis ─────────────────────────
    ch_all_short_reps = ch_short_k2_reports.map { meta, r -> r }.collect()
    ch_all_long_reps  = ch_long_k2_reports.map { meta, r -> r }.collect()

    COMPARE_ASSEMBLY_FREE(
        ch_all_short_reps,
        ch_all_long_reps,
        ch_short_bracken_reports
    )

    // ── 6. Stage 5: MultiQC Consolidation ─────────────────────────────────────
    if (params.run_multiqc in [true, 'true']) {
        MULTIQC( ch_qc_logs.collect() )
    }
}
