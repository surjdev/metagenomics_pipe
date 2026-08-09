include { QUAST_BINS   } from '../../modules/local/quast/main'
include { GUNC         } from '../../modules/local/gunc/main'
include { CHECKM2      } from '../../modules/local/checkm2/main'
include { BUSCO        } from '../../modules/local/busco/main'

workflow BIN_QC {
    take:
    ch_refined_bins // [meta, path(bins_directory)]
    ch_gunc_db
    ch_checkm2_db
    val_busco_lineage

    main:
    // Fan-out: All tools run independently on the same refined bins
    QUAST_BINS(ch_refined_bins)
    GUNC(ch_refined_bins, ch_gunc_db)
    CHECKM2(ch_refined_bins, ch_checkm2_db)
    
    // Optional: Include BUSCO based on pipeline parameters if desired
    BUSCO(ch_refined_bins, val_busco_lineage)

    emit:
    // We emit individual channels in case they are needed for specific downstream logic
    quast_report   = QUAST_BINS.out.report
    gunc_report    = GUNC.out.report
    gunc_tsv       = GUNC.out.summary_tsv
    checkm2_report = CHECKM2.out.report
    checkm2_tsv    = CHECKM2.out.summary_tsv
    busco_report   = BUSCO.out.report

    // Mix all QC outputs into a single channel to feed into RUN_SUMMARY and MultiQC easily
    reports = QUAST_BINS.out.report
                .mix(GUNC.out.report)
                .mix(CHECKM2.out.report)
                .mix(BUSCO.out.report)
}