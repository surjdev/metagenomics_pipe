# MEMORY_HANDOFF_TEST_Meta_NPI.md — AI Memory & Handoff for Meta_NPI Testing

> **Purpose**: This memory document maintains the persistent state, metadata, and testing progress for running the **Hybrid Metagenomics Pipeline** on the real-world Oxford Nanopore `Meta_NPI/` dataset.
>
> **Source Data**: `Meta_NPI/1_basecalled_fastq/`
> **Plan Document**: [`PLAN_TEST_Meta_NPI.md`](PLAN_TEST_Meta_NPI.md)
> **Master Framework Plan**: [`framework_plan.md`](framework_plan.md)
> **Pipeline Handoff**: [`HANDOFF.md`](HANDOFF.md)

---

## 1. Dataset Index & File Catalog

All input FASTQ files are located under `/home/surj/Workspace/metagenomics-pipeline/Meta_NPI/1_basecalled_fastq/`.

| Sample / Barcode | FASTQ Filename | Reads | Size (MB) | Tier Assignment |
|---|---|---|---|---|
| `barcode01` | `PBG11387_pass_barcode01_877e2cf7_59b28c65_0.fastq` | 8,807 | 45.97 | Tier 2 (Benchmark) |
| `barcode02` | `PBG11387_pass_barcode02_877e2cf7_59b28c65_0.fastq` | 8 | 0.01 | Debug / Edge Case |
| `barcode09` | `PBG11387_pass_barcode09_877e2cf7_59b28c65_0.fastq` | 3 | 0.00 | Debug / Edge Case |
| `barcode11` | `PBG11387_pass_barcode11_877e2cf7_59b28c65_0.fastq` | 92 | 0.07 | Tier 1 (Light) |
| `barcode12` | `PBG11387_pass_barcode12_877e2cf7_59b28c65_0.fastq` | 133 | 0.09 | Tier 1 (Light) |
| `barcode13` | `PBG11387_pass_barcode13_877e2cf7_59b28c65_0.fastq` | 127 | 0.10 | Tier 1 (Light) |
| `barcode14` | `PBG11387_pass_barcode14_877e2cf7_59b28c65_0.fastq` | 320 | 0.22 | Tier 1 (Smoke Test) |
| `barcode15` | `PBG11387_pass_barcode15_877e2cf7_59b28c65_0.fastq` | 146 | 0.11 | Tier 1 (Light) |
| `barcode16` | `PBG11387_pass_barcode16_877e2cf7_59b28c65_0.fastq` | 414 | 0.30 | Tier 1 (Smoke Test) |
| `barcode17` | `PBG11387_pass_barcode17_877e2cf7_59b28c65_0.fastq` | 105 | 0.08 | Tier 1 (Light) |
| `barcode18` | `PBG11387_pass_barcode18_877e2cf7_59b28c65_0.fastq` | 5,499 | 15.85 | Tier 2 (Benchmark) |
| `barcode19` | `PBG11387_pass_barcode19_877e2cf7_59b28c65_0.fastq` | 3,779 | 28.74 | Tier 2 (Benchmark) |
| `barcode20` | `PBG11387_pass_barcode20_877e2cf7_59b28c65_0.fastq` | 6,150 | 35.94 | Tier 2 (Benchmark) |
| `barcode21` | `PBG11387_pass_barcode21_877e2cf7_59b28c65_0.fastq` | 6,921 | 42.93 | Tier 2 (Benchmark) |
| `barcode22` | `PBG11387_pass_barcode22_877e2cf7_59b28c65_0.fastq` | 4,380 | 21.88 | Tier 2 (Benchmark) |
| `barcode23` | `PBG11387_pass_barcode23_877e2cf7_59b28c65_0.fastq` | 5,950 | 37.05 | Tier 2 (Benchmark) |
| `barcode24` | `PBG11387_pass_barcode24_877e2cf7_59b28c65_0.fastq` | 3,034 | 19.12 | Tier 2 (Benchmark) |

