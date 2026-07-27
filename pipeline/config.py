"""Config loading and sample manifest parsing."""
from __future__ import annotations

import csv
from dataclasses import dataclass
from pathlib import Path

import yaml


@dataclass
class Sample:
    sample_id: str
    fastq_1: Path
    fastq_2: Path | None  # None for single-end


def load_config(path: Path) -> dict:
    with open(path) as fh:
        cfg = yaml.safe_load(fh)

    cfg.setdefault("output_dir", "results")
    cfg.setdefault("threads", 4)
    cfg.setdefault("qc", {}).setdefault("enabled", True)
    cfg.setdefault("trimming", {}).setdefault("enabled", True)
    cfg.setdefault("host_removal", {}).setdefault("enabled", False)
    cfg.setdefault("taxonomy", {}).setdefault("enabled", True)
    cfg.setdefault("assembly", {}).setdefault("enabled", False)
    cfg.setdefault("report", {}).setdefault("enabled", True)

    if cfg["host_removal"].get("enabled") and not cfg["host_removal"].get("host_index"):
        raise ValueError("host_removal.enabled is true but host_removal.host_index is not set")
    if cfg["taxonomy"].get("enabled") and not cfg["taxonomy"].get("kraken2_db"):
        raise ValueError("taxonomy.enabled is true but taxonomy.kraken2_db is not set")

    return cfg


def load_samples(path: Path) -> list[Sample]:
    samples = []
    with open(path, newline="") as fh:
        reader = csv.DictReader(fh)
        required = {"sample_id", "fastq_1"}
        if not required.issubset(reader.fieldnames or []):
            raise ValueError(f"{path} must have columns: sample_id, fastq_1[, fastq_2]")
        for row in reader:
            fq2 = row.get("fastq_2") or None
            samples.append(
                Sample(
                    sample_id=row["sample_id"].strip(),
                    fastq_1=Path(row["fastq_1"].strip()),
                    fastq_2=Path(fq2.strip()) if fq2 else None,
                )
            )
    if not samples:
        raise ValueError(f"No samples found in {path}")
    return samples
