"""Per-sample orchestration: runs each enabled step in sequence, with resume support."""
from __future__ import annotations

import logging
from pathlib import Path

from .config import Sample
from .steps import assembly, host_removal, qc, report, taxonomy, trimming
from .utils import is_done, mark_done, require_tools

logger = logging.getLogger("metagenomics_pipe")


def required_tools(cfg: dict) -> list[str]:
    tools: list[str] = []
    if cfg["qc"]["enabled"]:
        tools += qc.TOOLS
    if cfg["trimming"]["enabled"]:
        tools += trimming.TOOLS
    if cfg["host_removal"]["enabled"]:
        tools += host_removal.TOOLS
    if cfg["taxonomy"]["enabled"]:
        tools += taxonomy.TOOLS
    if cfg["assembly"]["enabled"]:
        tools += assembly.TOOLS
    if cfg["report"]["enabled"]:
        tools += report.TOOLS
    return sorted(set(tools))


def run_sample(sample: Sample, cfg: dict, out_dir: Path, dry_run: bool) -> None:
    threads = cfg["threads"]
    checkpoints = out_dir / ".checkpoints" / sample.sample_id
    logger.info("=== Sample: %s ===", sample.sample_id)

    if cfg["qc"]["enabled"]:
        marker = checkpoints / "qc.done"
        if is_done(marker):
            logger.info("[%s] qc already done, skipping", sample.sample_id)
        else:
            qc.run(sample, out_dir, threads, dry_run)
            if not dry_run:
                mark_done(marker)

    fastq_1, fastq_2 = sample.fastq_1, sample.fastq_2

    if cfg["trimming"]["enabled"]:
        marker = checkpoints / "trimming.done"
        trimmed_1 = out_dir / "02_trimmed" / f"{sample.sample_id}_R1.trimmed.fastq.gz"
        trimmed_2 = out_dir / "02_trimmed" / f"{sample.sample_id}_R2.trimmed.fastq.gz" if sample.fastq_2 else None
        if is_done(marker):
            logger.info("[%s] trimming already done, skipping", sample.sample_id)
            fastq_1, fastq_2 = trimmed_1, trimmed_2
        else:
            fastq_1, fastq_2 = trimming.run(
                sample, out_dir, threads, cfg["trimming"].get("extra_args", ""), dry_run
            )
            if not dry_run:
                mark_done(marker)

    if cfg["host_removal"]["enabled"]:
        marker = checkpoints / "host_removal.done"
        clean_1 = out_dir / "03_host_removed" / f"{sample.sample_id}_unmapped_1.fastq.gz"
        clean_2 = out_dir / "03_host_removed" / f"{sample.sample_id}_unmapped_2.fastq.gz" if fastq_2 else None
        if is_done(marker):
            logger.info("[%s] host_removal already done, skipping", sample.sample_id)
            fastq_1, fastq_2 = clean_1, clean_2
        else:
            fastq_1, fastq_2 = host_removal.run(
                sample, fastq_1, fastq_2, out_dir,
                cfg["host_removal"]["host_index"], threads, dry_run,
            )
            if not dry_run:
                mark_done(marker)

    if cfg["taxonomy"]["enabled"]:
        marker = checkpoints / "taxonomy.done"
        if is_done(marker):
            logger.info("[%s] taxonomy already done, skipping", sample.sample_id)
        else:
            tax_cfg = cfg["taxonomy"]
            taxonomy.run(
                sample, fastq_1, fastq_2, out_dir,
                tax_cfg["kraken2_db"], tax_cfg["confidence"],
                tax_cfg["bracken_read_len"], tax_cfg["bracken_level"],
                threads, dry_run,
            )
            if not dry_run:
                mark_done(marker)

    if cfg["assembly"]["enabled"]:
        marker = checkpoints / "assembly.done"
        if is_done(marker):
            logger.info("[%s] assembly already done, skipping", sample.sample_id)
        else:
            assembly.run(
                sample, fastq_1, fastq_2, out_dir,
                cfg["assembly"]["min_contig_len"], threads, dry_run,
            )
            if not dry_run:
                mark_done(marker)


def run_pipeline(cfg: dict, samples: list[Sample], dry_run: bool = False, only_sample: str | None = None) -> None:
    out_dir = Path(cfg["output_dir"])
    out_dir.mkdir(parents=True, exist_ok=True)

    if not dry_run:
        require_tools(required_tools(cfg))

    selected = [s for s in samples if only_sample is None or s.sample_id == only_sample]
    if not selected:
        raise ValueError(f"No sample matching '{only_sample}' found in manifest")

    for sample in selected:
        run_sample(sample, cfg, out_dir, dry_run)

    if cfg["report"]["enabled"]:
        report.run(out_dir, dry_run)

    logger.info("Pipeline finished. Results in %s", out_dir)
