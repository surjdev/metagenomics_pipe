#!/usr/bin/env python3
"""
bin/kreport_to_krona.py — Convert Kraken2 report to Krona text input format
Extracts full taxonomic hierarchy (names) so Krona displays scientific names
instead of raw NCBI TaxIDs.
"""
import sys

def main():
    if len(sys.argv) < 3:
        print("Usage: kreport_to_krona.py <kraken_report> <krona_out.txt>", file=sys.stderr)
        sys.exit(1)

    report_file = sys.argv[1]
    out_file = sys.argv[2]

    lineage = []
    with open(report_file, 'r') as f_in, open(out_file, 'w') as f_out:
        for line in f_in:
            line = line.rstrip('\r\n')
            if not line:
                continue
            parts = line.split('\t')
            if len(parts) < 6:
                continue

            try:
                reads_direct = int(parts[2].strip())
            except ValueError:
                continue

            rank_code = parts[3].strip()
            name_raw = parts[5]

            # Handle unclassified reads
            if rank_code == 'U':
                if reads_direct > 0:
                    f_out.write(f"{reads_direct}\tUnclassified\n")
                continue

            # Calculate taxonomic depth based on leading spaces (2 spaces per depth level)
            leading_spaces = len(name_raw) - len(name_raw.lstrip(' '))
            depth = leading_spaces // 2
            name = name_raw.strip()

            # Skip empty names
            if not name:
                continue

            # Update lineage stack
            while len(lineage) > depth:
                lineage.pop()
            lineage.append(name)

            # Only output lines with direct reads
            if reads_direct > 0:
                lineage_str = "\t".join(lineage)
                f_out.write(f"{reads_direct}\t{lineage_str}\n")

if __name__ == '__main__':
    main()
