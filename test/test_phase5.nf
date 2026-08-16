#!/usr/bin/env nextflow
/*
 * test/test_phase5.nf — Phase 5 integration test
 *
 * Tests:
 *   - Functional Annotation: PROKKA, GENOMAD
 *   - Quality & Final Reporting: MULTIQC, GENERATE_REPORTS
 *
 * Run with:
 *   nextflow run test/test_phase5.nf -profile docker,test --run_prokka true --run_multiqc true --run_custom_report true
 */

nextflow.enable.dsl = 2

include { annotation } from '../workflows/annotation.nf'
include { reporting  } from '../workflows/reporting.nf'

workflow {

    // ── 1. Create synthetic contig channel ────────────────────────────────────
    ch_contigs = Channel.of(
        [
            [ id: 'SAMPLE001' ],
            file("${launchDir}/test/data/tiny_databases/host_ref.fasta")
        ]
    )

    // ── 2. Run Functional Annotation Workflow ─────────────────────────────────
    annotation( ch_contigs )

    // ── 3. Run Reporting Workflow ─────────────────────────────────────────────
    ch_quast = Channel.of(
        [
            [ id: 'SAMPLE001' ],
            file("${launchDir}/test/data/mock_reports/quast_report.tsv")
        ]
    )
    ch_bins = Channel.of(
        [
            [ id: 'SAMPLE001' ],
            file("${launchDir}/test/data/mock_reports/bins_summary.tsv")
        ]
    )
    ch_kraken = Channel.of(
        [
            [ id: 'SAMPLE001' ],
            file("${launchDir}/test/data/mock_reports/kraken2_report.txt")
        ]
    )

    ch_qc_files = Channel.fromPath("${launchDir}/test/data/mock_reports/fastqc_data.txt")

    reporting(
        ch_qc_files,
        ch_quast,
        ch_bins,
        ch_kraken
    )

    // ── 4. View results ───────────────────────────────────────────────────────
    annotation.out.gff.view         { meta, gff  -> "PROKKA GFF       ✓  ${meta.id}: ${gff}" }
    annotation.out.faa.view         { meta, faa  -> "PROKKA FAA       ✓  ${meta.id}: ${faa}" }
    reporting.out.multiqc_html.view { html       -> "MULTIQC REPORT   ✓  ${html}" }
    reporting.out.report_html.view  { meta, html -> "PIPELINE REPORT  ✓  ${meta.id}: ${html}" }
    reporting.out.summary_md.view   { meta, md   -> "PIPELINE SUMMARY ✓  ${meta.id}: ${md}" }
}
