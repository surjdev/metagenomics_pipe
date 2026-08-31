# HANDOFF.md — Hybrid Metagenomics Pipeline

> **Purpose**: This file tells any AI agent exactly where the project stands right now.
> Read this first. Update this after completing any work.
>
> **Source of truth**: [`framework_plan.md`](framework_plan.md)
> **Agent rules**: [`.agents/AGENTS.md`](.agents/AGENTS.md)

---

## Current Project State

**Stage**: Phase 1, Phase 2, Phase 3, and Phase 4 complete and fully verified. Core preprocessing, host removal, assembly, polishing, assembly QC, read mapping, contig coverage/depth, multi-binner MAG reconstruction, DAS Tool dereplication, CAT_BINS standardization, MAG QC, Kraken2 taxonomic profiling, Bracken abundance estimation, Krona visualization, BIOM export, and HUMAnN3 functional profiling workflows implemented.

**Last action**: Implemented all Phase 4 Read-Based Analysis modules (`kraken2`, `bracken`, `kraken_biom`, `krona`, `humann3`), script helper (`bin/kraken_to_biom.py`), and workflow (`workflows/assembly_free.nf`). Tested & verified Phase 4 execution with `test/test_phase4.nf` under Docker profile. All taxonomic classifications, Krona charts, and BIOM tables generated successfully.

---

## What Exists (Architecture Layer)

### ✅ Directories & Files Created

```
main.nf                          ← Application Layer entry point
nextflow.config                  ← Global runtime config

conf/
  base.config                    ← Default settings
  slurm.config                   ← HPC executor config
  singularity.config             ← Container config
  docker.config                  ← Local Docker config
  test.config                    ← CI test config

params/
  illumina.yaml                  ← Illumina preset
  nanopore.yaml                  ← Nanopore preset
  hybrid.yaml                    ← Hybrid preset
  databases.yaml                 ← DB path preset

workflows/
  preprocessing.nf               ← QC, trim, basecall ✅
  host_removal.nf                ← Bowtie2/Minimap2 ✅
  assembly.nf                    ← MEGAHIT/Flye/Opera-MS ✅
  polishing.nf                   ← Racon/Medaka/NextPolish ✅
  assembly_qc.nf                 ← QUAST ✅
  mapping.nf                     ← Read→assembly BAM & depth ✅
  binning.nf                     ← MAG binning (MetaBAT2/MaxBin2/SemiBin2/CONCOCT/DASTool/CAT_BINS) ✅
  mag_qc.nf                      ← CheckM2/GUNC/GTDB-Tk ✅
  annotation.nf                  ← Prokka/geNomad
  assembly_free.nf               ← Kraken2/Bracken/Krona/BIOM/HUMAnN3 ✅
  reporting.nf                   ← Final report

modules/local/ (35 tools)
  Phase 1: fastqc ✅  fastp ✅  dorado_basecall ✅  nanoplot ✅  porechop_abi ✅  filtlong ✅  bowtie2_host_removal ✅  minimap2_host_removal ✅
  Phase 2: megahit ✅  flye ✅  opera_ms ✅  racon_medaka ✅  nextpolish ✅  quast ✅
  Phase 3: map_short_reads ✅  map_long_reads ✅  align_reads_to_contigs ✅  metabat2 ✅  maxbin2 ✅  semibin2 ✅  concoct ✅  dastool ✅  cat_bins ✅  checkm2 ✅  gunc ✅  gtdbtk ✅
  Phase 4: kraken2 ✅  bracken ✅  kraken_biom ✅  krona ✅  humann3 ✅
  Phase 5: multiqc  generate_reports

lib/
  Utils.groovy                   ← General helpers
  Samplesheet.groovy             ← CSV parsing + validation
  Validation.groovy              ← Pre-flight checks

bin/
  extract_nonhost.py             ← BAM → unmapped FASTQ
  kraken_to_biom.py              ← Kraken2 → BIOM ✅
  generate_report.py             ← HTML/PDF report builder

templates/
  report.html                    ← Jinja2 HTML template
  summary.md                     ← Markdown summary template

docs/
  installation.md  quickstart.md  architecture.md
  outputs.md  developer.md  contributing.md

test/data/
  tiny_illumina/  tiny_nanopore/  tiny_databases/

databases/
  README.md  download.sh
```

