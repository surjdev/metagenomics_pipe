"""Optional de novo assembly via MEGAHIT."""
from __future__ import annotations

import shutil
from pathlib import Path

from ..config import Sample
from ..utils import run_cmd

TOOLS = ["megahit"]


def run(
    sample: Sample,
    fastq_1: Path,
    fastq_2: Path | None,
    out_dir: Path,
    min_contig_len: int,
    threads: int,
    dry_run: bool,
) -> Path:
    step_dir = out_dir / "05_assembly" / sample.sample_id
    # megahit refuses to run if its output directory already exists.
    if step_dir.exists() and not dry_run:
        shutil.rmtree(step_dir)

    cmd = [
        "megahit",
        "-t", str(threads),
        "--min-contig-len", str(min_contig_len),
        "-o", str(step_dir),
    ]
    if fastq_2:
        cmd += ["-1", str(fastq_1), "-2", str(fastq_2)]
    else:
        cmd += ["-r", str(fastq_1)]

    log_dir = out_dir / "05_assembly"
    run_cmd(cmd, log_dir / f"{sample.sample_id}.megahit.log", dry_run=dry_run)
    return step_dir / "final.contigs.fa"
