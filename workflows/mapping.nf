/*
 * workflows/mapping.nf — Read Mapping & Contig Coverage Workflow
 * Maps short and/or long reads to assembly contigs and computes per-contig coverage depths.
 */

include { MAP_SHORT_READS        } from '../modules/local/map_short_reads/main.nf'
include { MAP_LONG_READS         } from '../modules/local/map_long_reads/main.nf'
include { ALIGN_READS_TO_CONTIGS } from '../modules/local/align_reads_to_contigs/main.nf'

workflow mapping {
    take:
    ch_contigs      // channel: [ meta, contigs ]
    ch_short_reads  // channel: [ meta, [ r1, r2 ] ] (or empty)
    ch_long_reads   // channel: [ meta, long_reads ] (or empty)

    main:
    ch_bams = Channel.empty()
    ch_bais = Channel.empty()

    // ── 1. Map short reads if present ─────────────────────────────────────────
    ch_short_in = ch_contigs
        .map { meta, contigs -> [ meta.id, meta, contigs ] }
        .join( ch_short_reads.map { meta, reads -> [ meta.id, reads ] } )
        .map { id, meta, contigs, reads -> [ meta, contigs, reads ] }

    MAP_SHORT_READS( ch_short_in )
    ch_bams = ch_bams.mix( MAP_SHORT_READS.out.bam_bai.map { meta, bam, bai -> [ meta.id, meta, bam ] } )
    ch_bais = ch_bais.mix( MAP_SHORT_READS.out.bam_bai.map { meta, bam, bai -> [ meta.id, meta, bai ] } )

    // ── 2. Map long reads if present ──────────────────────────────────────────
    ch_long_in = ch_contigs
        .map { meta, contigs -> [ meta.id, meta, contigs ] }
        .join( ch_long_reads.map { meta, reads -> [ meta.id, reads ] } )
        .map { id, meta, contigs, reads -> [ meta, contigs, reads ] }

    MAP_LONG_READS( ch_long_in )
    ch_bams = ch_bams.mix( MAP_LONG_READS.out.bam_bai.map { meta, bam, bai -> [ meta.id, meta, bam ] } )
    ch_bais = ch_bais.mix( MAP_LONG_READS.out.bam_bai.map { meta, bam, bai -> [ meta.id, meta, bai ] } )

    // ── 3. Group BAMs/BAIs by sample and compute depth ─────────────────────────
    ch_grouped_bams = ch_bams
        .groupTuple( by: 0 )
        .map { id, metas, bams -> [ id, metas[0], bams ] }

    ch_grouped_bais = ch_bais
        .groupTuple( by: 0 )
        .map { id, metas, bais -> [ id, bais ] }

    ch_depth_in = ch_grouped_bams
        .join( ch_grouped_bais, by: 0 )
        .map { id, meta, bams, bais -> [ meta, bams, bais ] }

    ALIGN_READS_TO_CONTIGS( ch_depth_in )

    emit:
    bam   = ch_bams.map { id, meta, bam -> [ meta, bam ] }
    bai   = ch_bais.map { id, meta, bai -> [ meta, bai ] }
    depth = ALIGN_READS_TO_CONTIGS.out.depth
}
