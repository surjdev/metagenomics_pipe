"""Aggregate all tool logs/reports into a single MultiQC report."""
from __future__ import annotations

from pathlib import Path

from ..utils import run_cmd

TOOLS = ["multiqc"]


def run(out_dir: Path, dry_run: bool) -> None:
    cmd = ["multiqc", str(out_dir), "-o", str(out_dir / "06_report"), "-f"]
    run_cmd(cmd, out_dir / "06_report" / "multiqc.log", dry_run=dry_run)
