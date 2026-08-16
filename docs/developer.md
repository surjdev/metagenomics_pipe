# Developer & Contributor Guide

This document provides developer guidelines for maintaining, extending, and testing the **Hybrid Metagenomics Pipeline**.

---

## 1. Development Principles & Layer Isolation

Always adhere strictly to the **5-Layer Architecture**:

1. **`main.nf`**: Orchestrates workflows only (`include { workflow_name } from './workflows/...'`). Never call modules or run shell commands in `main.nf`.
2. **`workflows/*.nf`**: Connects modules into stage pipelines. Never execute shell commands directly inside workflows.
3. **`modules/local/<tool>/main.nf`**: Contains a single Nextflow DSL2 `process` wrapping one bioinformatics tool. Use pinned biocontainers (`tool:1.0.0`, never `:latest`).
4. **`lib/*.groovy`**: Pure Groovy helper classes (e.g. `Utils.groovy`, `Samplesheet.groovy`, `Validation.groovy`).
5. **`bin/*.py`**: Standalone executable CLI scripts with standard argument parsing and exit codes.
6. **`conf/` & `params/`**: Infrastructure configuration and parameter presets. Never hardcode file paths in `.nf` files; always use `params.*`.

---

## 2. Adding a New Tool Module

Follow this 5-step checklist when adding a new tool:

1. **Create the module file**:
   ```
   modules/local/<tool_name>/main.nf
   ```
2. **Implement the process block**:
   ```groovy
   process TOOL_NAME {
       tag "$meta.id"
       label 'process_medium'

       container 'quay.io/biocontainers/<tool>:<version>'

       input:
       tuple val(meta), path(reads)

       output:
       tuple val(meta), path("*.tsv"), emit: tsv

       script:
       def prefix = task.ext.prefix ?: "${meta.id}"
       """
       tool_cmd \\
           --input ${reads} \\
           --threads ${task.cpus} \\
           --out ${prefix}.tsv
       """
   }
   ```
3. **Connect to the relevant workflow** under `workflows/<workflow_name>.nf`.
4. **Add parameters & container defaults** to `nextflow.config`, `conf/singularity.config`, and `params/*.yaml`.
5. **Add/update integration tests** in `test/`.

---

## 3. Running Automated Integration Tests

Test individual phase test suites locally with Docker:

```bash
# Phase 1: Preprocessing & Host Removal
nextflow run test/test_phase1.nf -profile docker,test

# Phase 2: Assembly & Polishing & QUAST
nextflow run test/test_phase2.nf -profile docker,test

# Phase 3: Read Mapping & Binning
nextflow run test/test_phase3.nf -profile docker,test

# Phase 4: Read-Based Profiling (Kraken2, Krona, BIOM)
nextflow run test/test_phase4.nf -profile docker,test --run_kraken2 true --kraken2_db test/data/tiny_databases/kraken2_db --run_krona true --run_kraken_biom true

# Phase 5: Annotation & Reporting
nextflow run test/test_phase5.nf -profile docker,test --run_prokka true --run_multiqc true --run_custom_report true

# Full End-to-End Pipeline
nextflow run main.nf -profile docker,test
```

---

## 4. Coding Conventions

- **Module Process Names**: All uppercase (`process FASTQC`, `process MEGAHIT`).
- **Workflow Names**: Lowercase with underscores (`workflow preprocessing`, `workflow host_removal`).
- **Groovy Classes**: PascalCase with camelCase methods (`Samplesheet.parseRow()`, `Validation.run()`).
- **Channel Tuples**: Always structure as `[ meta, files ]` where `meta` is a Map containing `[ id: 'sample_id', ... ]`.
- **Process Resource Labels**: Use `process_low`, `process_medium`, `process_high`, or `process_gpu`.
