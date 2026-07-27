# metagenomics pipeline

A basic shotgun metagenomics pipeline. Python does the orchestration (config
parsing, logging, checkpointing, chaining inputs/outputs between steps) — all
of the actual bioinformatics is done by standard, established tools invoked
as subprocesses. No algorithms (alignment, classification, assembly) are
reimplemented in Python.

## Steps

| # | Step | Tool |
|---|------|------|
| 1 | Raw read QC | [FastQC](https://www.bioinformatics.babraham.ac.uk/projects/fastqc/) |
| 2 | Adapter/quality trimming | [fastp](https://github.com/OpenGene/fastp) |
| 3 | Host read removal (optional) | [Bowtie2](https://bowtie-bio.sourceforge.net/bowtie2/) |
| 4 | Taxonomic classification + abundance | [Kraken2](https://github.com/DerrickWood/kraken2) + [Bracken](https://github.com/jenniferlu717/Bracken) |
| 5 | De novo assembly (optional, off by default) | [MEGAHIT](https://github.com/voutcn/megahit) |
| 6 | Aggregate report | [MultiQC](https://multiqc.info/) |

Each step's inputs/outputs, thread count, and enable/disable flags are
configured in `config.yaml`. Steps are checkpointed (`results/.checkpoints/`)
so a re-run skips work that already completed.

## Install

Tools are external bioinformatics binaries, not pip packages. Easiest path
is conda/mamba:

```bash
conda env create -f environment.yml
conda activate metagenomics-pipe
```

You will also need, separately (not bundled — these are large downloads):

- A Kraken2 database (e.g. the prebuilt [Standard](https://benlangmead.github.io/aws-indexes/k2) or a custom one), matching Bracken files (`bracken-build` or prebuilt `.kmer_distrib`).
- If using host removal: a Bowtie2 index of the host genome (`bowtie2-build genome.fa host_index`).

## Usage

1. Fill in `samples.csv`:

   ```csv
   sample_id,fastq_1,fastq_2
   sample1,data/sample1_R1.fastq.gz,data/sample1_R2.fastq.gz
   ```

   Omit `fastq_2` for single-end reads.

2. Edit `config.yaml` — at minimum set `taxonomy.kraken2_db`, and
   `host_removal.host_index` if you enable host removal.

3. Preview the exact commands that will run, without executing anything:

   ```bash
   python3 run_pipeline.py --dry-run
   ```

4. Run it:

   ```bash
   python3 run_pipeline.py --config config.yaml
   ```

   Useful flags: `--sample <id>` (run one sample only), `--threads N`
   (override config), `--samples other.csv`.

Results land in `results/`: `01_fastqc/`, `02_trimmed/`, `03_host_removed/`,
`04_taxonomy/` (Kraken2 reports + Bracken abundance tables — the main
output of a basic run), `05_assembly/`, and `06_report/` (MultiQC HTML).

## Layout

```
pipeline/
  cli.py          argparse entrypoint
  config.py       config.yaml + samples.csv loading/validation
  runner.py       per-sample orchestration, checkpointing, tool-presence checks
  utils.py        subprocess runner, logging
  steps/          one module per tool (qc, trimming, host_removal, taxonomy, assembly, report)
config.yaml       example configuration
samples.csv       example sample manifest
environment.yml   conda spec for all external tools
```