---

## What Does NOT Exist Yet (Implementation)

### ✅ Phase 1 — Implemented

| File | Status |
|---|---|
| `modules/local/fastqc/main.nf` | ✅ process FASTQC |
| `modules/local/fastp/main.nf` | ✅ process FASTP |
| `modules/local/dorado_basecall/main.nf` | ✅ process DORADO_BASECALL |
| `modules/local/nanoplot/main.nf` | ✅ process NANOPLOT |
| `modules/local/porechop_abi/main.nf` | ✅ process PORECHOP_ABI |
| `modules/local/filtlong/main.nf` | ✅ process FILTLONG |
| `modules/local/bowtie2_host_removal/main.nf` | ✅ process BOWTIE2_HOST_REMOVAL |
| `modules/local/minimap2_host_removal/main.nf` | ✅ process MINIMAP2_HOST_REMOVAL |
| `workflows/preprocessing.nf` | ✅ workflow preprocessing |
| `workflows/host_removal.nf` | ✅ workflow host_removal |

### ✅ Phase 2 — Implemented

| File | Status |
|---|---|
| `modules/local/megahit/main.nf` | ✅ process MEGAHIT |
| `modules/local/flye/main.nf` | ✅ process FLYE |
| `modules/local/opera_ms/main.nf` | ✅ process OPERA_MS |
| `modules/local/racon_medaka/main.nf` | ✅ process RACON_MEDAKA |
| `modules/local/nextpolish/main.nf` | ✅ process NEXTPOLISH |
| `modules/local/quast/main.nf` | ✅ process QUAST |
| `workflows/assembly.nf` | ✅ workflow assembly |
| `workflows/polishing.nf` | ✅ workflow polishing |
| `workflows/assembly_qc.nf` | ✅ workflow assembly_qc |

### ✅ Phase 3 — Implemented

| File | Status |
|---|---|
| `modules/local/map_short_reads/main.nf` | ✅ process MAP_SHORT_READS |
| `modules/local/map_long_reads/main.nf` | ✅ process MAP_LONG_READS |
| `modules/local/align_reads_to_contigs/main.nf` | ✅ process ALIGN_READS_TO_CONTIGS |
| `modules/local/metabat2/main.nf` | ✅ process METABAT2 |
| `modules/local/maxbin2/main.nf` | ✅ process MAXBIN2 |
| `modules/local/semibin2/main.nf` | ✅ process SEMIBIN2 |
| `modules/local/concoct/main.nf` | ✅ process CONCOCT |
| `modules/local/dastool/main.nf` | ✅ process DASTOOL |
| `modules/local/cat_bins/main.nf` | ✅ process CAT_BINS |
| `modules/local/checkm2/main.nf` | ✅ process CHECKM2 |
| `modules/local/gunc/main.nf` | ✅ process GUNC |
| `modules/local/gtdbtk/main.nf` | ✅ process GTDBTK |
| `workflows/mapping.nf` | ✅ workflow mapping |
| `workflows/binning.nf` | ✅ workflow binning |
| `workflows/mag_qc.nf` | ✅ workflow mag_qc |

### ✅ Phase 4 — Implemented

| File | Status |
|---|---|
| `modules/local/kraken2/main.nf` | ✅ process KRAKEN2 |
| `modules/local/bracken/main.nf` | ✅ process BRACKEN |
| `modules/local/kraken_biom/main.nf` | ✅ process KRAKEN_BIOM |
| `modules/local/krona/main.nf` | ✅ process KRONA |
| `modules/local/humann3/main.nf` | ✅ process HUMANN3 |
| `bin/kraken_to_biom.py` | ✅ kraken_to_biom.py |
| `workflows/assembly_free.nf` | ✅ workflow assembly_free |

### ✅ Phase 5 — Implemented & Verified
- `modules/local/multiqc/main.nf`: `process MULTIQC`
- `modules/local/generate_reports/main.nf`: `process GENERATE_REPORTS`
- `modules/local/prokka/main.nf`: `process PROKKA`
- `modules/local/genomad/main.nf`: `process GENOMAD`
- `bin/generate_report.py`: Python CLI for Jinja2 report and summary generation
- `templates/report.html`: Interactive HTML report template
- `templates/summary.md`: Markdown summary template
- `workflows/annotation.nf`: Functional and mobile genetic element annotation workflow
- `workflows/reporting.nf`: Quality and reporting orchestration workflow
- `test/test_phase5.nf`: Integration test verified with 100% success

