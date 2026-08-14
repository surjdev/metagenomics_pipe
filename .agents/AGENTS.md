# Hybrid Metagenomics Nextflow DSL2 — Agent Rules

## What This Project Is

A **Nextflow DSL2 software framework** that orchestrates bioinformatics tools into reproducible metagenomics workflows. It is **not** a collection of scripts — it is a layered framework with strict boundaries between layers.

Source of truth for all architecture decisions: [`framework_plan.md`](../framework_plan.md)

---

## Project Location

```
d:/workspace/metagenomic_workflow/metagenomics_pipe/
```

Current state handoff document: [`metagenomics_pipe/HANDOFF.md`](../metagenomics_pipe/HANDOFF.md)

---

## 5-Layer Architecture — MEMORIZE THIS

```
Application Layer    →  main.nf                      (orchestrates only)
Workflow Layer       →  workflows/*.nf               (connects modules)
Module Layer         →  modules/local/<tool>/main.nf (one tool = one module)
Script Layer         →  lib/*.groovy  bin/*.py        (helpers only)
Infrastructure       →  conf/*.config  params/*.yaml  (no bio logic)
```

### Layer Boundary Rules (NEVER violate)

| File | May call | May NOT call |
|---|---|---|
| `main.nf` | `workflows/` only | modules, shell commands |
| `workflows/*.nf` | `modules/` only | shell commands, other workflows directly |
| `modules/*/main.nf` | Shell/tool only | other modules, workflows |
| `lib/*.groovy` | Groovy stdlib only | Nextflow DSL, shell |
| `bin/*.py` | Python/R stdlib only | Nextflow channels |

---

## Coding Conventions

- **Module process names**: `UPPERCASE` (e.g. `process FASTQC`)
- **Workflow names**: `lowercase_with_underscores`
- **Groovy classes**: `PascalCase`, methods `camelCase`
- **No hardcoded paths** anywhere in `.nf` files — always use `params.*`
- **One module = one tool, nothing else**
- **Params always defined** in `params/*.yaml`, never inline

---

## Directory Map (Quick Reference)

| Path | Layer | Purpose |
|---|---|---|
| `main.nf` | Application | Entry point, orchestrates workflows |
| `nextflow.config` | Infrastructure | Global runtime config |
| `conf/` | Infrastructure | Environment configs (slurm, singularity, docker, test) |
| `params/` | Infrastructure | Parameter presets (illumina, nanopore, hybrid, databases) |
| `workflows/` | Workflow | 11 pipeline stage orchestrators |
| `modules/local/` | Module | 35 single-tool process modules |
| `lib/` | Script | Groovy helpers (Utils, Samplesheet, Validation) |
| `bin/` | Script | Python scripts called by modules |
| `templates/` | Script | Report templates (Jinja2) |
| `assets/` | Static | Logo, CSS, config files |
| `docs/` | Documentation | User and developer docs |
| `test/` | Testing | Tiny datasets for CI |
| `databases/` | Infrastructure | DB download scripts (no DB files committed) |

---

## The 11 Workflows and Their Tools

| Workflow | Tools Used |
|---|---|
| `preprocessing.nf` | FastQC, Fastp, NanoPlot, Dorado, Porechop-ABI, Filtlong, MultiQC |
| `host_removal.nf` | Bowtie2 (short reads), Minimap2 (long reads) |
| `assembly.nf` | MEGAHIT, Flye, Opera-MS (chosen by `params.assembler`) |
| `polishing.nf` | Racon/Medaka, NextPolish |
| `assembly_qc.nf` | QUAST |
| `mapping.nf` | map_short_reads, map_long_reads, align_reads_to_contigs |
| `binning.nf` | MetaBAT2, MaxBin2, SemiBin2, CONCOCT, DAS Tool, cat_bins |
| `mag_qc.nf` | CheckM2, GUNC, GTDB-Tk |
| `annotation.nf` | Prokka, geNomad |
| `assembly_free.nf` | Kraken2, Bracken, kraken_biom, Krona, HUMAnN3 |
| `reporting.nf` | MultiQC, generate_reports, bin/generate_report.py |

---

## The 3 Groovy Helpers in lib/

| File | Responsibility |
|---|---|
| `Utils.groovy` | Filename utils, logging, path helpers, formatting |
| `Samplesheet.groovy` | Parse CSV, validate paired-end, return channel items |
| `Validation.groovy` | Pre-flight checks: files exist, DBs set, params in range, no duplicates |

---

## Development Phases (from framework_plan.md §9)

| Phase | Modules | Status |
|---|---|---|
| 1 — Core | FastQC, Fastp, Dorado, NanoPlot, Porechop, Filtlong, Bowtie2, Minimap2 | Stub only |
| 2 — Assembly | MEGAHIT, Flye, Opera-MS, Racon, Medaka, NextPolish, QUAST | Stub only |
| 3 — MAG | Mapping, MetaBAT2, MaxBin2, SemiBin2, CONCOCT, DAS Tool, CheckM2, GUNC, GTDB-Tk | Stub only |
| 4 — Read-Based | Kraken2, Bracken, Krona, HUMAnN3 | Stub only |
| 5 — Reporting | MultiQC, HTML, PDF, visualizations | Stub only |

---

## Rules for AI Agents Working on This Project

1. **Always read `HANDOFF.md` first** before doing any work.
2. **Always check `framework_plan.md`** before adding new files — if it's not in the spec, don't add it.
3. **Never add code to files unless explicitly asked** — architecture-only tasks create empty stubs.
4. **Never merge layers** — workflows call modules, not shell. Modules run shell, not other modules.
5. **Update `HANDOFF.md`** after completing any work phase.
6. **One module = one tool** — never combine two tools into one `main.nf`.
7. **Container image must be pinned** — always use `toolname:1.0.0`, never `toolname:latest`.
8. **No hardcoded paths** — use `params.*` for all database and file paths.

---

## How to Add a New Module (Quick Reference)

```
1. Create modules/local/<toolname>/main.nf    ← empty or process block
2. Add module to the relevant workflow in workflows/
3. Add any new params to params/illumina.yaml, nanopore.yaml, hybrid.yaml
4. Add container to nextflow.config or conf/singularity.config
5. Update HANDOFF.md with the new module status
```

## How to Implement a Workflow (Quick Reference)

```
1. Open workflows/<workflow>.nf
2. Include modules at top: include { TOOLNAME } from '../modules/local/toolname/main.nf'
3. Define workflow block with input channels → tool calls → output channels
4. Wire into main.nf with include + call
5. Update HANDOFF.md
```
