"""Adapter/quality trimming via fastp."""
from __future__ import annotations

import shlex
from pathlib import Path

from ..config import Sample
from ..utils import run_cmd

TOOLS = ["fastp"]


def run(sample: Sample, out_dir: Path, threads: int, extra_args: str, dry_run: bool) -> tuple[Path, Path | None]:
    step_dir = out_dir / "02_trimmed"
    step_dir.mkdir(parents=True, exist_ok=True)

    out_1 = step_dir / f"{sample.sample_id}_R1.trimmed.fastq.gz"
    out_2 = step_dir / f"{sample.sample_id}_R2.trimmed.fastq.gz" if sample.fastq_2 else None

    cmd = [
        "fastp",
        "-i", str(sample.fastq_1),
        "-o", str(out_1),
        "-w", str(threads),
        "-j", str(step_dir / f"{sample.sample_id}.fastp.json"),
        "-h", str(step_dir / f"{sample.sample_id}.fastp.html"),
    ]
    if sample.fastq_2:
        cmd += ["-I", str(sample.fastq_2), "-O", str(out_2)]
    if extra_args:
        cmd += shlex.split(extra_args)

    run_cmd(cmd, step_dir / f"{sample.sample_id}.fastp.log", dry_run=dry_run)
    return out_1, out_2
