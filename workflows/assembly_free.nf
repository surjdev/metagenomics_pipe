/*
 * workflows/assembly_free.nf — Read-Based Profiling Workflow
 * Executes Kraken2, Bracken, Krona, BIOM conversion, and HUMAnN3 functional analysis.
 */

include { KRAKEN2     } from '../modules/local/kraken2/main.nf'
include { BRACKEN     } from '../modules/local/bracken/main.nf'
include { KRONA       } from '../modules/local/krona/main.nf'
include { KRAKEN_BIOM } from '../modules/local/kraken_biom/main.nf'
include { HUMANN3     } from '../modules/local/humann3/main.nf'

workflow assembly_free {
    take:
    ch_reads  // channel: [ meta, reads ]

    main:
    ch_kraken_report       = Channel.empty()
    ch_bracken_report      = Channel.empty()
    ch_krona_html          = Channel.empty()
    ch_biom                = Channel.empty()
    ch_humann_genefamilies = Channel.empty()
    ch_humann_pathabundance= Channel.empty()

    // ── 1. Kraken2 Taxonomic Classification ───────────────────────────────────
    def run_kraken      = (params.run_kraken2 != false && params.run_kraken2 != 'false')
    def has_kraken_db   = (params.kraken2_db && params.kraken2_db != 'null')
    def run_bracken     = (params.run_bracken == true || params.run_bracken == 'true')
    def run_krona       = (params.run_krona != false && params.run_krona != 'false')
    def run_kraken_biom = (params.run_kraken_biom != false && params.run_kraken_biom != 'false')
    def run_humann3     = (params.run_humann3 == true || params.run_humann3 == 'true')

    if (run_kraken && has_kraken_db) {
        KRAKEN2( ch_reads, file(params.kraken2_db) )
        ch_kraken_report = KRAKEN2.out.report

        // ── 2. Bracken Abundance Estimation (Optional, typically for Illumina) ──
        if (run_bracken) {
            BRACKEN( KRAKEN2.out.report, file(params.kraken2_db) )
            ch_bracken_report = BRACKEN.out.report
        }

        // ── 3. Krona Visualization ────────────────────────────────────────────
        if (run_krona) {
            KRONA( KRAKEN2.out.report )
            ch_krona_html = KRONA.out.html
        }

        // ── 4. BIOM Conversion ────────────────────────────────────────────────
        if (run_kraken_biom) {
            KRAKEN_BIOM( KRAKEN2.out.report )
            ch_biom = KRAKEN_BIOM.out.biom
        }
    }

    // ── 5. HUMAnN3 Functional Profiling ───────────────────────────────────────
    if (params.run_humann3 && params.humann3_nucleotide_db && params.humann3_protein_db) {
        HUMANN3(
            ch_reads,
            file(params.humann3_nucleotide_db),
            file(params.humann3_protein_db)
        )
        ch_humann_genefamilies  = HUMANN3.out.genefamilies
        ch_humann_pathabundance = HUMANN3.out.pathabundance
    }

    emit:
    kraken_report       = ch_kraken_report
    bracken_report      = ch_bracken_report
    krona_html          = ch_krona_html
    biom                = ch_biom
    humann_genefamilies = ch_humann_genefamilies
    humann_pathabundance= ch_humann_pathabundance
}
