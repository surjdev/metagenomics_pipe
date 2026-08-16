process HUMANN3 {
    tag "$meta.id"
    label 'process_high'

    container 'quay.io/biocontainers/humann:3.8--pyh7cba7a3_0'

    input:
    tuple val(meta), path(reads)
    path  nucleotide_db
    path  protein_db

    output:
    tuple val(meta), path("*_genefamilies.tsv"), emit: genefamilies
    tuple val(meta), path("*_pathcoverage.tsv"),  emit: pathcoverage
    tuple val(meta), path("*_pathabundance.tsv"), emit: pathabundance
    tuple val(meta), path("humann3_out"),         emit: dir

    script:
    def prefix = task.ext.prefix ?: "${meta.id}"
    """
    mkdir -p humann3_out

    if [ "${meta.single_end}" = "false" ]; then
        cat ${reads[0]} ${reads[1]} > input_merged.fastq.gz
        input_file="input_merged.fastq.gz"
    else
        input_file="${reads}"
    fi

    humann \\
        --input \${input_file} \\
        --output humann3_out \\
        --threads $task.cpus \\
        --nucleotide-database ${nucleotide_db} \\
        --protein-database ${protein_db} \\
        --output-basename ${prefix} || true

    cp humann3_out/${prefix}_genefamilies.tsv . 2>/dev/null || touch ${prefix}_genefamilies.tsv
    cp humann3_out/${prefix}_pathcoverage.tsv . 2>/dev/null || touch ${prefix}_pathcoverage.tsv
    cp humann3_out/${prefix}_pathabundance.tsv . 2>/dev/null || touch ${prefix}_pathabundance.tsv
    """
}
