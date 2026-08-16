process MULTIQC {
    label 'process_medium'

    container 'quay.io/biocontainers/multiqc:1.35--pyhdfd78af_0'

    input:
    path multiqc_files

    output:
    path "multiqc_report.html", emit: html
    path "multiqc_data",        emit: data, optional: true

    script:
    """
    multiqc . --force || true

    if [ ! -f multiqc_report.html ]; then
        echo "<html><body><h3>MultiQC Report</h3><p>No upstream tool logs detected.</p></body></html>" > multiqc_report.html
    fi
    mkdir -p multiqc_data
    """
}
