#!/usr/bin/env python3
"""
bin/kraken_to_biom.py — Convert Kraken2 / Bracken reports to BIOM 1.0 JSON format.
Can also output a standard tab-delimited abundance TSV.
"""
import sys
import os
import argparse
import json

RANK_MAP = {
    'R': 'root',
    'D': 'd__',
    'K': 'k__',
    'P': 'p__',
    'C': 'c__',
    'O': 'o__',
    'F': 'f__',
    'G': 'g__',
    'S': 's__'
}

def parse_kraken_report(report_path):
    """
    Parses a Kraken2 report file into a list of taxon records.
    Report format:
      pct, reads_clade, reads_tax, rank_code, tax_id, name
    """
    records = []
    current_lineage = []
    
    with open(report_path, 'r') as f:
        for line in f:
            parts = line.strip().split('\t')
            if len(parts) < 6:
                continue
            pct = float(parts[0].strip())
            clade_reads = int(parts[1].strip())
            taxon_reads = int(parts[2].strip())
            rank_code = parts[3].strip()
            tax_id = parts[4].strip()
            name = parts[5]
            
            # Indentation in name indicates taxonomy depth
            depth = (len(name) - len(name.lstrip())) // 2
            clean_name = name.strip()
            
            # Maintain lineage stack
            while len(current_lineage) > depth:
                current_lineage.pop()
            
            prefix = RANK_MAP.get(rank_code[0].upper(), 'u__')
            current_lineage.append(f"{prefix}{clean_name}")
            
            full_lineage = ";".join(current_lineage)
            records.append({
                'tax_id': tax_id,
                'name': clean_name,
                'rank': rank_code,
                'clade_reads': clade_reads,
                'taxon_reads': taxon_reads,
                'lineage': full_lineage
            })
    return records

def write_biom_json(sample_records, output_path):
    """
    Writes BIOM 1.0 JSON format for multiple sample records.
    sample_records: dict of sample_id -> list of records
    """
    samples = list(sample_records.keys())
    
    # Collect all unique lineages/taxa
    taxa_set = {}
    for s, recs in sample_records.items():
        for r in recs:
            if r['taxon_reads'] > 0:
                tid = r['tax_id']
                if tid not in taxa_set:
                    taxa_set[tid] = {
                        'id': tid,
                        'metadata': {
                            'taxonomy': r['lineage'].split(';')
                        }
                    }
    
    rows = list(taxa_set.values())
    row_id_to_idx = {r['id']: i for i, r in enumerate(rows)}
    col_id_to_idx = {s: j for j, s in enumerate(samples)}
    
    data = []
    for s_id, recs in sample_records.items():
        col_idx = col_id_to_idx[s_id]
        for r in recs:
            if r['taxon_reads'] > 0 and r['tax_id'] in row_id_to_idx:
                row_idx = row_id_to_idx[r['tax_id']]
                data.append([row_idx, col_idx, r['taxon_reads']])
    
    biom_obj = {
        "id": "Kraken2/Bracken Abundance",
        "format": "Biological Observation Matrix 1.0.0",
        "format_url": "http://biom-format.org",
        "type": "Taxon table",
        "generated_by": "metagenomics_pipe (kraken_to_biom.py)",
        "date": "2026-08-17T00:00:00",
        "rows": rows,
        "columns": [{"id": s, "metadata": None} for s in samples],
        "matrix_type": "sparse",
        "matrix_element_type": "int",
        "shape": [len(rows), len(samples)],
        "data": data
    }
    
    with open(output_path, 'w') as f:
        json.dump(biom_obj, f, indent=2)
    print(f"BIOM written to: {output_path} ({len(rows)} taxa x {len(samples)} samples)")

def write_tsv(sample_records, output_path):
    samples = list(sample_records.keys())
    taxa_map = {}
    for s, recs in sample_records.items():
        for r in recs:
            tid = r['tax_id']
            if tid not in taxa_map:
                taxa_map[tid] = {'lineage': r['lineage'], 'counts': {}}
            taxa_map[tid]['counts'][s] = r['taxon_reads']
            
    with open(output_path, 'w') as f:
        header = ["#Taxon_ID", "Lineage"] + samples
        f.write("\t".join(header) + "\n")
        for tid, data in taxa_map.items():
            row = [tid, data['lineage']] + [str(data['counts'].get(s, 0)) for s in samples]
            f.write("\t".join(row) + "\n")
    print(f"TSV written to: {output_path}")

def main():
    parser = argparse.ArgumentParser(description="Convert Kraken2 reports to BIOM / TSV")
    parser.add_argument("reports", nargs="+", help="Input Kraken2 report file(s)")
    parser.add_argument("-o", "--output", default="taxonomy.biom", help="Output BIOM path")
    parser.add_argument("-t", "--tsv", default=None, help="Optional output TSV path")
    parser.add_argument("-s", "--samples", nargs="*", help="Sample IDs matching reports")
    args = parser.parse_args()

    sample_records = {}
    for i, report_file in enumerate(args.reports):
        if args.samples and i < len(args.samples):
            s_name = args.samples[i]
        else:
            s_name = os.path.basename(report_file).split('.')[0].replace('_kraken2_report', '').replace('_report', '')
        sample_records[s_name] = parse_kraken_report(report_file)

    write_biom_json(sample_records, args.output)
    if args.tsv:
        write_tsv(sample_records, args.tsv)

if __name__ == "__main__":
    main()