---

## 2. Technical Profile & Biological Context

- **Sequencing Run ID**: `PBG11387`
- **Kit**: `SQK-RBK114-24` (Rapid Barcoding Kit 24)
- **Basecaller Model**: `dna_r10.4.1_e8.2_400bps_sup@v5.0.0` (Dorado Super Accuracy mode)
- **Mean Quality Score**: ~Q17.6
- **Sample Type**: Metagenomic community

---

## 3. Execution Tracking & Test Status

| Test ID | Barcodes Tested | Profile / Config | Date | Status | Key Outputs / Metrics |
|---|---|---|---|---|---|
| `PHASE-1` | All 17 Barcodes & Smoke Barcodes | CLI generator `bin/generate_samplesheet_meta_npi.py` | 2026-08-26 | ✅ Complete | `samplesheet_meta_npi_smoke.csv`, `samplesheet_meta_npi_full.csv` |
| `PHASE-2` | `barcode14`, `barcode16` | Nextflow DAG Compile / Preview | 2026-08-26 | ✅ Verified | Validated 11-stage long-read DAG in `main.nf` with `conf/meta_npi.config` |
| `TEST-NPI-001` | `barcode14`, `barcode16` | `local,test` (Nanopore Flye mode) | 2026-08-27 | ✅ Complete | Smoke test end-to-end execution |
| `TEST-NPI-002` | `barcode01`, `barcode21` | `local` + `conf/meta_npi.config` | Planned | ⏳ Pending | Deep Nanopore MAG assembly & binning |
| `TEST-NPI-003` | All 17 barcodes | `local` full run (`run_meta_npi.sh full`) | 2026-08-30 | ✅ Complete | 239 tasks succeeded (12m 33s). Results saved to `results_meta_npi_full/` |

---

## 4. Key Implementation Rules for Nanopore-Only Execution

1. **Samplesheet format**:
   Must have `sample` and `long_reads` columns:
   ```csv
   sample,long_reads
   barcode14,/absolute/path/to/Meta_NPI/1_basecalled_fastq/barcode14/PBG11387_pass_barcode14_877e2cf7_59b28c65_0.fastq
   ```
2. **Flye Assembly**:
   - `assembler = 'flye'`
   - `flye_mode = '--nano-hq'` (due to Dorado SUP Q17+ accuracy)
3. **Assembly-Free Profiling**:
   - Long reads flow directly into Kraken2/Krona/HUMAnN3 via `ch_clean_short.mix(ch_clean_long)`.
   - `KRAKEN2` supports single-end long reads natively.
4. **Binning on Long Reads**:
   - Minimap2 aligns long reads back to Flye contigs to create coverage BAM/BAI for MetaBAT2/SemiBin2.

---

## 5. Changelog & Update History

| Date | Agent | Action Description |
|---|---|---|
| 2026-08-26 | Antigravity | Created `PLAN_TEST_Meta_NPI.md` and `MEMORY_HANDOFF_TEST_Meta_NPI.md`. Analyzed all 17 barcode FASTQs in `Meta_NPI/`. |
| 2026-08-26 | Antigravity | Completed **Phase 1 & 2**: Built dynamic samplesheet CLI `bin/generate_samplesheet_meta_npi.py`, generated `samplesheet_meta_npi_smoke.csv` & `samplesheet_meta_npi_full.csv`, configured `conf/meta_npi.config`, updated `main.nf` long-read profiling routing, and validated Nextflow DAG preview. |
| 2026-08-27 | Antigravity | Created executable Bash automation runner `run_meta_npi.sh` (smoke, benchmark, full, dry-run, clean modes) and educational interactive Jupyter Notebook `notebooks/Meta_NPI_Workflow_Walkthrough.ipynb` with detailed 11-stage tool explanations and visualizations. |
| 2026-08-30 | Antigravity | Executed Full Mode analysis (`./run_meta_npi.sh full local`) across all 17 barcodes. All 239 processes completed successfully in 12m 33s. |
