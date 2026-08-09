process KRAKEN_BIOM {
    label 'process_low'
    container 'quay.io/biocontainers/kraken-biom:1.2.0--pyh5e36f6f_0'

    input:
    path(kraken_reports)

    output:
    path "merged_taxonomy.biom", emit: biom

    script:
    """
    kraken-biom $kraken_reports --fmt biom -o merged_taxonomy.biom
    """
}