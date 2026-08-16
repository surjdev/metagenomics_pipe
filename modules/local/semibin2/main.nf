process SEMIBIN2 {
    tag "$meta.id"
    label 'process_high'

    container 'quay.io/biocontainers/semibin:2.4.1--pyhdfd78af_0'

    input:
    tuple val(meta), path(contigs), path(bam)

    output:
    tuple val(meta), path("semibin2_bins/output_bins/*.fa"), emit: bins, optional: true
    tuple val(meta), path("semibin2_bins"),                 emit: dir
    tuple val(meta), path("*.semibin2.tsv"),                emit: scaffolds2bin, optional: true

    script:
    def prefix = task.ext.prefix ?: "${meta.id}"
    def env = params.semibin_environment ?: 'global'
    def min_len = params.min_contig_len_binning ?: 1500
    """
    mkdir -p semibin2_bins/output_bins

    SemiBin2 single_easy_bin \\
        -i ${contigs} \\
        -b ${bam} \\
        -o semibin2_bins \\
        -t $task.cpus \\
        --environment ${env} \\
        --min-len ${min_len} || true

    touch ${prefix}.semibin2.tsv
    for bin_file in semibin2_bins/output_bins/*.fa; do
        if [ -f "\$bin_file" ]; then
            bname=\$(basename "\$bin_file" .fa)
            grep "^>" "\$bin_file" | sed 's/^>//' | awk -v b="\$bname" '{print \$1"\t"b}' >> ${prefix}.semibin2.tsv
        fi
    done
    """
}
