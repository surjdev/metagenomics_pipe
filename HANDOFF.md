# HANDOFF.md — Hybrid Metagenomics Pipeline

> **Purpose**: This file tells any AI agent exactly where the project stands right now.
> Read this first. Update this after completing any work.
>
> **Source of truth**: [`../../framework_plan.md`](../../framework_plan.md)
> **Agent rules**: [`../../.agents/AGENTS.md`](../../.agents/AGENTS.md)

---

## Current Project State

**Stage**: Phase 1 complete. Core modules and preprocessing/host_removal workflows implemented.

**Last action**: Implemented all 8 Phase 1 modules (FastQC, Fastp, Dorado, NanoPlot, Porechop-ABI, Filtlong, Bowtie2, Minimap2) and 2 workflows (preprocessing.nf, host_removal.nf). All other files remain empty stubs.

---

## What Exists (Architecture Layer)

### ✅ Directories & Files Created (all empty)

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
  preprocessing.nf               ← QC, trim, basecall
  host_removal.nf                ← Bowtie2/Minimap2
  assembly.nf                    ← MEGAHIT/Flye/Opera-MS
  polishing.nf                   ← Racon/Medaka/NextPolish
  assembly_qc.nf                 ← QUAST
  mapping.nf                     ← Read→assembly BAM
  binning.nf                     ← MAG binning
  mag_qc.nf                      ← CheckM2/GUNC/GTDB-Tk
  annotation.nf                  ← Prokka/geNomad
  assembly_free.nf               ← Kraken2/Bracken/Krona/HUMAnN3
  reporting.nf                   ← Final report

modules/local/ (35 tools, all empty main.nf)
  Phase 1: fastqc ✅  fastp ✅  dorado_basecall ✅  nanoplot ✅  porechop_abi ✅  filtlong ✅  bowtie2_host_removal ✅  minimap2_host_removal ✅
  Phase 2: megahit  flye  opera_ms  racon_medaka  nextpolish  quast
  Phase 3: align_reads_to_contigs  map_short_reads  map_long_reads  metabat2  maxbin2  semibin2  concoct  dastool  cat_bins  checkm2  gunc  gtdbtk
  Phase 4: kraken2  bracken  kraken_biom  krona  humann3
  Phase 5: multiqc  generate_reports

lib/
  Utils.groovy                   ← General helpers
  Samplesheet.groovy             ← CSV parsing + validation
  Validation.groovy              ← Pre-flight checks

bin/
  extract_nonhost.py             ← BAM → unmapped FASTQ
  kraken_to_biom.py              ← Kraken2 → BIOM
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

### ❌ Phases 2–5 — Not yet implemented

All remaining `.nf` module files, `.groovy`, `.py`, `.yaml`, `.config` files are **completely empty stubs**.

---

## Implementation Order (follow framework_plan.md §9)

Work through phases in order. Each phase depends on the previous.

---

### Phase 1 — Core Modules (`modules/local/`)

Implement these first — all downstream workflows depend on them.

| Module | File | What to Write |
|---|---|---|
| FastQC | `modules/local/fastqc/main.nf` | `process FASTQC` — run fastqc on paired FASTQ |
| Fastp | `modules/local/fastp/main.nf` | `process FASTP` — trim + filter short reads |
| Dorado | `modules/local/dorado_basecall/main.nf` | `process DORADO_BASECALL` — POD5 → FASTQ |
| NanoPlot | `modules/local/nanoplot/main.nf` | `process NANOPLOT` — long read QC plots |
| Porechop-ABI | `modules/local/porechop_abi/main.nf` | `process PORECHOP_ABI` — adapter trimming |
| Filtlong | `modules/local/filtlong/main.nf` | `process FILTLONG` — quality filter long reads |
| Bowtie2 | `modules/local/bowtie2_host_removal/main.nf` | `process BOWTIE2_HOST_REMOVAL` — map + extract unmapped |
| Minimap2 | `modules/local/minimap2_host_removal/main.nf` | `process MINIMAP2_HOST_REMOVAL` — long read host removal |

**After Phase 1**: Implement `workflows/preprocessing.nf` and `workflows/host_removal.nf`

---

### Phase 2 — Assembly Modules

| Module | File | What to Write |
|---|---|---|
| MEGAHIT | `modules/local/megahit/main.nf` | `process MEGAHIT` — Illumina assembly |
| Flye | `modules/local/flye/main.nf` | `process FLYE` — Nanopore assembly |
| Opera-MS | `modules/local/opera_ms/main.nf` | `process OPERA_MS` — hybrid assembly |
| Racon+Medaka | `modules/local/racon_medaka/main.nf` | `process RACON_MEDAKA` — long read polishing |
| NextPolish | `modules/local/nextpolish/main.nf` | `process NEXTPOLISH` — short read polishing |
| QUAST | `modules/local/quast/main.nf` | `process QUAST` — assembly QC |

**After Phase 2**: Implement `workflows/assembly.nf`, `polishing.nf`, `assembly_qc.nf`

---

### Phase 3 — MAG Reconstruction Modules

