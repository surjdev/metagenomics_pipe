process NEXTPOLISH {
    tag "$meta.id"
    label 'process_high'
    container 'quay.io/biocontainers/nextpolish:1.4.1--h9ee0642_1'

    input:
    tuple val(meta), path(contigs), path(r1), path(r2)

    output:
    tuple val(meta), path("${meta.id}_polished.fasta"), emit: contigs

    script:
    """
    # Generate run configuration dynamically
    echo "read1 = $r1" > run.cfg
    echo "read2 = $r2" >> run.cfg
    echo "genome = $contigs" >> run.cfg
    echo "task = best" >> run.cfg
    echo "parallel_jobs = 1" >> run.cfg
    echo "multithread_jobs = $task.cpus" >> run.cfg
    
    nextPolish run.cfg
    mv input.genome.nextpolish.fasta ${meta.id}_polished.fasta
    """
}