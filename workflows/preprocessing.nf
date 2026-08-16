include { FASTQC           } from '../modules/local/fastqc/main.nf'
include { FASTP            } from '../modules/local/fastp/main.nf'
include { NANOPLOT         } from '../modules/local/nanoplot/main.nf'
include { DORADO_BASECALL  } from '../modules/local/dorado_basecall/main.nf'
include { PORECHOP_ABI     } from '../modules/local/porechop_abi/main.nf'
include { FILTLONG         } from '../modules/local/filtlong/main.nf'
include { MULTIQC as MULTIQC_PREPROCESS } from '../modules/local/multiqc/main.nf'

workflow preprocessing {

    take:
    ch_short_reads  // channel: [ meta, [ fastq_1, fastq_2 ] ]
    ch_long_reads   // channel: [ meta, fastq ]

    main:
    ch_qc_reports = Channel.empty()

    // ── Short reads ──────────────────────────────────────────────────────────
    // Run FastQC on raw short reads
    FASTQC ( ch_short_reads )
    ch_qc_reports = ch_qc_reports.mix( FASTQC.out.zip.map { meta, zip -> zip } )

    // Trim adapters and filter by quality/length
    FASTP ( ch_short_reads )
    ch_clean_short = FASTP.out.reads
    ch_qc_reports  = ch_qc_reports.mix( FASTP.out.json.map { meta, json -> json } )

    // ── Long reads ───────────────────────────────────────────────────────────
    // Optional basecalling (only when starting from raw POD5/FAST5)
    if ( params.run_basecalling ) {
        DORADO_BASECALL ( ch_long_reads )
        ch_basecalled = DORADO_BASECALL.out.reads
    } else {
        ch_basecalled = ch_long_reads
    }

    // Long read quality statistics
    NANOPLOT ( ch_basecalled )
    ch_qc_reports = ch_qc_reports.mix( NANOPLOT.out.txt.map { meta, txt -> txt } )

    // Optional adapter trimming for long reads
    if ( params.run_porechop ) {
        PORECHOP_ABI ( ch_basecalled )
        ch_trimmed_long = PORECHOP_ABI.out.reads
    } else {
        ch_trimmed_long = ch_basecalled
    }

    // Optional quality/length filtering for long reads
    if ( params.run_filtlong ) {
        FILTLONG ( ch_trimmed_long )
        ch_clean_long = FILTLONG.out.reads
    } else {
        ch_clean_long = ch_trimmed_long
    }

    emit:
    short_reads  = ch_clean_short        // [ meta, [ fq1, fq2 ] ]
    long_reads   = ch_clean_long         // [ meta, fastq ]
    qc_reports   = ch_qc_reports
}
