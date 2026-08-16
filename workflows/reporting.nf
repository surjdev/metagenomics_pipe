/*
 * workflows/reporting.nf — Quality Aggregation & Final Reporting Workflow
 * Aggregates QC files via MultiQC and generates consolidated HTML/Markdown pipeline reports.
 */

include { MULTIQC          } from '../modules/local/multiqc/main.nf'
include { GENERATE_REPORTS } from '../modules/local/generate_reports/main.nf'

workflow reporting {
    take:
    ch_multiqc_files  // channel: path(files)
    ch_quast_tsv      // channel: [ meta, tsv ]
    ch_bins_summary   // channel: [ meta, tsv ]
    ch_kraken_report  // channel: [ meta, report ]

    main:
    ch_multiqc_html = Channel.empty()
    ch_report_html  = Channel.empty()
    ch_summary_md   = Channel.empty()

    // ── 1. MultiQC Aggregation ────────────────────────────────────────────────
    if (params.run_multiqc) {
        ch_flat_files = ch_multiqc_files
            .map { item -> (item instanceof List) ? item.last() : item }
            .flatten()
        MULTIQC( ch_flat_files.collect() )
        ch_multiqc_html = MULTIQC.out.html
    }

    // ── 2. Custom Pipeline HTML & Markdown Report Generation ──────────────────
    if (params.run_custom_report) {
        ch_quast_keyed  = ch_quast_tsv.map { meta, quast -> [ meta.id, meta, quast ] }
        ch_bins_keyed   = ch_bins_summary.map { meta, bins -> [ meta.id, meta, bins ] }
        ch_kraken_keyed = ch_kraken_report.map { meta, rep -> [ meta.id, meta, rep ] }

        ch_all_samples = ch_quast_keyed
            .mix( ch_bins_keyed )
            .mix( ch_kraken_keyed )
            .map { id, meta, f -> [ id, meta ] }
            .unique { it[0] }

        ch_report_in = ch_all_samples
            .join( ch_quast_tsv.map { meta, q -> [ meta.id, q ] }, remainder: true )
            .join( ch_bins_summary.map { meta, b -> [ meta.id, b ] }, remainder: true )
            .join( ch_kraken_report.map { meta, k -> [ meta.id, k ] }, remainder: true )
            .map { list ->
                def flat = [list].flatten()
                def id     = flat[0]
                def meta   = (flat.size() > 1 && flat[1] instanceof Map) ? flat[1] : [ id: id, single_end: false, platform: 'metagenomics' ]
                def q_file = flat.size() > 2 && flat[2] ? flat[2] : file('EMPTY_QUAST')
                def b_file = flat.size() > 3 && flat[3] ? flat[3] : file('EMPTY_BINS')
                def k_file = flat.size() > 4 && flat[4] ? flat[4] : file('EMPTY_KRAKEN')
                [ meta, q_file, b_file, k_file ]
            }

        template_html = file("${params.template_html ?: "${projectDir}/templates/report.html"}")
        template_md   = file("${params.template_md ?: "${projectDir}/templates/summary.md"}")

        GENERATE_REPORTS(
            ch_report_in,
            template_html,
            template_md
        )

        ch_report_html = GENERATE_REPORTS.out.html
        ch_summary_md  = GENERATE_REPORTS.out.summary
    }

    emit:
    multiqc_html = ch_multiqc_html
    report_html  = ch_report_html
    summary_md   = ch_summary_md
}
