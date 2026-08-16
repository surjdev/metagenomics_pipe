/*
 * lib/Utils.groovy — Helper Utilities
 * Layer: Script Layer
 */

class Utils {

    static String headerBanner() {
        return """
        =======================================================
          HYBRID METAGENOMICS PIPELINE (Nextflow DSL2)
        =======================================================
        """.stripIndent()
    }

    static void logParameters(Map params) {
        println "── Configured Parameters ──"
        params.each { k, v ->
            if (v != null && !['help', 'monochrome_logs'].contains(k)) {
                println "  * ${k.padRight(25)}: ${v}"
            }
        }
        println "───────────────────────────\n"
    }
}
