include { FASTQC as FASTQC_RAW     } from '../../modules/local/fastqc/main'
include { FASTP                    } from '../../modules/local/fastp/main'
include { BOWTIE2_HOST_REMOVAL     } from '../../modules/local/bowtie2_host_removal/main'
include { CLUMPIFY_DEDUP           } from '../../modules/local/clumpify_dedup/main'
include { BBNORM                   } from '../../modules/local/bbnorm/main'
include { FASTQC as FASTQC_TRIMMED } from '../../modules/local/fastqc/main'

workflow SHORT_READ_QC {
    take:
    ch_reads      // channel: [ val(meta), [ path(r1), path(r2) ] ]
    ch_host_index // channel: path(bowtie2_index_dir)

    main:
    ch_versions = channel.empty()

    // 1. Diagnostics on raw inputs
    FASTQC_RAW(ch_reads)
    ch_versions = ch_versions.mix(FASTQC_RAW.out.versions)

    // 2. Adapter trimming & structural filtering
    FASTP(ch_reads)
    ch_versions = ch_versions.mix(FASTP.out.versions)

    // 3. Mapping-based host contamination screening
    BOWTIE2_HOST_REMOVAL(FASTP.out.reads, ch_host_index)
    ch_versions = ch_versions.mix(BOWTIE2_HOST_REMOVAL.out.versions)

    // 4. Clumpify deduplication
    CLUMPIFY_DEDUP(BOWTIE2_HOST_REMOVAL.out.reads)
    ch_versions = ch_versions.mix(CLUMPIFY_DEDUP.out.versions)

    // 5. Gated normalization routine
    if (params.normalise) {
        BBNORM(CLUMPIFY_DEDUP.out.reads)
        ch_versions     = ch_versions.mix(BBNORM.out.versions)
        ch_final_reads  = BBNORM.out.reads.map { meta, r1, r2 -> [meta, [r1, r2]] }
    } else {
        ch_final_reads  = CLUMPIFY_DEDUP.out.reads.map { meta, r1, r2 -> [meta, [r1, r2]] }
    }

    // 6. Final post-QC evaluation
    FASTQC_TRIMMED(ch_final_reads)
    ch_versions = ch_versions.mix(FASTQC_TRIMMED.out.versions)

    emit:
    reads      = ch_final_reads                                 // [ val(meta), [path(r1), path(r2)] ]
    qc_zips    = FASTQC_RAW.out.zip.mix(FASTQC_TRIMMED.out.zip) // For multiqc logs mix channel
    fastp_json = FASTP.out.json                                 
    versions   = ch_versions                                    // Collected manifest
}