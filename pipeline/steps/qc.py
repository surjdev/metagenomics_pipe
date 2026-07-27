"""Raw read QC via FastQC."""
from __future__ import annotations

from pathlib import Path

from ..config import Sample
from ..utils import run_cmd

TOOLS = ["fastqc"]


def run(sample: Sample, out_dir: Path, threads: int, dry_run: bool) -> None:
    step_dir = out_dir / "01_fastqc" / sample.sample_id
    step_dir.mkdir(parents=True, exist_ok=True)

    reads = [str(sample.fastq_1)]
    if sample.fastq_2:
        reads.append(str(sample.fastq_2))

    cmd = ["fastqc", "-o", str(step_dir), "-t", str(threads), *reads]
    run_cmd(cmd, step_dir / "fastqc.log", dry_run=dry_run)
