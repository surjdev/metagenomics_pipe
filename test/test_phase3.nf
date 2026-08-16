#!/usr/bin/env nextflow
/*
 * test/test_phase3.nf — Phase 3 integration test
 *
 * Tests:
 *   - Mapping workflow: MAP_SHORT_READS, MAP_LONG_READS, ALIGN_READS_TO_CONTIGS
 *   - Binning workflow: METABAT2, MAXBIN2, SEMIBIN2, CONCOCT, DASTOOL, CAT_BINS
 *   - MAG QC workflow: CHECKM2, GUNC, GTDBTK (tested with flags/stubs if db omitted)
 *
 * Run with:
 *   nextflow run test/test_phase3.nf -profile docker,test
 */

nextflow.enable.dsl = 2

include { MEGAHIT } from '../modules/local/megahit/main.nf'
include { mapping } from '../workflows/mapping.nf'
include { binning } from '../workflows/binning.nf'
include { mag_qc  } from '../workflows/mag_qc.nf'

workflow {

    // ── 1. Load short reads ──────────────────────────────────────────────────
    ch_short = Channel
        .fromPath( params.input )
        .splitCsv( header: true )
        .map { row ->
            def meta = [ id: row.sample, single_end: false ]
            [ meta, [ file(row.fastq_1), file(row.fastq_2) ] ]
        }

    // ── 2. Load long reads ───────────────────────────────────────────────────
    ch_long = Channel
        .fromPath( params.input )
        .splitCsv( header: true )
        .map { row ->
            def meta = [ id: row.sample, single_end: true ]
            [ meta, file(row.long_reads) ]
        }

    // ── 3. Assemble contigs with MEGAHIT ──────────────────────────────────────
    MEGAHIT ( ch_short )

    // ── 4. Mapping Workflow ───────────────────────────────────────────────────
    mapping (
        MEGAHIT.out.contigs,
        ch_short,
        ch_long
    )

    // ── 5. Binning Workflow ───────────────────────────────────────────────────
    binning (
        MEGAHIT.out.contigs,
        mapping.out.bam,
        mapping.out.bai,
        mapping.out.depth
    )

    // ── 6. MAG QC Workflow ────────────────────────────────────────────────────
    mag_qc (
        binning.out.bins_dir
    )

    // ── Summary logging ───────────────────────────────────────────────────────
    MEGAHIT.out.contigs.view { meta, fa      -> "ASSEMBLY       ✓  ${meta.id}: ${fa}" }
    mapping.out.bam.view     { meta, bam     -> "MAPPING (BAM)  ✓  ${meta.id}: ${bam}" }
    mapping.out.depth.view   { meta, depth   -> "DEPTH TABLE    ✓  ${meta.id}: ${depth}" }
    binning.out.bins_dir.view{ meta, dir     -> "BINS DIR       ✓  ${meta.id}: ${dir}" }
    binning.out.summary.view { meta, summary -> "BINS SUMMARY   ✓  ${meta.id}: ${summary}" }
}
