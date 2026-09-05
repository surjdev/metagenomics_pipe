process KRONA {
    tag "$meta.id"
    label 'process_low'

    container 'quay.io/biocontainers/krona:2.7.1--pl526_0'

    input:
    tuple val(meta), path(kraken_report)

    output:
    tuple val(meta), path("*.krona.html"), emit: html

    script:
    def prefix = task.ext.prefix ?: "${meta.id}"
    """
    # Convert Kraken2 report into hierarchical text format with scientific names
    python3 ${projectDir}/bin/kreport_to_krona.py ${kraken_report} krona_input.txt

    if [ -s krona_input.txt ]; then
        ktImportText krona_input.txt -o ${prefix}.krona.html
    else
        echo "<html><body><h3>No classified taxa found</h3></body></html>" > ${prefix}.krona.html
    fi
    """
}
