/*
 * lib/Samplesheet.groovy — Samplesheet Parsing and Validation
 * Layer: Script Layer
 */

class Samplesheet {

    static void validateHeader(List header) {
        def required = ['sample']
        required.each { col ->
            if (!header.contains(col)) {
                throw new IllegalArgumentException("Samplesheet error: missing required column '${col}'")
            }
        }
    }

    static Map parseRow(Map row) {
        def sampleId = row.sample?.trim()
        if (!sampleId) {
            throw new IllegalArgumentException("Samplesheet error: sample ID is blank in row: ${row}")
        }
        return row
    }
}
