process BRACKEN {
    tag "$meta.id"
    label 'process_medium'

    container 'quay.io/biocontainers/bracken:3.0--h9948957_2'

    input:
    tuple val(meta), path(kraken_report)
    path  db

    output:
    tuple val(meta), path("*_bracken_report.txt"), emit: report
    tuple val(meta), path("*_bracken_species.tsv"), emit: species

    script:
    def prefix = task.ext.prefix ?: "${meta.id}"
    def read_len = params.bracken_read_len ?: 150
    def level = params.bracken_level ?: 'S'
    def threshold = params.bracken_threshold ?: 10
    """
    # Check if report has classified reads before running bracken
    classified_reads=\$(awk -F'\t' '\$4 == "U" {next} {sum += \$2} END {print sum+0}' ${kraken_report})

    if [ "\${classified_reads}" -gt 0 ]; then
        bracken \\
            -d ${db} \\
            -i ${kraken_report} \\
            -o ${prefix}_bracken_species.tsv \\
            -w ${prefix}_bracken_report.txt \\
            -r ${read_len} \\
            -l ${level} \\
            -t ${threshold} || true
    fi

    # Ensure output files exist even for empty/zero-read samples
    touch ${prefix}_bracken_species.tsv ${prefix}_bracken_report.txt
    """
}
