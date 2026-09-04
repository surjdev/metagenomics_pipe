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
        // Normalize fastq column names if needed
        if (!row.fastq_1 && row.short_r1) row.fastq_1 = row.short_r1
        if (!row.fastq_2 && row.short_r2) row.fastq_2 = row.short_r2
        return row
    }
}

