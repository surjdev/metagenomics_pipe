include { MEGAHIT         } from '../../modules/local/megahit/main'
include { FLYE            } from '../../modules/local/flye/main'
include { OPERA_MS        } from '../../modules/local/opera_ms/main'
include { NEXTPOLISH      } from '../../modules/local/nextpolish/main'
include { RACON_MEDAKA    } from '../../modules/local/racon_medaka/main'
include { MAP_SHORT_READS } from '../../modules/local/map_short_reads/main'
include { MAP_LONG_READS  } from '../../modules/local/map_long_reads/main'
include { QUAST           } from '../../modules/local/quast/main'
include { PRODIGAL        } from '../../modules/local/prodigal/main'

workflow ASSEMBLY_AND_ANNOTATION {
    take:
    ch_short_reads   // channel: [ val(meta), [ path(r1), path(r2) ] ]
    ch_long_reads    // channel: [ val(meta), path(long_reads) ]

    main:
    // 1. Align channels by meta and branch using correct tuple structures
    ch_short_reads
        .join(ch_long_reads, remainder: true)
        .branch { meta, short_reads, long_reads ->
            hybrid:     short_reads != null && long_reads != null
            short_only: short_reads != null && long_reads == null
            long_only:  short_reads == null && long_reads != null
        }
        .set { ch_branched }

    // 2. Execute target assemblers (explicitly unpacking the short read array)
    MEGAHIT ( 
        ch_branched.short_only.map { meta, short_reads, long_reads -> [ meta, short_reads[0], short_reads[1] ] } 
    )
    FLYE ( 
        ch_branched.long_only.map { meta, short_reads, long_reads -> [ meta, long_reads ] } 
    )
    OPERA_MS ( 
        ch_branched.hybrid.map { meta, short_reads, long_reads -> [ meta, short_reads[0], short_reads[1], long_reads ] } 
    )

    // 3. Re-align and route to specialized polishers with clean array unpacking
    ch_to_nextpolish = MEGAHIT.out.contigs
        .mix(OPERA_MS.out.contigs)
        .join(ch_short_reads)
        .map { meta, contigs, short_reads -> [ meta, contigs, short_reads[0], short_reads[1] ] }

    NEXTPOLISH ( ch_to_nextpolish )

    ch_to_racon = FLYE.out.contigs
        .join(ch_long_reads)
        
    RACON_MEDAKA ( ch_to_racon )

    // Converge all polished streams
    ch_final_contigs = NEXTPOLISH.out.contigs.mix(RACON_MEDAKA.out.polished_contigs)

    // 4. Map reads back to the finalized contigs to produce the BAM allocations for binning
    ch_mapping_input = ch_final_contigs
        .join(ch_short_reads, remainder: true)
        .join(ch_long_reads, remainder: true)
        .branch { meta, contigs, short_reads, long_reads ->
            has_short: short_reads != null
            long_only: short_reads == null && long_reads != null
        }

    MAP_SHORT_READS ( 
        ch_mapping_input.has_short.map { meta, contigs, short_reads, long_reads -> [ meta, contigs, short_reads[0], short_reads[1] ] } 
    )
    MAP_LONG_READS ( 
        ch_mapping_input.long_only.map { meta, contigs, short_reads, long_reads -> [ meta, contigs, long_reads ] } 
    )

    ch_alignments = MAP_SHORT_READS.out.alignment.mix(MAP_LONG_READS.out.alignment)

    // 5. Downstream Evaluation & Structural Annotations
    QUAST ( ch_final_contigs )
    PRODIGAL ( ch_final_contigs )

    emit:
    contigs    = ch_final_contigs 
    bam        = ch_alignments     
    quast_tsv  = QUAST.out.tsv
    genes_faa  = PRODIGAL.out.faa
    genes_gff  = PRODIGAL.out.gff
}