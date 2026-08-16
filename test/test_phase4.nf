#!/usr/bin/env nextflow
/*
 * test/test_phase4.nf — Phase 4 integration test
 *
 * Tests:
 *   - Assembly-Free Read Profiling: KRAKEN2, BRACKEN, KRONA, KRAKEN_BIOM, HUMANN3
 *
 * Run with:
 *   nextflow run test/test_phase4.nf -profile docker,test --run_kraken2 true --kraken2_db test/data/tiny_databases/kraken2_db --run_krona true --run_kraken_biom true
 */

nextflow.enable.dsl = 2

include { assembly_free } from '../workflows/assembly_free.nf'

workflow {

    // ── 1. Load paired short reads ────────────────────────────────────────────
    ch_short = Channel
        .fromPath( params.input )
        .splitCsv( header: true )
        .map { row ->
            def meta = [ id: row.sample, single_end: false ]
            [ meta, [ file(row.fastq_1), file(row.fastq_2) ] ]
        }

    // ── 2. Run Assembly-Free Workflow ─────────────────────────────────────────
    assembly_free ( ch_short )

    // ── 3. Summary Logging ────────────────────────────────────────────────────
    assembly_free.out.kraken_report.view { meta, rep  -> "KRAKEN2 REPORT ✓  ${meta.id}: ${rep}" }
    assembly_free.out.krona_html.view    { meta, html -> "KRONA HTML     ✓  ${meta.id}: ${html}" }
    assembly_free.out.biom.view          { meta, biom -> "BIOM OUTPUT    ✓  ${meta.id}: ${biom}" }
}
