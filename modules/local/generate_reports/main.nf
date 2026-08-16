process GENERATE_REPORTS {
    tag "$meta.id"
    label 'process_low'

    container 'quay.io/biocontainers/multiqc:1.35--pyhdfd78af_0'

    input:
    tuple val(meta), path(quast_tsv, stageAs: 'quast_in/*'), path(bins_summary, stageAs: 'bins_in/*'), path(kraken_report, stageAs: 'kraken_in/*')
    path  template_html
    path  template_md

    output:
    tuple val(meta), path("*_pipeline_report.html"), emit: html
    tuple val(meta), path("*_summary.md"),          emit: summary

    script:
    def prefix = task.ext.prefix ?: "${meta.id}"
    def script_path = file("${projectDir}/bin/generate_report.py").exists() ? "${projectDir}/bin/generate_report.py" : "${projectDir}/../bin/generate_report.py"
    """
    python3 ${script_path} \\
        --sample-id ${prefix} \\
        --quast-tsv ${quast_tsv} \\
        --bins-tsv ${bins_summary} \\
        --kraken-report ${kraken_report} \\
        --template-html ${template_html} \\
        --template-md ${template_md} \\
        --outdir .
    """
}
