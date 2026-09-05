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

    // ── Platform Routing & Input Channels ─────────────────────────────────────
    def plat = (params.platform ?: 'auto').toLowerCase()
    def include_short = (plat in ['auto', 'short', 'illumina', 'hybrid'])
    def include_long  = (plat in ['auto', 'long', 'nanopore', 'ont', 'hybrid'])

    ch_samplesheet = Channel
        .fromPath( params.input )
        .splitCsv( header: true )
        .map { row -> Samplesheet.parseRow(row) }

    ch_short_reads = include_short
        ? ch_samplesheet
            .filter { row -> row.fastq_1 && row.fastq_2 }
            .map { row ->
                def meta = [ id: row.sample, single_end: false, platform: 'illumina' ]
                [ meta, [ file(row.fastq_1), file(row.fastq_2) ] ]
            }
        : Channel.empty()

    ch_long_reads = include_long
        ? ch_samplesheet
            .filter { row -> row.long_fastq || row.long_reads }
            .map { row ->
                def meta = [ id: row.sample, single_end: true, platform: 'nanopore' ]
                def fq = row.long_fastq ?: row.long_reads
                [ meta, file(fq) ]
            }
        : Channel.empty()

    // ── 1. Quality Control & Preprocessing ────────────────────────────────────
    preprocessing( ch_short_reads, ch_long_reads )

    // ── 2. Host Removal (Optional) ────────────────────────────────────────────
    host_removal(
        preprocessing.out.short_reads,
        preprocessing.out.long_reads
    )

    ch_clean_short = host_removal.out.short_reads
    ch_clean_long  = host_removal.out.long_reads
    ch_qc_reports  = preprocessing.out.qc_reports

    // ── 3. Mode Dispatcher ────────────────────────────────────────────────────
    def mode = (params.mode ?: 'assembly_free').toLowerCase()

    if (mode in ['assembly_free', 'profile', 'abundance', 'taxonomic_profiling']) {
        // ── MODE A: Assembly-Free Taxonomic & Functional Abundance Profiling ──
        log.info "🔬 Running Pipeline in [ASSEMBLY_FREE] mode (Taxonomic abundance & Kraken2 profiling)"

        ch_profiling_reads = ch_clean_short.mix( ch_clean_long )
        assembly_free( ch_profiling_reads )

        reporting(
            ch_qc_reports,
            Channel.empty(),
            Channel.empty(),
            assembly_free.out.kraken_report
        )

    } else if (mode in ['assembly', 'mag', 'mag_recovery', 'full']) {
        // ── MODE B: De Novo Metagenome Assembly & MAG Recovery ────────────────
        log.info "🧬 Running Pipeline in [ASSEMBLY] mode (De novo contig assembly & MAG recovery)"

        assembly( ch_clean_short, ch_clean_long )

        ch_polishing_reads = (params.polisher == 'nextpolish') ? ch_clean_short : ch_clean_long
        polishing(
            assembly.out.contigs,
            ch_polishing_reads
        )

        assembly_qc( polishing.out.contigs )

        mapping(
            polishing.out.contigs,
            ch_clean_short,
            ch_clean_long
        )

        binning(
            polishing.out.contigs,
            mapping.out.bam,
            mapping.out.bai,
            mapping.out.depth
        )

        mag_qc( binning.out.bins_dir )

        annotation( polishing.out.contigs )

        ch_kraken_rep = Channel.empty()
        if (params.run_kraken2) {
            ch_profiling_reads = ch_clean_short.mix( ch_clean_long )
            assembly_free( ch_profiling_reads )
            ch_kraken_rep = assembly_free.out.kraken_report
        }

        ch_all_qc = ch_qc_reports.mix( assembly_qc.out.tsv.map { meta, rep -> rep } )
        reporting(
            ch_all_qc,
            assembly_qc.out.tsv,
            binning.out.summary,
            ch_kraken_rep
        )

    } else {
        error "Unknown pipeline mode: '${params.mode}'. Supported modes: 'assembly_free' (read-based profiling) or 'assembly' (de novo MAG recovery)."
    }
}
