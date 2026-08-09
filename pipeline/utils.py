"""Shared helpers: subprocess execution, logging, checkpointing, tool checks."""
from __future__ import annotations

import logging
import shutil
import subprocess
import sys
from pathlib import Path

logger = logging.getLogger("metagenomics_pipe")


def setup_logging(log_file: Path | None = None) -> None:
    handlers = [logging.StreamHandler(sys.stdout)]
    if log_file is not None:
        log_file.parent.mkdir(parents=True, exist_ok=True)
        handlers.append(logging.FileHandler(log_file))
    logging.basicConfig(
        level=logging.INFO,
        format="%(asctime)s [%(levelname)s] %(message)s",
        datefmt="%H:%M:%S",
        handlers=handlers,
        force=True,
    )


def require_tools(tool_names: list[str]) -> None:
    """Fail fast with a clear message if any required binary is missing from PATH."""
    missing = [t for t in tool_names if shutil.which(t) is None]
    if missing:
        raise RuntimeError(
            "Missing required tool(s) on PATH: "
            + ", ".join(missing)
            + ". Install them (see environment.yml) before running the pipeline."
        )


def run_cmd(cmd: list[str], log_file: Path, dry_run: bool = False) -> None:
    """Run a command, streaming output to both the console and a per-step log file."""
    printable = " ".join(str(c) for c in cmd)
    logger.info("$ %s", printable)
    if dry_run:
        return

    log_file.parent.mkdir(parents=True, exist_ok=True)
    with open(log_file, "w") as fh:
        fh.write(f"$ {printable}\n\n")
        fh.flush()
        result = subprocess.run(cmd, stdout=fh, stderr=subprocess.STDOUT)
    if result.returncode != 0:
        raise RuntimeError(
            f"Command failed (exit {result.returncode}): {printable}\nSee log: {log_file}"
        )


def is_done(marker: Path) -> bool:
    return marker.exists()


def mark_done(marker: Path) -> None:
    marker.parent.mkdir(parents=True, exist_ok=True)
    marker.touch()
