process CONCOCT {
    tag "$meta.id"
    label 'process_high'

    container 'quay.io/biocontainers/concoct:1.1.0--py311hdfb91c2_8'

    input:
    tuple val(meta), path(contigs), path(bam), path(bai)

    output:
    tuple val(meta), path("concoct_bins/*.fa"), emit: bins, optional: true
    tuple val(meta), path("concoct_bins"),      emit: dir
    tuple val(meta), path("*.concoct.tsv"),     emit: scaffolds2bin, optional: true

    script:
    def prefix = task.ext.prefix ?: "${meta.id}"
    def min_len = params.min_contig_len_binning ?: 1000
    """
    mkdir -p concoct_out concoct_bins

    cut_up_fasta.py ${contigs} -c 10000 -o 0 --merge_last -b contigs_10k.bed > contigs_10k.fa
    concoct_coverage_table.py contigs_10k.bed ${bam} > coverage_table.tsv

    concoct \\
        --composition_file contigs_10k.fa \\
        --coverage_file coverage_table.tsv \\
        -b concoct_out/ \\
        -t $task.cpus \\
        -l ${min_len} || true

    if [ -f concoct_out/clustering_gt${min_len}.csv ]; then
        merge_cut_up_clustering.py concoct_out/clustering_gt${min_len}.csv > concoct_out/clustering_merged.csv
        extract_fasta_bins.py ${contigs} concoct_out/clustering_merged.csv --output_path concoct_bins || true
    elif [ -f concoct_out/clustering_gt1000.csv ]; then
        merge_cut_up_clustering.py concoct_out/clustering_gt1000.csv > concoct_out/clustering_merged.csv
        extract_fasta_bins.py ${contigs} concoct_out/clustering_merged.csv --output_path concoct_bins || true
    fi

    touch ${prefix}.concoct.tsv
    for bin_file in concoct_bins/*.fa; do
        if [ -f "\$bin_file" ]; then
            bname=\$(basename "\$bin_file" .fa)
            grep "^>" "\$bin_file" | sed 's/^>//' | awk -v b="\$bname" '{print \$1"\t"b}' >> ${prefix}.concoct.tsv
        fi
    done
    """
}
