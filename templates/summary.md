# {{ title | default('Hybrid Metagenomics Pipeline Summary') }}

Generated: {{ date | default('2026-08-17') }}

## Key Metrics

- **Total Samples**: {{ summary.total_samples | default(1) }}
- **Total Assembled Contigs**: {{ summary.total_contigs | default(0) }}
- **Assembly N50**: {{ summary.n50 | default('N/A') }} bp
- **Reconstructed MAGs**: {{ summary.total_bins | default(0) }}
- **Classified Taxa**: {{ summary.total_taxa | default(0) }}

## Sample Summary Table

| Sample ID | Platform | Contigs | Total Length (bp) | N50 (bp) | Bins | Status |
|---|---|---|---|---|---|---|
{% for sample in samples %}
| {{ sample.id }} | {{ sample.platform | default('hybrid') }} | {{ sample.contigs | default('-') }} | {{ sample.total_length | default('-') }} | {{ sample.n50 | default('-') }} | {{ sample.bins | default('0') }} | Completed |
{% else %}
| - | - | - | - | - | - | No samples |
{% endfor %}

## Pipeline Workflow Stages

1. **Preprocessing & Host Removal**: FastQC, Fastp, NanoPlot, Bowtie2, Minimap2
2. **Assembly & Polishing**: MEGAHIT, Flye, Opera-MS, NextPolish, QUAST
3. **MAG Reconstruction & QC**: MetaBAT2, MaxBin2, SemiBin2, CONCOCT, DAS Tool, CAT_BINS, CheckM2
4. **Read-Based Profiling**: Kraken2, Bracken, Krona, BIOM, HUMAnN3
5. **Annotation & Reporting**: Prokka, geNomad, MultiQC, Final Report
