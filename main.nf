#!/usr/bin/env nextflow
nextflow.enable.dsl = 2

// --------------------------------------------------------
// Import Subworkflows
// --------------------------------------------------------
include { SHORT_READ_QC              } from './subworkflows/local/short_read_qc'
include { LONG_READ_QC                } from './subworkflows/local/long_read_qc'
include { ASSEMBLY_FREE_PROFILING     } from './subworkflows/local/assembly_free_profiling'
include { ASSEMBLY_AND_ANNOTATION     } from './subworkflows/local/assembly_and_annotation'
include { BINNING                     } from './subworkflows/local/binning'
include { BIN_QC                      } from './subworkflows/local/bin_qc'
include { BIN_TAXONOMY_ANNOTATION     } from './subworkflows/local/bin_taxonomy_annotation'
include { RUN_SUMMARY                 } from './subworkflows/local/run_summary'

workflow {
    
    // 0. ตรวจสอบพารามิเตอร์เบื้องต้นและสร้าง Channel สำหรับฐานข้อมูลต่างๆ
    if (!params.input) { error "โปรดระบุไฟล์ Samplesheet ผ่าน --input" }
    
    ch_kraken2_db    = params.kraken2_db    ? Channel.value(file(params.kraken2_db))    : Channel.empty()
    ch_bracken_db   = params.bracken_db   ? Channel.value(file(params.bracken_db))   : Channel.empty()
    ch_metaphlan_db = params.metaphlan_db ? Channel.value(file(params.metaphlan_db)) : Channel.empty()
    ch_gunc_db      = params.gunc_db      ? Channel.value(file(params.gunc_db))      : Channel.empty()
    ch_checkm2_db   = params.checkm2_db   ? Channel.value(file(params.checkm2_db))   : Channel.empty()
    ch_gtdbtk_db    = params.gtdbtk_db    ? Channel.value(file(params.gtdbtk_db))    : Channel.empty()
    ch_eggnog_db    = params.eggnog_db    ? Channel.value(file(params.eggnog_db))    : Channel.empty()

    // อ่านค่า Samplesheet CSV
    // โครงสร้างสมมุติของ CSV: sample,fastq_1,fastq_2,long_fastx,input_type
    ch_samplesheet = Channel.fromPath(params.input)
        .splitCsv(header: true)
        .map { row ->
            def meta = [:]
            meta.id         = row.sample
            meta.single_end = row.fastq_2 ? false : true
            meta.input_type = row.input_type ? row.input_type : 'fastq' // สำหรับ long reads (fast5, pod5, fastq)

            def short_r1 = row.fastq_1 ? file(row.fastq_1) : null
            def short_r2 = row.fastq_2 ? file(row.fastq_2) : null
            def long_read = row.long_fastx ? file(row.long_fastx) : null

            return [ meta, short_r1, short_r2, long_read ]
        }

    // --------------------------------------------------------
    // Section 1 & 2: Independent QC Arms
    // --------------------------------------------------------
    
    // แยก Channel สำหรับ Short Reads และ Long Reads
    ch_short_inputs = ch_samplesheet
        .filter { it[1] != null }
        .map { meta, r1, r2, long_read -> [ meta, [r1, r2] ] }

    ch_long_inputs = ch_samplesheet
        .filter { it[3] != null }
        .map { meta, r1, r2, long_read -> [ meta, long_read ] }

    // รันกระบวนการ Short Reads QC
    ch_host_bt2_idx = params.host_bt2_index ? Channel.value(file(params.host_bt2_index)) : Channel.empty()
    SHORT_READ_QC(ch_short_inputs, ch_host_bt2_idx)

    // รันกระบวนการ Long Reads QC
    ch_host_fasta = params.host_fasta ? Channel.value(file(params.host_fasta)) : Channel.empty()
    LONG_READ_QC(ch_long_inputs, ch_host_fasta)

    // --------------------------------------------------------
    // Section 3: Assembly-Free Profiling
    // --------------------------------------------------------
    
    ASSEMBLY_FREE_PROFILING(
        SHORT_READ_QC.out.reads, 
        LONG_READ_QC.out.reads,
        ch_kraken2_db,
        ch_bracken_db,
        ch_metaphlan_db
    )

    // --------------------------------------------------------
    // Section 4: Assembly and Annotation
    // --------------------------------------------------------
    
    // จัดรูปแบบโครงสร้าง Channel ของ Short Reads ให้เข้าคู่แยก R1, R2 ตามที่โมดูลย่อยต้องการ
    ch_short_for_assembly = SHORT_READ_QC.out.reads.map { meta, reads -> [ meta, reads[0], reads[1] ] }
    
    ASSEMBLY_AND_ANNOTATION(
        ch_short_for_assembly, 
        LONG_READ_QC.out.reads
    )

    // --------------------------------------------------------
    // Section 5: Binning (Tiara -> Multi-binners -> DASTool)
    // --------------------------------------------------------
    
    /* *หมายเหตุโครงสร้างโค้ดเดิม*: โมดูล BINNING ต้องการ `ch_alignment` ในรูปแบบ `[meta, bam, bai]`
      เนื่องจากในโปรเจกต์นี้ไม่มีขั้นตอนการสร้าง BAM (เช่น Minimap2 หรือ Bowtie2 บน Contigs) ปรากฏอยู่ 
      ในระบบทดสอบขั้นนี้จึงสร้าง Mock channel เพื่อให้ Nextflow รันเชื่อมต่อผ่านไปได้แบบราบรื่น 
    */
    ch_mock_alignment = ASSEMBLY_AND_ANNOTATION.out.contigs.map { meta, contigs -> 
        [ meta, file("mock.bam"), file("mock.bai") ] 
    }

    BINNING(
        ASSEMBLY_AND_ANNOTATION.out.contigs, 
        ch_mock_alignment
    )

    // --------------------------------------------------------
    // Section 6 & 7: Bin Quality Control & Taxonomic Annotation
    // --------------------------------------------------------
    
    BIN_QC(
        BINNING.out.refined_bins,
        ch_gunc_db,
        ch_checkm2_db,
        params.busco_lineage ?: 'bacteria_odb10'
    )

    BIN_TAXONOMY_ANNOTATION(
        BINNING.out.refined_bins, 
        ch_gtdbtk_db, 
        ch_eggnog_db
    )

    // --------------------------------------------------------
    // Section 8: Run Summary & Global Reporting
    // --------------------------------------------------------
    
    // รวบรวมและรันระบบรายงานผลลัพธ์
    // RUN_SUMMARY(
    //     qc_logs        = SHORT_READ_QC.out.qc_zips.mix(LONG_READ_QC.out.filt_plots),
    //     profiling_out  = ASSEMBLY_FREE_PROFILING.out.merged_table,
    //     bin_qc_out     = BIN_QC.out.reports,
    //     bin_annot_out  = BIN_TAXONOMY_ANNOTATION.out.reports
    // )
    RUN_SUMMARY(
        SHORT_READ_QC.out.qc_zips.mix(LONG_READ_QC.out.filt_plots),
        ASSEMBLY_FREE_PROFILING.out.merged_table,
        BIN_QC.out.reports,
        BIN_TAXONOMY_ANNOTATION.out.reports
    )
}