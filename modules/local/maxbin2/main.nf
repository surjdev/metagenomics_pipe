process MAXBIN2 {
    tag "$meta.id"
    label 'process_high'

    container 'quay.io/biocontainers/maxbin2:2.2.7--h503566f_8'

    input:
    tuple val(meta), path(contigs), path(abund)

    output:
    tuple val(meta), path("maxbin2_bins/*.fasta"), emit: bins, optional: true
    tuple val(meta), path("maxbin2_bins"),         emit: dir
    tuple val(meta), path("*.maxbin2.tsv"),        emit: scaffolds2bin, optional: true

    script:
    def prefix = task.ext.prefix ?: "${meta.id}"
    def min_len = params.min_contig_len_binning ?: 1500
    """
    mkdir -p maxbin2_bins

    # Extract 2-column abundance file (contig_name, depth) from metabat depth file if needed
    awk '{print \$1"\t"\$3}' ${abund} > maxbin_abund.txt

    run_MaxBin.pl \\
        -contig ${contigs} \\
        -abund maxbin_abund.txt \\
        -out maxbin2_bins/${prefix}_maxbin \\
        -thread $task.cpus \\
        -min_contig_length ${min_len} || true

    touch ${prefix}.maxbin2.tsv
    for bin_file in maxbin2_bins/*.fasta; do
        if [ -f "\$bin_file" ]; then
            bname=\$(basename "\$bin_file" .fasta)
            grep "^>" "\$bin_file" | sed 's/^>//' | awk -v b="\$bname" '{print \$1"\t"b}' >> ${prefix}.maxbin2.tsv
        fi
    done
    """
}
