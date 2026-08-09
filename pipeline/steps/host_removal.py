"""Host decontamination via Bowtie2: keep only reads that do NOT map to the host genome."""
from __future__ import annotations

from pathlib import Path

from ..config import Sample
from ..utils import run_cmd

TOOLS = ["bowtie2"]


def run(
    sample: Sample,
    fastq_1: Path,
    fastq_2: Path | None,
    out_dir: Path,
    host_index: str,
    threads: int,
    dry_run: bool,
) -> tuple[Path, Path | None]:
    step_dir = out_dir / "03_host_removed"
    step_dir.mkdir(parents=True, exist_ok=True)

    cmd = [
        "bowtie2",
        "-x", host_index,
        "-p", str(threads),
        "--very-fast",
    ]
    if fastq_2:
        unmapped_pattern = step_dir / f"{sample.sample_id}_unmapped_%.fastq.gz"
        cmd += ["-1", str(fastq_1), "-2", str(fastq_2), "--un-conc-gz", str(unmapped_pattern)]
        out_1 = step_dir / f"{sample.sample_id}_unmapped_1.fastq.gz"
        out_2 = step_dir / f"{sample.sample_id}_unmapped_2.fastq.gz"
    else:
        unmapped = step_dir / f"{sample.sample_id}_unmapped.fastq.gz"
        cmd += ["-U", str(fastq_1), "--un-gz", str(unmapped)]
        out_1, out_2 = unmapped, None

    cmd += ["-S", "/dev/null"]

    run_cmd(cmd, step_dir / f"{sample.sample_id}.bowtie2.log", dry_run=dry_run)
    return out_1, out_2
