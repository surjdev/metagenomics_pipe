#!/usr/bin/env nextflow
nextflow.enable.dsl = 2

include { SHORT_READ_QC              } from './subworkflows/local/short_read_qc'
include { LONG_READ_QC               } from './subworkflows/local/long_read_qc'
include { ASSEMBLY_FREE_PROFILING    } from './subworkflows/local/assembly_free_profiling'
include { ASSEMBLY_AND_ANNOTATION    } from './subworkflows/local/assembly_and_annotation'
include { BINNING                    } from './subworkflows/local/binning'
include { BIN_QC                     } from './subworkflows/local/bin_qc'
include { BIN_TAXONOMY_ANNOTATION    } from './subworkflows/local/bin_taxonomy_annotation'
include { RUN_SUMMARY                } from './subworkflows/local/run_summary'

workflow {
    ch_samplesheet = channel.fromPath(params.input).splitCsv(header: true).map { /* Parsing logic */ }

    // Section 1 + 2: independent QC arms
    SHORT_READ_QC(ch_samplesheet, params.host_bt2_index)
    LONG_READ_QC(ch_samplesheet, params.host_fasta)

    // Branch point: Assembly-free & Assembly routes
    ASSEMBLY_FREE_PROFILING(
        SHORT_READ_QC.out.reads, 
        LONG_READ_QC.out.reads,
        params.kraken2_db,
        params.bracken_db,
        params.metaphlan_db
    )
    
    ASSEMBLY_AND_ANNOTATION(
        SHORT_READ_QC.out.reads, 
        LONG_READ_QC.out.reads
    )

    // Sections 5, 6, 7 chain off the assembly arm only
    BINNING(
        ASSEMBLY_AND_ANNOTATION.out.contigs, 
        ASSEMBLY_AND_ANNOTATION.out.bam
    )
    
    BIN_QC(
        BINNING.out.refined_bins,
        params.gunc_db,
        params.checkm2_db,
        params.busco_lineage
    )
    
    BIN_TAXONOMY_ANNOTATION(
        BINNING.out.refined_bins, 
        params.gtdbtk_db,           // or your CAT db path depending on logic
        params.cat_taxonomy_db,     // Add this parameter to your config/params
        params.mmseqs_db,           // Add this parameter to your config/params
        params.eggnog_db
    )

    // Section 8: Synchronize QC logs before collection to prevent race conditions
    ch_synced_qc = SHORT_READ_QC.out.qc_zips
        .join(LONG_READ_QC.out.qc_zips, remainder: true)
        .map { _meta, short_qc, long_qc -> 
            def files = []
            if (short_qc) files << short_qc
            if (long_qc) files << long_qc
            return files
        }
        .flatten()

    RUN_SUMMARY(
        ch_synced_qc,
        ASSEMBLY_FREE_PROFILING.out.merged_table,
        BIN_QC.out.reports,
        BIN_TAXONOMY_ANNOTATION.out.reports
    )
}