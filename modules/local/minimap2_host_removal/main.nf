process MINIMAP2_HOST_REMOVAL {
    tag "$meta.id"
    label 'process_high'

    // Image bundles minimap2 + samtools
    container 'community.wave.seqera.io/library/minimap2_samtools:b09096fc890429ce'

    input:
    tuple val(meta), path(reads)
    path  reference

    output:
    tuple val(meta), path("*_nonhost.fastq.gz"), emit: reads
    tuple val(meta), path("*.flagstat"),          emit: stats
    tuple val(meta), path("*.minimap2.log"),       emit: log

    script:
    def prefix = task.ext.prefix ?: "${meta.id}"
    """
    # 1. Check if input reads file is empty (e.g. 0 reads passed filtlong)
    READS_COUNT=\$(zcat "${reads}" 2>/dev/null | head -n 4 | wc -l)
    if [ "\${READS_COUNT}" -eq 0 ]; then
        echo "[WARN] No reads found in ${reads}. Generating empty non-host output." >&2
        touch dummy.fastq
        gzip -c dummy.fastq > ${prefix}_nonhost.fastq.gz
        rm -f dummy.fastq
        touch ${prefix}_minimap2.flagstat ${prefix}.minimap2.log
    else
        # 2. Map long reads to host reference (supports .fa / .fasta / .mmi)
        # Note: -I 1G and --split-prefix are used for raw FASTA to split human genome indexing
        # into 1GB chunks, reducing peak RAM from ~14GB down to ~3.5GB to avoid OOM killer.
        split_opt=""
        if [[ "${reference}" != *.mmi ]]; then
            split_opt="-I 1G --split-prefix ${prefix}_tmp"
        fi

        minimap2 \\
            -ax map-ont \\
            \${split_opt} \\
            -t $task.cpus \\
            ${reference} \\
            ${reads} \\
            2> ${prefix}.minimap2.log \\
            | samtools view -b -@ $task.cpus -o ${prefix}.host.bam - \\
            || {
                echo "[ERROR] minimap2 mapping failed. Log content from ${prefix}.minimap2.log:" >&2
                cat ${prefix}.minimap2.log >&2
                exit 1
            }

        rm -f ${prefix}_tmp.*.tmp

        samtools flagstat \\
            --threads $task.cpus \\
            ${prefix}.host.bam \\
            > ${prefix}_minimap2.flagstat

        # 3. Extract unmapped reads (flag 4 = read unmapped)
        samtools view -f 4 -b ${prefix}.host.bam \\
            | samtools fastq - \\
            | gzip -c > ${prefix}_nonhost.fastq.gz

        rm -f ${prefix}.host.bam
    fi
    """
}
