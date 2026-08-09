include { GTDBTK        } from '../../modules/local/gtdbtk/main'
include { CAT_BINS      } from '../../modules/local/cat_bins/main'
include { PROKKA        } from '../../modules/local/prokka/main'
include { METAEUK       } from '../../modules/local/metaeuk/main'
include { EGGNOG_MAPPER } from '../../modules/local/eggnog_mapper/main'

workflow BIN_TAXONOMY_ANNOTATION {
    take:
    ch_bins_dir   
    ch_tax_db          // GTDB-Tk or CAT DB
    ch_cat_taxonomy    // Required for CAT_BINS (Line 17 fix)
    ch_mmseqs_db       // Required for METAEUK (Line 33 fix)
    ch_eggnog_db  

    main:
    // Option 1: Taxonomy
    ch_tax_reports = channel.empty()
    if (params.taxonomy_tool == 'cat') {
        CAT_BINS(ch_bins_dir, ch_tax_db, ch_cat_taxonomy)
        ch_tax_reports = CAT_BINS.out.classification
    } else {
        GTDBTK(ch_bins_dir, ch_tax_db)
        ch_tax_reports = GTDBTK.out.summary
    }

    ch_individual_bins = ch_bins_dir.flatMap { meta, bins_dir ->
        bins_dir.listFiles()
            .findAll { file -> file.name.endsWith('.fa') || file.name.endsWith('.fasta') }
            .collect { bin_file -> [ meta, bin_file ] }
    }

    // Option 2: Gene Annotation
    ch_amino_acids = channel.empty()
    if (params.gene_annotator == 'metaeuk') {
        METAEUK(ch_individual_bins, ch_mmseqs_db)
        ch_amino_acids = METAEUK.out.fasta // Uses emitted predicted amino acids
    } else {
        PROKKA(ch_individual_bins)
        ch_amino_acids = PROKKA.out.faa
    }

    EGGNOG_MAPPER(ch_amino_acids, ch_eggnog_db)

    emit:
    reports = ch_tax_reports.mix(EGGNOG_MAPPER.out.annotations)
}