---

### ✅ Full Pipeline Application Orchestration — Implemented & Verified
- `lib/Utils.groovy`: Formatted header banners and parameter logging
- `lib/Samplesheet.groovy`: CSV samplesheet parsing and column validation
- `lib/Validation.groovy`: Parameter and input file pre-flight sanity checks
- `main.nf`: Application layer entry point connecting all 11 workflows end-to-end
- Verified with Nextflow Docker test profile (`nextflow run main.nf -profile docker,test`)

---

## Phase Completion Status

| Phase | Modules Done | Workflow Done | Test Status |
|---|---|---|---|
| 1 — Core | ✅ (8/8) | ✅ (2/2) | ✅ Verified (test_phase1.nf) |
| 2 — Assembly | ✅ (6/6) | ✅ (3/3) | ✅ Verified (test_phase2.nf) |
| 3 — MAG Reconstruction | ✅ (12/12) | ✅ (3/3) | ✅ Verified (test_phase3.nf) |
| 4 — Read-Based | ✅ (5/5) | ✅ (1/1) | ✅ Verified (test_phase4.nf) |
| 5 — Reporting & Annotation | ✅ (4/4) | ✅ (2/2) | ✅ Verified (test_phase5.nf) |
| Infrastructure & Lib | ✅ (3/3 lib) | — | ✅ Verified (conf/params) |
| main.nf End-to-End | — | ✅ (11/11 wired) | ✅ Verified (main.nf) |

**Overall: 100% implemented & verified** (All 35 modules, 11 workflows, lib scripts, templates, Python CLI utilities, and main.nf entry point).

---

## Update Log

| Date | Agent | Action |
|---|---|---|
| 2026-08-14 | Antigravity | Architecture scaffold created from framework_plan.md |
| 2026-08-14 | Antigravity | Unused modules deleted, all files wiped to empty stubs |
| 2026-08-14 | Antigravity | HANDOFF.md and .agents/AGENTS.md created |
| 2026-08-14 | Antigravity | Phase 1 implemented: 8 modules + preprocessing.nf + host_removal.nf |
| 2026-08-14 | Antigravity | Phase 1 tested & verified with Nextflow docker profile (test/test_phase1.nf) |
| 2026-08-14 | Antigravity | Phase 2 implemented & verified: 6 modules (MEGAHIT, Flye, Opera-MS, Racon, NextPolish, QUAST) + assembly.nf, polishing.nf, assembly_qc.nf (test/test_phase2.nf) |
| 2026-08-17 | Antigravity | Phase 3 implemented & verified: 12 modules (map_short_reads, map_long_reads, align_reads_to_contigs, metabat2, maxbin2, semibin2, concoct, dastool, cat_bins, checkm2, gunc, gtdbtk) + mapping.nf, binning.nf, mag_qc.nf (test/test_phase3.nf) |
| 2026-08-17 | Antigravity | Phase 4 implemented & verified: 5 modules (kraken2, bracken, kraken_biom, krona, humann3) + bin/kraken_to_biom.py + assembly_free.nf (test/test_phase4.nf) |
| 2026-08-17 | Antigravity | Phase 5 implemented & verified: 4 modules (multiqc, generate_reports, prokka, genomad) + bin/generate_report.py + templates + annotation.nf, reporting.nf (test/test_phase5.nf) |
| 2026-08-17 | Antigravity | Complete pipeline application layer implemented: lib/Utils.groovy, lib/Samplesheet.groovy, lib/Validation.groovy + main.nf orchestrating all 11 workflows end-to-end (verified with test profile) |
| 2026-08-26 | Antigravity | Initiated Meta_NPI Nanopore testing: Built Phase 1 & 2 (PLAN_TEST_Meta_NPI.md, MEMORY_HANDOFF_TEST_Meta_NPI.md, bin/generate_samplesheet_meta_npi.py, conf/meta_npi.config, samplesheet_meta_npi_smoke.csv, samplesheet_meta_npi_full.csv, main.nf long-read profiling routing, DAG preview verified) |
