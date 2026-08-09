include { TIARA    } from '../../modules/local/tiara/main'
include { METABAT2 } from '../../modules/local/metabat2/main'
include { MAXBIN2  } from '../../modules/local/maxbin2/main'
include { CONCOCT  } from '../../modules/local/concoct/main'
include { SEMIBIN2 } from '../../modules/local/semibin2/main'
include { DASTOOL  } from '../../modules/local/dastool/main'

workflow BINNING {
    take:
    ch_contigs     // channel: [ val(meta), path(contigs) ]
    ch_alignment   // channel: [ val(meta), path(bam), path(bai) ]

    main:
    // 1. Filter out Eukaryotic contigs using Tiara
    TIARA(ch_contigs)
    ch_prok_contigs = TIARA.out.prokaryote_contigs

    // 2. Pair the filtered contigs with their corresponding alignment BAM files
    // Shape: [ val(meta), path(prok_contigs), path(bam), path(bai) ]
    ch_binning_input = ch_prok_contigs.join(ch_alignment)

    // 3. Fire off the 4 multi-binning algorithms in parallel
    METABAT2(ch_binning_input)
    MAXBIN2(ch_binning_input)
    CONCOCT(ch_binning_input)
    SEMIBIN2(ch_binning_input)

    // 4. Consolidate and refine all bins through DASTool
    // FIXED: Replaced implicit 'it' with explicit closure parameters 'meta, bins'
    DASTOOL(
        ch_prok_contigs,
        METABAT2.out.bins.map { meta, bins -> bins }.collect(),
        MAXBIN2.out.bins.map  { meta, bins -> bins }.collect(),
        CONCOCT.out.bins.map  { meta, bins -> bins }.collect(),
        SEMIBIN2.out.bins.map { meta, bins -> bins }.collect()
    )

    emit:
    refined_bins = DASTOOL.out.bins    // channel: [ val(meta), path("bins/*.fa") ]
    summary_tsv  = DASTOOL.out.summary // channel: [ val(meta), path("*.tsv") ]
}