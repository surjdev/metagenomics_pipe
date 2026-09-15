process COMPARE_ASSEMBLY_FREE {
    tag "comparison"
    label 'process_low'

    container 'community.wave.seqera.io/library/python:3.11--a05ce51283e30f14'

    input:
    path short_reports
    path long_reports
    path short_bracken

    output:
    path "*_summary.tsv",  emit: summary_tsv
    path "*_species.tsv",  emit: species_tsv
    path "*_genus.tsv",    emit: genus_tsv
    path "*_top_taxa.tsv", emit: top_taxa_tsv
    path "*.md",           emit: md
    path "*.html",         emit: html

    script:
    def bracken_arg = short_bracken ? "--short-bracken ${short_bracken}" : ""
    """
    python3 ${projectDir}/bin/compare_assembly_free.py \\
        --short-reports ${short_reports} \\
        --long-reports ${long_reports} \\
        ${bracken_arg} \\
        -o assembly_free_comparison
    """
}
