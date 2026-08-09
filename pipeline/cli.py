"""Command-line entrypoint: python -m pipeline.cli run --config config.yaml"""
from __future__ import annotations

import argparse
import logging
import sys
from pathlib import Path

from .config import load_config, load_samples
from .runner import run_pipeline
from .utils import setup_logging

logger = logging.getLogger("metagenomics_pipe")


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(
        prog="metagenomics-pipe",
        description="Basic shotgun metagenomics pipeline (QC -> trim -> host removal -> "
        "taxonomic classification -> optional assembly -> report).",
    )
    parser.add_argument("--config", type=Path, default=Path("config.yaml"), help="Path to config.yaml")
    parser.add_argument("--samples", type=Path, default=None, help="Override samples CSV from config")
    parser.add_argument("--threads", type=int, default=None, help="Override thread count from config")
    parser.add_argument("--sample", type=str, default=None, help="Run only this sample_id")
    parser.add_argument("--dry-run", action="store_true", help="Print commands without executing them")
    return parser


def main(argv: list[str] | None = None) -> int:
    parser = build_parser()
    args = parser.parse_args(argv)

    setup_logging()
    try:
        cfg = load_config(args.config)
        if args.threads:
            cfg["threads"] = args.threads

        samples_path = args.samples or Path(cfg["samples"])
        samples = load_samples(samples_path)

        out_dir = Path(cfg["output_dir"])
        if not args.dry_run:
            setup_logging(out_dir / "pipeline.log")

        run_pipeline(cfg, samples, dry_run=args.dry_run, only_sample=args.sample)
    except Exception as exc:  # noqa: BLE001
        logger.error(str(exc))
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
