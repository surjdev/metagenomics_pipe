#!/usr/bin/env nextflow
nextflow.enable.dsl = 2

include { SHORT_READ_QC              } from './subworkflows/local/short_read_qc'
include { LONG_READ_QC                } from './subworkflows/local/long_read_qc'
include { ASSEMBLY_FREE_PROFILING     } from './subworkflows/local/assembly_free_profiling'
include { ASSEMBLY_AND_ANNOTATION     } from './subworkflows/local/assembly_and_annotation'
include { BINNING                     } from './subworkflows/local/binning'
include { BIN_QC                      } from './subworkflows/local/bin_qc'
include { BIN_TAXONOMY_ANNOTATION     } from './subworkflows/local/bin_taxonomy_annotation'
include { RUN_SUMMARY                 } from './subworkflows/local/run_summary'

workflow {

    if (!params.input) {
        error "Please provide a samplesheet with --input <path/to/samplesheet.csv>"
    }

    // -----------------------------------------------------------------
    // Samplesheet -> per-row channel.
    //
    // NOTE: this is a Phase-0-scoped parser, just enough to get real
    // channels flowing instead of the `.map{...}` placeholder. Column
    // validation, a proper JSON schema (assets/samplesheet_schema.json),
    // and confirming `meta` stays IDENTICAL across the short/long arms
    // for the same sample are Phase 1 work -- see the roadmap.
    //
    // Expected columns: sample, fastq_1, fastq_2, long_reads, long_input_type
    // (fastq_1/fastq_2 and long_reads are each optional -- a sample can be
    // short-only, long-only, or both/hybrid)
    // -----------------------------------------------------------------
    ch_samplesheet = channel
        .fromPath(params.input)
        .splitCsv(header: true)
        .map { row ->
            def meta = [
                id         : row.sample,
                single_end : false,
                input_type : (row.long_input_type ?: 'fastq')   // 'fastq' | 'fast5' | 'pod5'
            ]
            [ meta, row ]
        }

    ch_short_reads = ch_samplesheet
        .filter { meta, row -> row.fastq_1 && row.fastq_2 }
        .map    { meta, row -> [ meta, file(row.fastq_1), file(row.fastq_2) ] }

    ch_long_reads = ch_samplesheet
        .filter { meta, row -> row.long_reads }
        .map    { meta, row -> [ meta, file(row.long_reads) ] }

    // Section 1 + 2: independent QC arms
    SHORT_READ_QC(ch_short_reads, params.host_bt2_index)
    LONG_READ_QC(ch_long_reads, params.host_fasta)

    // Branch point: both arms feed Section 3 (assembly-free), and separately Section 4 (assembly)
    ASSEMBLY_FREE_PROFILING(
        SHORT_READ_QC.out.reads,
        LONG_READ_QC.out.reads,
        params.kraken2_db,
        params.bracken_db,
        params.metaphlan_db
    )
    ASSEMBLY_AND_ANNOTATION(SHORT_READ_QC.out.reads, LONG_READ_QC.out.reads)

    // Sections 5, 6, 7 chain off the assembly arm only
    BINNING(ASSEMBLY_AND_ANNOTATION.out.contigs, ASSEMBLY_AND_ANNOTATION.out.bam)

    BIN_QC(
        BINNING.out.refined_bins,
        params.gunc_db,
        params.checkm2_db,
        params.busco_lineage
    )
    BIN_TAXONOMY_ANNOTATION(
        BINNING.out.refined_bins,
        params.gtdbtk_db,
        params.eggnog_db
    )

    // Section 8: both arms converge
    RUN_SUMMARY(
        SHORT_READ_QC.out.qc_zips.mix(LONG_READ_QC.out.qc_zips),
        ASSEMBLY_FREE_PROFILING.out.merged_table,
        BIN_QC.out.reports,
        BIN_TAXONOMY_ANNOTATION.out.reports
    )
}