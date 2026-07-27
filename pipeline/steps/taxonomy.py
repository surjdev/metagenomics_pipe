"""Taxonomic classification (Kraken2) and abundance re-estimation (Bracken)."""
from __future__ import annotations

from pathlib import Path

from ..config import Sample
from ..utils import run_cmd

TOOLS = ["kraken2", "bracken"]


def run(
    sample: Sample,
    fastq_1: Path,
    fastq_2: Path | None,
    out_dir: Path,
    kraken2_db: str,
    confidence: float,
    bracken_read_len: int,
    bracken_level: str,
    threads: int,
    dry_run: bool,
) -> None:
    step_dir = out_dir / "04_taxonomy"
    step_dir.mkdir(parents=True, exist_ok=True)

    kraken_report = step_dir / f"{sample.sample_id}.kraken2.report"
    kraken_output = step_dir / f"{sample.sample_id}.kraken2.output"

    cmd = [
        "kraken2",
        "--db", kraken2_db,
        "--threads", str(threads),
        "--confidence", str(confidence),
        "--report", str(kraken_report),
        "--output", str(kraken_output),
        "--gzip-compressed",
    ]
    if fastq_2:
        cmd += ["--paired", str(fastq_1), str(fastq_2)]
    else:
        cmd += [str(fastq_1)]

    run_cmd(cmd, step_dir / f"{sample.sample_id}.kraken2.log", dry_run=dry_run)

    bracken_output = step_dir / f"{sample.sample_id}.bracken"
    bracken_report = step_dir / f"{sample.sample_id}.bracken.report"
    bracken_cmd = [
        "bracken",
        "-d", kraken2_db,
        "-i", str(kraken_report),
        "-o", str(bracken_output),
        "-w", str(bracken_report),
        "-r", str(bracken_read_len),
        "-l", bracken_level,
    ]
    run_cmd(bracken_cmd, step_dir / f"{sample.sample_id}.bracken.log", dry_run=dry_run)
