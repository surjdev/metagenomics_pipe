process EVAL_HOST_SUMMARY {
    tag "summary"
    label 'process_low'

    container 'community.wave.seqera.io/library/python:3.11--a05ce51283e30f14'

    input:
    path flagstats
    path raw_reports
    path clean_reports

    output:
    path "host_removal_comparison.tsv", emit: tsv
    path "host_removal_comparison.md",  emit: md

    script:
    """
    python3 ${projectDir}/bin/eval_host_summary.py \\
        --flagstats ${flagstats} \\
        --raw-reports ${raw_reports} \\
        --clean-reports ${clean_reports} \\
        -o host_removal_comparison
    """
}
