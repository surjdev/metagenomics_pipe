process METABAT2 {
    tag "$meta.id"
    label 'process_high'

    container 'quay.io/biocontainers/metabat2:2.18--h38e344b_2'

    input:
    tuple val(meta), path(contigs), path(depth)

    output:
    tuple val(meta), path("metabat2_bins/*.fa"), emit: bins, optional: true
    tuple val(meta), path("metabat2_bins"),      emit: dir
    tuple val(meta), path("*.metabat2.tsv"),     emit: scaffolds2bin, optional: true

    script:
    def prefix = task.ext.prefix ?: "${meta.id}"
    def min_len = Math.max(1500, (params.min_contig_len_binning ?: 1500) as int)
    """
    mkdir -p metabat2_bins

    metabat2 \\
        -i ${contigs} \\
        -a ${depth} \\
        -o metabat2_bins/${prefix}_bin \\
        -m ${min_len} \\
        -t $task.cpus \\
        --saveCls \\
        --unbinned || true

    touch ${prefix}.metabat2.tsv
    for bin_file in metabat2_bins/${prefix}_bin.*.fa; do
        if [ -f "\$bin_file" ]; then
            bname=\$(basename "\$bin_file" .fa)
            grep "^>" "\$bin_file" | sed 's/^>//' | awk -v b="\$bname" '{print \$1"\t"b}' >> ${prefix}.metabat2.tsv
        fi
    done
    """
}
