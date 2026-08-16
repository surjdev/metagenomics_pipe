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
    # Extract taxid and read count from kraken2 report (cols 5 and 3)
    awk -F'\t' '{ if (\$3 > 0) print \$5"\t"\$3 }' ${kraken_report} > krona_input.txt

    if [ -s krona_input.txt ]; then
        ktImportTaxonomy -q 2 -t 1 krona_input.txt -o ${prefix}.krona.html || ktImportText krona_input.txt -o ${prefix}.krona.html
    else
        echo "<html><body><h3>No classified taxa found</h3></body></html>" > ${prefix}.krona.html
    fi
    """
}
