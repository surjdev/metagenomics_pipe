/*
 * lib/Validation.groovy — Parameter Pre-flight Checks
 * Layer: Script Layer
 */

class Validation {

    static void run(Map params) {
        if (!params.input) {
            throw new IllegalArgumentException("Pipeline error: Please specify input samplesheet with '--input <path/to/samplesheet.csv>'")
        }

        def input_file = new File(params.input as String)
        if (!input_file.exists()) {
            throw new IllegalArgumentException("Pipeline error: Input file '${params.input}' does not exist.")
        }
    }
}
