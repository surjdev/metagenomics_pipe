/*
 * workflows/binning.nf — Metagenome Binning & Refinement Workflow
 * Executes MetaBAT2, MaxBin2, SemiBin2, CONCOCT, DAS Tool, and standardizes bins with CAT_BINS.
 */

include { METABAT2  } from '../modules/local/metabat2/main.nf'
include { MAXBIN2   } from '../modules/local/maxbin2/main.nf'
include { SEMIBIN2  } from '../modules/local/semibin2/main.nf'
include { CONCOCT   } from '../modules/local/concoct/main.nf'
include { DASTOOL   } from '../modules/local/dastool/main.nf'
include { CAT_BINS  } from '../modules/local/cat_bins/main.nf'

workflow binning {
    take:
    ch_contigs  // channel: [ meta, contigs ]
    ch_bam      // channel: [ meta, bam ]
    ch_bai      // channel: [ meta, bai ]
    ch_depth    // channel: [ meta, depth ]

    main:
    ch_bins_all = Channel.empty()
    ch_tsvs_all = Channel.empty()

    // ── 1. MetaBAT2 ───────────────────────────────────────────────────────────
    if (params.run_metabat2) {
        ch_metabat2_in = ch_contigs
            .map { meta, contigs -> [ meta.id, meta, contigs ] }
            .join( ch_depth.map { meta, depth -> [ meta.id, depth ] } )
            .map { id, meta, contigs, depth -> [ meta, contigs, depth ] }

        METABAT2( ch_metabat2_in )
        ch_bins_all = ch_bins_all.mix( METABAT2.out.bins )
        ch_tsvs_all = ch_tsvs_all.mix( METABAT2.out.scaffolds2bin )
    }

    // ── 2. MaxBin2 ────────────────────────────────────────────────────────────
    if (params.run_maxbin2) {
        ch_maxbin2_in = ch_contigs
            .map { meta, contigs -> [ meta.id, meta, contigs ] }
            .join( ch_depth.map { meta, depth -> [ meta.id, depth ] } )
            .map { id, meta, contigs, depth -> [ meta, contigs, depth ] }

        MAXBIN2( ch_maxbin2_in )
        ch_bins_all = ch_bins_all.mix( MAXBIN2.out.bins )
        ch_tsvs_all = ch_tsvs_all.mix( MAXBIN2.out.scaffolds2bin )
    }

    // ── 3. SemiBin2 ───────────────────────────────────────────────────────────
    if (params.run_semibin2) {
        ch_first_bam = ch_bam
            .map { meta, bam -> [ meta.id, bam ] }
            .groupTuple( by: 0 )
            .map { id, bams -> [ id, bams[0] ] }

        ch_semibin2_in = ch_contigs
            .map { meta, contigs -> [ meta.id, meta, contigs ] }
            .join( ch_first_bam )
            .map { id, meta, contigs, bam -> [ meta, contigs, bam ] }

        SEMIBIN2( ch_semibin2_in )
        ch_bins_all = ch_bins_all.mix( SEMIBIN2.out.bins )
        ch_tsvs_all = ch_tsvs_all.mix( SEMIBIN2.out.scaffolds2bin )
    }

    // ── 4. CONCOCT ────────────────────────────────────────────────────────────
    if (params.run_concoct) {
        ch_first_bam_bai = ch_bam
            .map { meta, bam -> [ meta.id, bam ] }
            .groupTuple( by: 0 )
            .join( ch_bai.map { meta, bai -> [ meta.id, bai ] }.groupTuple( by: 0 ) )
            .map { id, bams, bais -> [ id, bams[0], bais[0] ] }

        ch_concoct_in = ch_contigs
            .map { meta, contigs -> [ meta.id, meta, contigs ] }
            .join( ch_first_bam_bai )
            .map { id, meta, contigs, bam, bai -> [ meta, contigs, bam, bai ] }

        CONCOCT( ch_concoct_in )
        ch_bins_all = ch_bins_all.mix( CONCOCT.out.bins )
        ch_tsvs_all = ch_tsvs_all.mix( CONCOCT.out.scaffolds2bin )
    }

    // ── 5. DAS Tool (optional dereplication if enabled) ───────────────────────
    if (params.run_dastool) {
        ch_tsvs_grouped = ch_tsvs_all
            .map { meta, tsv -> [ meta.id, tsv ] }
            .groupTuple( by: 0 )

        ch_dastool_in = ch_contigs
            .map { meta, contigs -> [ meta.id, meta, contigs ] }
            .join( ch_tsvs_grouped )
            .map { id, meta, contigs, tsvs -> [ meta, contigs, tsvs ] }

        DASTOOL( ch_dastool_in )
        ch_bins_to_cat = DASTOOL.out.bins
    } else {
        ch_bins_to_cat = ch_bins_all
    }

    // ── 6. Consolidate and summarize final bins ───────────────────────────────
    ch_cat_in = ch_contigs
        .map { meta, contigs -> [ meta.id, meta, contigs ] }
        .join( ch_bins_to_cat.map { meta, bins -> [ meta.id, bins ] }.groupTuple( by: 0 ), remainder: true )
        .map { id, meta, contigs, bins -> 
            def bin_list = (bins != null) ? [bins].flatten().findAll { it != null } : [contigs]
            [ meta, bin_list ]
        }

    CAT_BINS( ch_cat_in )

    emit:
    bins     = CAT_BINS.out.bins
    bins_dir = CAT_BINS.out.dir
    summary  = CAT_BINS.out.summary
}
