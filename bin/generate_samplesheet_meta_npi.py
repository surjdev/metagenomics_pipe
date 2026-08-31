#!/usr/bin/env python3
"""
bin/generate_samplesheet_meta_npi.py
Helper script to discover FASTQ files in Meta_NPI/1_basecalled_fastq/ and generate Nextflow samplesheets.
"""

import argparse
import glob
import os
import sys

def main():
    parser = argparse.ArgumentParser(description="Generate samplesheet for Meta_NPI dataset")
    parser.add_argument("--data-dir", default="Meta_NPI/1_basecalled_fastq", help="Path to basecalled fastq directory")
    parser.add_argument("--out", "-o", default="samplesheet_meta_npi.csv", help="Output CSV path")
    parser.add_argument("--min-reads", type=int, default=0, help="Minimum read count to include sample")
    parser.add_argument("--barcodes", nargs="*", help="Specific barcode list to include (e.g. barcode01 barcode14)")
    parser.add_argument("--tier", choices=["all", "smoke", "benchmark"], default="all", help="Preset tier selection")

    args = parser.parse_args()

    data_dir = os.path.abspath(args.data_dir)
    if not os.path.isdir(data_dir):
        print(f"Error: Directory '{data_dir}' not found.", file=sys.stderr)
        sys.exit(1)

    tier_map = {
        "smoke": ["barcode14", "barcode16"],
        "benchmark": ["barcode01", "barcode18", "barcode19", "barcode20", "barcode21", "barcode22", "barcode23", "barcode24"]
    }

    selected_barcodes = set(args.barcodes) if args.barcodes else None
    if args.tier in tier_map:
        selected_barcodes = set(tier_map[args.tier])

    fastq_pattern = os.path.join(data_dir, "barcode*", "*.fastq")
    fastq_files = sorted(glob.glob(fastq_pattern))

    rows = []
    print(f"Scanning '{data_dir}'...")

    for fq in fastq_files:
        if ".ipynb_checkpoints" in fq:
            continue
        barcode = os.path.basename(os.path.dirname(fq))

        if selected_barcodes and barcode not in selected_barcodes:
            continue

        # Count reads
        with open(fq, "rb") as fp:
            line_count = sum(1 for _ in fp)
        reads = line_count // 4

        if reads < args.min_reads:
            continue

        rows.append((barcode, fq, reads))

    print(f"Writing {len(rows)} samples to '{args.out}'...")
    with open(args.out, "w") as out_fp:
        out_fp.write("sample,long_reads\n")
        for barcode, fq_path, reads in sorted(rows, key=lambda x: x[0]):
            out_fp.write(f"{barcode},{fq_path}\n")
            print(f"  - {barcode:12s} ({reads:6d} reads) -> {fq_path}")

    print(f"\nDone! Successfully generated {args.out}")

if __name__ == "__main__":
    main()
