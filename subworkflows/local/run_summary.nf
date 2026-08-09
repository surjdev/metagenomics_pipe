// Import required modules
include { MULTIQC          } from '../../modules/local/multiqc/main'
include { GENERATE_REPORTS } from '../../modules/local/generate_reports/main'

workflow RUN_SUMMARY {
    take:
    qc_logs        // Channel containing fastqc, nanoplot, quast logs, etc.
    profiling_out  // Channel containing taxonomy/functional tables
    bin_qc_out     // Channel containing DASTool/CheckM2/GTDB-Tk reports
    bin_annot_out  // Channel containing PROKKA/eggNOG reports

    main:
    // Station 1: Aggregate global QC metrics
    MULTIQC(qc_logs.collect())

    // Stations 2, 3, & 4: Process custom summaries and build the HTML layout
    GENERATE_REPORTS(
        profiling_out.collect(),
        bin_qc_out.collect(),
        bin_annot_out.collect()
    )

    emit:
    multiqc_html = MULTIQC.out.report
    final_report = GENERATE_REPORTS.out.html_report
}