| Module | File | What to Write |
|---|---|---|
| map_short_reads | `modules/local/map_short_reads/main.nf` | `process MAP_SHORT_READS` |
| map_long_reads | `modules/local/map_long_reads/main.nf` | `process MAP_LONG_READS` |
| align_reads_to_contigs | `modules/local/align_reads_to_contigs/main.nf` | `process ALIGN_READS_TO_CONTIGS` — depth calc |
| MetaBAT2 | `modules/local/metabat2/main.nf` | `process METABAT2` |
| MaxBin2 | `modules/local/maxbin2/main.nf` | `process MAXBIN2` |
| SemiBin2 | `modules/local/semibin2/main.nf` | `process SEMIBIN2` |
| CONCOCT | `modules/local/concoct/main.nf` | `process CONCOCT` |
| DAS Tool | `modules/local/dastool/main.nf` | `process DASTOOL` — bin dereplication |
| cat_bins | `modules/local/cat_bins/main.nf` | `process CAT_BINS` — collect bin FASTAs |
| CheckM2 | `modules/local/checkm2/main.nf` | `process CHECKM2` |
| GUNC | `modules/local/gunc/main.nf` | `process GUNC` |
| GTDB-Tk | `modules/local/gtdbtk/main.nf` | `process GTDBTK` |

**After Phase 3**: Implement `workflows/mapping.nf`, `binning.nf`, `mag_qc.nf`

---

### Phase 4 — Read-Based Analysis Modules

| Module | File | What to Write |
|---|---|---|
| Kraken2 | `modules/local/kraken2/main.nf` | `process KRAKEN2` |
| Bracken | `modules/local/bracken/main.nf` | `process BRACKEN` |
| kraken_biom | `modules/local/kraken_biom/main.nf` | `process KRAKEN_BIOM` — report → BIOM |
| Krona | `modules/local/krona/main.nf` | `process KRONA` — interactive HTML |
| HUMAnN3 | `modules/local/humann3/main.nf` | `process HUMANN3` — functional profiling |

**After Phase 4**: Implement `workflows/assembly_free.nf`

---

### Phase 5 — Reporting Modules

| Module | File | What to Write |
|---|---|---|
| MultiQC | `modules/local/multiqc/main.nf` | `process MULTIQC` — aggregate QC |
| generate_reports | `modules/local/generate_reports/main.nf` | `process GENERATE_REPORTS` — calls bin/generate_report.py |

**After Phase 5**: Implement `workflows/annotation.nf`, `workflows/reporting.nf`

---

### Final Step — Wire Everything in main.nf

After all phases, implement `main.nf`:
- Include all 11 workflows
- Define input channels from samplesheet
- Connect workflows in correct order
- Add `Validation.run(params)` at startup

---

## Infrastructure Files to Implement

These should be implemented early (before any module work):

| File | What to Write |
|---|---|
| `lib/Validation.groovy` | Pre-flight param/file checks — implement first |
| `lib/Samplesheet.groovy` | CSV parser — implement before preprocessing |
| `lib/Utils.groovy` | Logging, path helpers — implement alongside |
| `conf/base.config` | Default CPUs, memory, retry, errorStrategy |
| `nextflow.config` | Load conf files, define profiles (slurm, singularity, docker, test) |
| `params/illumina.yaml` | Preset parameters for Illumina runs |
| `params/nanopore.yaml` | Preset parameters for Nanopore runs |
| `params/hybrid.yaml` | Preset parameters for hybrid runs |
| `params/databases.yaml` | Database path parameters |
| `conf/slurm.config` | executor=slurm, queue, retry, queueSize |
| `conf/singularity.config` | enabled=true, autoMounts, cacheDir, runOptions |
| `conf/docker.config` | enabled=true, userEmulation |
| `conf/test.config` | Small params, tiny input files |

---

## Key Architecture Decisions (Already Made)

| Decision | Value | Reason |
|---|---|---|
| DSL version | Nextflow DSL2 | Modular, reusable processes |
| HPC executor | SLURM | Production HPC target |
| Containers | Singularity (primary), Docker (local) | HPC compatibility |
| Assembler switching | Via `params.assembler` | Replaceability principle |
| Samplesheet format | CSV | Simple, widely supported |
| Channel format | `[meta, files]` tuple | nf-core standard |
| Param presets | YAML files in `params/` | Reproducibility |

---

## How the Next Agent Should Start

1. Read [`../../framework_plan.md`](../../framework_plan.md) for full spec
2. Read [`../../.agents/AGENTS.md`](../../.agents/AGENTS.md) for rules
3. Read this file for current state
4. Pick the **lowest numbered incomplete phase** above
5. Implement modules in that phase (one process block per file)
6. Implement the corresponding workflow after all modules in that phase are done
7. Update the status table below and this file's "Current Project State" section

---

## Phase Completion Status

| Phase | Modules Done | Workflow Done |
|---|---|---|
| 1 — Core | ✅ | ✅ |
| 2 — Assembly | ☐ | ☐ |
| 3 — MAG Reconstruction | ☐ | ☐ |
| 4 — Read-Based | ☐ | ☐ |
| 5 — Reporting | ☐ | ☐ |
| Infrastructure | ☐ | — |
| main.nf wiring | — | ☐ |

**Overall: ~15% implemented** (Phase 1 of 5 + 2 of 11 workflows)

---

## Update Log

| Date | Agent | Action |
|---|---|---|
| 2026-08-14 | Antigravity | Architecture scaffold created from framework_plan.md |
| 2026-08-14 | Antigravity | Unused modules deleted, all files wiped to empty stubs |
| 2026-08-14 | Antigravity | HANDOFF.md and .agents/AGENTS.md created |
| 2026-08-14 | Antigravity | Phase 1 implemented: 8 modules + preprocessing.nf + host_removal.nf |
