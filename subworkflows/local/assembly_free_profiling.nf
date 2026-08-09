// subworkflows/local/assembly_free_profiling.nf

include { KRAKEN2         } from '../../modules/local/kraken2/main'
include { BRACKEN         } from '../../modules/local/bracken/main'
include { METAPHLAN4      } from '../../modules/local/metaphlan4/main'
include { HUMANN3         } from '../../modules/local/humann3/main'
include { KRONA           } from '../../modules/local/krona/main'
include { KRAKEN_BIOM     } from '../../modules/local/kraken_biom/main'

workflow ASSEMBLY_FREE_PROFILING {
    take:
    ch_short_reads   
    ch_long_reads    
    ch_kraken2_db
    ch_bracken_db
    ch_metaphlan_db     // Separated MetaPhlAn DB
    ch_humann_nuc_db    // Explicit HUMAnN3 Nucleotide DB (ChocoPhlAn)
    ch_humann_prot_db   // Explicit HUMAnN3 Protein DB (UniRef)

    main:
    ch_versions = channel.empty()
    ch_all_reads = ch_short_reads.mix(ch_long_reads)

    // Taxonomy Profiling
    KRAKEN2(ch_all_reads, ch_kraken2_db)
    ch_versions = ch_versions.mix(KRAKEN2.out.versions)

    BRACKEN(KRAKEN2.out.report, ch_bracken_db)
    ch_versions = ch_versions.mix(BRACKEN.out.versions)
    
    // Functional Profiling Branch
    ch_functional_out = channel.empty()
    
    if (params.functional_profiler == 'humann3') {
        // FIXED: Now passing exactly the 3 arguments HUMANN3 expects
        HUMANN3(ch_all_reads, ch_humann_nuc_db, ch_humann_prot_db)
        ch_functional_out = HUMANN3.out.gene_families
        ch_versions = ch_versions.mix(HUMANN3.out.versions)
    } else {
        METAPHLAN4(ch_all_reads, ch_metaphlan_db)
        ch_functional_out = METAPHLAN4.out.profile
        ch_versions = ch_versions.mix(METAPHLAN4.out.versions)
    }
    
    // Visualizations and Conversions
    KRONA(KRAKEN2.out.report)
    ch_versions = ch_versions.mix(KRONA.out.versions)

    ch_all_kraken_reports = KRAKEN2.out.report.map { meta, report -> report }.collect()
    KRAKEN_BIOM(ch_all_kraken_reports)
    ch_versions = ch_versions.mix(KRAKEN_BIOM.out.versions)

    emit:
    kraken_reports = KRAKEN2.out.report
    bracken_tables = BRACKEN.out.abundances
    functional_out = ch_functional_out
    merged_table   = KRAKEN_BIOM.out.biom
    versions       = ch_versions
}