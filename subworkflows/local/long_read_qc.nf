include { DORADO_BASECALL          } from '../../modules/local/dorado_basecall/main'
include { NANOPLOT as NANOPLOT_RAW } from '../../modules/local/nanoplot/main'
include { PORECHOP_ABI             } from '../../modules/local/porechop_abi/main'
include { MINIMAP2_HOST_REMOVAL    } from '../../modules/local/minimap2_host_removal/main'
include { FILTLONG                 } from '../../modules/local/filtlong/main'
include { NANOPLOT as NANOPLOT_FLT } from '../../modules/local/nanoplot/main'

workflow LONG_READ_QC {
    take:
    ch_long_inputs // channel: [ val(meta), path(reads_or_folder) ]
    ch_host_fasta  // channel: path(host.fasta)

    main:
    // Using the modern, lowercase channel keyword
    ch_versions = channel.empty()
    ch_qc_logs  = channel.empty()

    // 1. Conditional Branching: Handle Raw Fast5/Pod5 vs Pre-basecalled Fastq
    // Using '_' to explicitly ignore the reads path and avoid linter warnings
    ch_long_inputs.branch { tuple ->
        raw:   tuple[0].input_type == 'fast5' || tuple[0].input_type == 'pod5'
        fastq: tuple[0].input_type == 'fastq'
    }.set { ch_inputs }

    // Run Dorado basecalling only if needed (with a fallback model if unconfigured)
    DORADO_BASECALL(ch_inputs.raw, params.dorado_model ?: 'dna_r10.4.1_e8.2_400bps_sup@v4.3.0')
    ch_versions = ch_versions.mix(DORADO_BASECALL.out.versions)
    
    // Re-combine basecalled stream with the native fastq stream
    ch_initial_fastq = DORADO_BASECALL.out.reads.mix(ch_inputs.fastq)

    // 2. Initial Quality Assessment
    NANOPLOT_RAW(ch_initial_fastq, 'raw')
    ch_versions = ch_versions.mix(NANOPLOT_RAW.out.versions)
    ch_qc_logs  = ch_qc_logs.mix(NANOPLOT_RAW.out.report_dir)

    // 3. Adapter Trimming
    PORECHOP_ABI(ch_initial_fastq)
    ch_versions = ch_versions.mix(PORECHOP_ABI.out.versions)
    ch_qc_logs  = ch_qc_logs.mix(PORECHOP_ABI.out.log)

    // 4. Host Screen & Removals
    MINIMAP2_HOST_REMOVAL(PORECHOP_ABI.out.reads, ch_host_fasta)
    ch_versions = ch_versions.mix(MINIMAP2_HOST_REMOVAL.out.versions)

    // 5. Length & Quality Filters
    FILTLONG(MINIMAP2_HOST_REMOVAL.out.reads)
    ch_versions = ch_versions.mix(FILTLONG.out.versions)
    ch_qc_logs  = ch_qc_logs.mix(FILTLONG.out.log)

    // 6. Post-Filter Quality Assessment
    NANOPLOT_FLT(FILTLONG.out.reads, 'filtered')
    ch_versions = ch_versions.mix(NANOPLOT_FLT.out.versions)
    ch_qc_logs  = ch_qc_logs.mix(NANOPLOT_FLT.out.report_dir)

    emit:
    reads       = FILTLONG.out.reads       // Feeds Section 3 & Section 4
    qc_logs     = ch_qc_logs               // Feeds Section 8 MultiQC
    versions    = ch_versions              // Emits standard version YAMLs
}