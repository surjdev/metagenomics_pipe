/*
 * lib/Samplesheet.groovy — Samplesheet Parsing and Validation
 * Layer: Script Layer
 */

class Samplesheet {

    static void validateHeader(List header) {
        def hasSample = header.contains('sample') || header.contains('sample_id')
        if (!hasSample) {
            throw new IllegalArgumentException("Samplesheet error: missing required column 'sample' or 'sample_id'")
        }
    }

    static Map parseRow(Map row) {
        def sampleId = (row.sample ?: row.sample_id)?.trim()
        if (!sampleId) {
            throw new IllegalArgumentException("Samplesheet error: sample ID is blank in row: ${row}")
        }
        if (!row.sample && row.sample_id) {
            row.sample = row.sample_id
        }
        // Normalize short read FASTQ column names
        if (!row.fastq_1) {
            row.fastq_1 = row.illumina_r1 ?: row.short_r1 ?: row.read1 ?: row.r1
        }
        if (!row.fastq_2) {
            row.fastq_2 = row.illumina_r2 ?: row.short_r2 ?: row.read2 ?: row.r2
        }
        // Normalize long read FASTQ column names
        if (!row.long_fastq) {
            row.long_fastq = row.ont_fastq ?: row.long_reads ?: row.nanopore_fastq ?: row.ont
        }
        return row
    }
}

