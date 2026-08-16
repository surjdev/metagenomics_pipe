process DASTOOL {
    tag "$meta.id"
    label 'process_high'

    container 'quay.io/biocontainers/das_tool:1.1.7--r44hdfd78af_1'

    input:
    tuple val(meta), path(contigs), path(tsvs)

    output:
    tuple val(meta), path("dastool_bins/*.fa"), emit: bins, optional: true
    tuple val(meta), path("dastool_bins"),      emit: dir
    tuple val(meta), path("dastool_out/*_DASTool_summary.tsv"), emit: summary, optional: true

    script:
    def prefix = task.ext.prefix ?: "${meta.id}"
    def score_threshold = params.dastool_threshold ?: 0.5
    """
    mkdir -p dastool_out dastool_bins

    # Collect non-empty TSV files and generate corresponding labels
    VALID_TSVS=""
    LABELS=""
    for tsv in ${tsvs}; do
        if [ -s "\$tsv" ]; then
            lbl=\$(basename "\$tsv" | sed 's/${prefix}.//' | sed 's/.tsv//')
            if [ -z "\$VALID_TSVS" ]; then
                VALID_TSVS="\$tsv"
                LABELS="\$lbl"
            else
                VALID_TSVS="\$VALID_TSVS,\$tsv"
                LABELS="\$LABELS,\$lbl"
            fi
        fi
    done

    if [ -n "\$VALID_TSVS" ]; then
        DAS_Tool \\
            -i "\$VALID_TSVS" \\
            -l "\$LABELS" \\
            -c ${contigs} \\
            -o dastool_out/${prefix} \\
            -t $task.cpus \\
            --write_bins \\
            --score_threshold ${score_threshold} || true

        if [ -d dastool_out/${prefix}_DASTool_bins ]; then
            cp dastool_out/${prefix}_DASTool_bins/*.fa dastool_bins/ 2>/dev/null || true
        fi
    fi
    """
}
