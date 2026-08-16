process CAT_BINS {
    tag "$meta.id"
    label 'process_medium'

    container 'community.wave.seqera.io/library/bowtie2_htslib_samtools_pigz:edeb13799090a2a6'

    input:
    tuple val(meta), path(bin_files)

    output:
    tuple val(meta), path("final_bins/*.fa"), emit: bins, optional: true
    tuple val(meta), path("final_bins"),      emit: dir
    tuple val(meta), path("bins_summary.tsv"), emit: summary

    script:
    def prefix = task.ext.prefix ?: "${meta.id}"
    """
    mkdir -p final_bins
    echo -e "sample\\tbin_id\\tnum_contigs\\ttotal_length_bp" > bins_summary.tsv

    bin_idx=1
    for f in ${bin_files}; do
        if [ -f "\$f" ] && [ -s "\$f" ]; then
            # Format target bin file name
            target="final_bins/${prefix}_bin_\${bin_idx}.fa"
            cp "\$f" "\$target"
            
            # Simple summary stats
            n_seqs=\$(grep -c "^>" "\$target" || echo 0)
            t_len=\$(grep -v "^>" "\$target" | tr -d '\\r\\n ' | wc -c || echo 0)
            echo -e "${prefix}\\t${prefix}_bin_\${bin_idx}\\t\${n_seqs}\\t\${t_len}" >> bins_summary.tsv
            
            bin_idx=\$((bin_idx + 1))
        fi
    done
    """
}
