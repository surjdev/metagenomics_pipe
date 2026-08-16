process KRAKEN_BIOM {
    tag "$meta.id"
    label 'process_low'

    container 'quay.io/biocontainers/kraken-biom:1.2.0--pyh5e36f6f_0'

    input:
    tuple val(meta), path(kraken_reports)

    output:
    tuple val(meta), path("*.biom"), emit: biom
    tuple val(meta), path("*.tsv"),  emit: tsv, optional: true

    script:
    def prefix = task.ext.prefix ?: "${meta.id}"
    """
    if command -v kraken-biom >/dev/null 2>&1; then
        kraken-biom ${kraken_reports} --output_fp ${prefix}_taxonomy.biom --fmt json
    else
        kraken_to_biom.py ${kraken_reports} -o ${prefix}_taxonomy.biom -t ${prefix}_taxonomy.tsv
    fi
    """
}
