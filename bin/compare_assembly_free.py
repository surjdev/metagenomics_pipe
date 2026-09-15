#!/usr/bin/env python3
"""
bin/compare_assembly_free.py — Short-Read vs Long-Read Assembly-Free Comparison Engine
Evaluates and benchmarks taxonomic and abundance profiles between paired
Short Reads (Illumina) and Long Reads (Oxford Nanopore):
- Read classification rate (% Classified vs % Unclassified)
- Taxonomic richness across ranks (Phylum, Genus, Species)
- Taxonomic concordance & overlap (Shared, Unique, Jaccard Similarity Index)
- Abundance correlation (Pearson r and Spearman rho on relative abundances)
- Top differential taxa matrix (delta abundance between Short vs Long)

Generates:
1. assembly_free_comparison_summary.tsv
2. species_abundance_comparison.tsv
3. genus_abundance_comparison.tsv
4. top_taxa_comparison.tsv
5. assembly_free_comparison.md
6. assembly_free_comparison.html
"""

import sys
import os
import re
import math
import argparse
from collections import OrderedDict

def parse_sample_id(filepath, platform_type=None):
    """Extract sample name by stripping platform and kraken suffixes."""
    base = os.path.basename(filepath)
    # Remove extensions
    base = re.sub(r'(\.txt|\.tsv|\.report)$', '', base)
    # Remove kraken2 report suffixes
    base = re.sub(r'(_kraken2_report|_bracken_report|\.report|_report)$', '', base)
    # Remove platform suffixes
    if platform_type == 'short':
        base = re.sub(r'(_short|_illumina|_sr|_paired|_s)$', '', base)
    elif platform_type == 'long':
        base = re.sub(r'(_long|_nanopore|_ont|_lr|_l)$', '', base)
    else:
        base = re.sub(r'(_short|_long|_illumina|_nanopore|_ont|_sr|_lr|_paired|_s|_l)$', '', base)
    return base

def parse_kraken_report(report_path):
    """
    Parses a Kraken2 report file into structured taxonomic data.
    Format: %_fragments \t clade_frags \t direct_frags \t rank_code \t taxid \t name
    """
    res = {
        'total_reads': 0,
        'unclassified_reads': 0,
        'unclassified_pct': 0.0,
        'classified_reads': 0,
        'classified_pct': 0.0,
        'taxa': {
            'D': {},  # Domain
            'P': {},  # Phylum
            'C': {},  # Class
            'O': {},  # Order
            'F': {},  # Family
            'G': {},  # Genus
            'S': {}   # Species
        }
    }
    if not report_path or not os.path.exists(report_path):
        return res

    try:
        with open(report_path, 'r', encoding='utf-8') as f:
            for line in f:
                line = line.rstrip('\r\n')
                if not line:
                    continue
                parts = line.split('\t')
                if len(parts) < 6:
                    continue

                try:
                    pct = float(parts[0].strip())
                    clade_reads = int(parts[1].strip())
                    direct_reads = int(parts[2].strip())
                    rank_code = parts[3].strip()
                    taxid = parts[4].strip()
                    name = parts[5].strip()
                except (ValueError, IndexError):
                    continue

                if rank_code == 'U':
                    res['unclassified_reads'] = clade_reads
                    res['unclassified_pct'] = pct
                elif rank_code == 'R':
                    res['classified_reads'] = clade_reads
                    res['classified_pct'] = pct
                elif rank_code in res['taxa']:
                    # Only record taxa with > 0 reads
                    if clade_reads > 0:
                        res['taxa'][rank_code][name] = {
                            'taxid': taxid,
                            'clade_reads': clade_reads,
                            'direct_reads': direct_reads,
                            'pct': pct
                        }

        res['total_reads'] = res['unclassified_reads'] + res['classified_reads']
        if res['total_reads'] > 0:
            res['unclassified_pct'] = round((res['unclassified_reads'] / res['total_reads']) * 100.0, 2)
            res['classified_pct'] = round((res['classified_reads'] / res['total_reads']) * 100.0, 2)
    except Exception as e:
        print(f"[WARN] Error reading Kraken2 report {report_path}: {e}", file=sys.stderr)

    return res

def compute_pearson(x_vals, y_vals):
    """Compute Pearson correlation coefficient."""
    n = len(x_vals)
    if n < 2:
        return 0.0
    sum_x = sum(x_vals)
    sum_y = sum(y_vals)
    mean_x = sum_x / n
    mean_y = sum_y / n

    cov = sum((x - mean_x) * (y - mean_y) for x, y in zip(x_vals, y_vals))
    var_x = sum((x - mean_x) ** 2 for x in x_vals)
    var_y = sum((y - mean_y) ** 2 for y in y_vals)

    denom = math.sqrt(var_x * var_y)
    if denom == 0.0:
        return 0.0
    return round(cov / denom, 4)

def compute_spearman(x_vals, y_vals):
    """Compute Spearman rank correlation coefficient."""
    n = len(x_vals)
    if n < 2:
        return 0.0

    def get_ranks(seq):
        indexed = sorted(enumerate(seq), key=lambda x: x[1])
        ranks = [0.0] * n
        i = 0
        while i < n:
            j = i
            while j < n - 1 and indexed[j][1] == indexed[j + 1][1]:
                j += 1
            avg_rank = (i + j + 2) / 2.0
            for k in range(i, j + 1):
                ranks[indexed[k][0]] = avg_rank
            i = j + 1
        return ranks

    rank_x = get_ranks(x_vals)
    rank_y = get_ranks(y_vals)
    return compute_pearson(rank_x, rank_y)

def generate_html_report(out_html_path, summary_data, top_taxa_data, samples):
    """Generates a standalone, beautiful HTML comparison report."""
    html_content = f"""<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1.0">
<title>Short vs Long Metagenomics Comparison Report</title>
<style>
  :root {{
    --bg-main: #0f172a;
    --card-bg: #1e293b;
    --card-border: #334155;
    --text-primary: #f8fafc;
    --text-secondary: #94a3b8;
    --accent-short: #38bdf8;
    --accent-long: #f59e0b;
    --accent-green: #10b981;
    --accent-purple: #818cf8;
  }}
  body {{
    font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, Helvetica, Arial, sans-serif;
    background-color: var(--bg-main);
    color: var(--text-primary);
    margin: 0;
    padding: 30px 20px;
    line-height: 1.5;
  }}
  .container {{
    max-width: 1200px;
    margin: 0 auto;
  }}
  header {{
    margin-bottom: 30px;
    border-bottom: 1px solid var(--card-border);
    padding-bottom: 20px;
  }}
  h1 {{
    font-size: 26px;
    font-weight: 700;
    margin: 0 0 8px 0;
    color: #fff;
    display: flex;
    align-items: center;
    gap: 12px;
  }}
  .subtitle {{
    color: var(--text-secondary);
    font-size: 14px;
    margin: 0;
  }}
  .badge-container {{
    display: flex;
    gap: 10px;
    margin-top: 15px;
  }}
  .badge {{
    display: inline-block;
    padding: 4px 10px;
    border-radius: 9999px;
    font-size: 12px;
    font-weight: 600;
  }}
  .badge-short {{
    background-color: rgba(56, 189, 248, 0.15);
    color: var(--accent-short);
    border: 1px solid rgba(56, 189, 248, 0.3);
  }}
  .badge-long {{
    background-color: rgba(245, 158, 11, 0.15);
    color: var(--accent-long);
    border: 1px solid rgba(245, 158, 11, 0.3);
  }}
  .card {{
    background-color: var(--card-bg);
    border: 1px solid var(--card-border);
    border-radius: 12px;
    padding: 24px;
    margin-bottom: 28px;
    box-shadow: 0 4px 6px -1px rgba(0, 0, 0, 0.2);
  }}
  .card-title {{
    font-size: 18px;
    font-weight: 600;
    margin: 0 0 16px 0;
    display: flex;
    align-items: center;
    justify-content: space-between;
  }}
  table {{
    width: 100%;
    border-collapse: collapse;
    font-size: 13.5px;
  }}
  th, td {{
    padding: 10px 14px;
    text-align: left;
    border-bottom: 1px solid var(--card-border);
  }}
  th {{
    background-color: rgba(255, 255, 255, 0.03);
    color: var(--text-secondary);
    font-weight: 600;
    text-transform: uppercase;
    font-size: 11.5px;
    letter-spacing: 0.5px;
  }}
  tr:hover {{
    background-color: rgba(255, 255, 255, 0.02);
  }}
  .text-right {{ text-align: right; }}
  .text-center {{ text-align: center; }}
  .highlight-short {{ color: var(--accent-short); font-weight: 600; }}
  .highlight-long {{ color: var(--accent-long); font-weight: 600; }}
  .delta-pos {{ color: #10b981; font-weight: 600; }}
  .delta-neg {{ color: #ef4444; font-weight: 600; }}
  .metric-pill {{
    background: rgba(255, 255, 255, 0.05);
    padding: 2px 8px;
    border-radius: 4px;
    font-family: ui-monospace, monospace;
    font-size: 12px;
  }}
  .bar-container {{
    display: flex;
    height: 8px;
    border-radius: 4px;
    overflow: hidden;
    background: rgba(255, 255, 255, 0.1);
    margin-top: 4px;
  }}
  .bar-short {{ background: var(--accent-short); }}
  .bar-long {{ background: var(--accent-long); }}
  .footer {{
    text-align: center;
    color: var(--text-secondary);
    font-size: 12px;
    margin-top: 40px;
  }}
</style>
</head>
<body>
<div class="container">
  <header>
    <h1>🔬 Assembly-Free Metagenomics: Short vs Long Reads Comparison</h1>
    <p class="subtitle">Taxonomic Concordance, Read Classification, and Abundance Correlation Benchmark</p>
    <div class="badge-container">
      <span class="badge badge-short">Illumina Paired-End (Short Reads)</span>
      <span class="badge badge-long">Oxford Nanopore (Long Reads)</span>
    </div>
  </header>

  <!-- Summary Card -->
  <div class="card">
    <div class="card-title">
      <span>📊 Sample Classification & Concordance Summary</span>
      <span style="font-size: 13px; color: var(--text-secondary);">Total Samples: {len(samples)}</span>
    </div>
    <div style="overflow-x: auto;">
      <table>
        <thead>
          <tr>
            <th>Sample</th>
            <th class="text-right">Short Reads</th>
            <th class="text-right">Short Class. %</th>
            <th class="text-right">Long Reads</th>
            <th class="text-right">Long Class. %</th>
            <th class="text-center">Shared Species</th>
            <th class="text-center">Unique (S / L)</th>
            <th class="text-center">Jaccard Index</th>
            <th class="text-right">Pearson r</th>
            <th class="text-right">Spearman &rho;</th>
          </tr>
        </thead>
        <tbody>
"""
    for row in summary_data:
        jaccard_val = float(row.get('jaccard_index', 0.0))
        pearson_val = float(row.get('species_pearson_r', 0.0))
        spearman_val = float(row.get('species_spearman_rho', 0.0))

        html_content += f"""          <tr>
            <td><strong>{row['sample']}</strong></td>
            <td class="text-right">{int(row['short_total_reads']):,}</td>
            <td class="text-right highlight-short">{row['short_classified_pct']}%</td>
            <td class="text-right">{int(row['long_total_reads']):,}</td>
            <td class="text-right highlight-long">{row['long_classified_pct']}%</td>
            <td class="text-center"><span class="metric-pill" style="color: #10b981;">{row['shared_species_count']}</span></td>
            <td class="text-center"><span class="metric-pill">{row['unique_short_species']} / {row['unique_long_species']}</span></td>
            <td class="text-center"><code>{jaccard_val:.3f}</code></td>
            <td class="text-right"><code>{pearson_val:.3f}</code></td>
            <td class="text-right"><code>{spearman_val:.3f}</code></td>
          </tr>
"""

    html_content += """        </tbody>
      </table>
    </div>
  </div>

  <!-- Top Taxa Card -->
  <div class="card">
    <div class="card-title">
      <span>🧬 Top 20 Microbial Taxa (Abundance Benchmark)</span>
    </div>
    <div style="overflow-x: auto;">
      <table>
        <thead>
          <tr>
            <th>Sample</th>
            <th>Taxon Name</th>
            <th class="text-center">Rank</th>
            <th class="text-right">Short Abundance (%)</th>
            <th class="text-right">Long Abundance (%)</th>
            <th class="text-right">&Delta; (Long - Short)</th>
            <th style="width: 160px;">Distribution</th>
          </tr>
        </thead>
        <tbody>
"""

    for t in top_taxa_data[:30]:
        s_pct = float(t['short_pct'])
        l_pct = float(t['long_pct'])
        delta = float(t['delta_pct'])
        delta_class = "delta-pos" if delta > 0 else ("delta-neg" if delta < 0 else "")
        delta_str = f"+{delta:.2f}%" if delta > 0 else f"{delta:.2f}%"

        tot = s_pct + l_pct
        s_bar_w = (s_pct / tot * 100) if tot > 0 else 0
        l_bar_w = (l_pct / tot * 100) if tot > 0 else 0

        html_content += f"""          <tr>
            <td>{t['sample']}</td>
            <td><strong>{t['taxon']}</strong></td>
            <td class="text-center"><span class="metric-pill">{t['rank']}</span></td>
            <td class="text-right highlight-short">{s_pct:.2f}%</td>
            <td class="text-right highlight-long">{l_pct:.2f}%</td>
            <td class="text-right {delta_class}">{delta_str}</td>
            <td>
              <div class="bar-container" title="Short: {s_pct:.2f}% | Long: {l_pct:.2f}%">
                <div class="bar-short" style="width: {s_bar_w}%;"></div>
                <div class="bar-long" style="width: {l_bar_w}%;"></div>
              </div>
            </td>
          </tr>
"""

    html_content += f"""        </tbody>
      </table>
    </div>
  </div>

  <div class="footer">
    Generated automatically by <strong>Hybrid Metagenomics Pipeline</strong> • {len(samples)} Samples Analyzed
  </div>
</div>
</body>
</html>
"""
    with open(out_html_path, 'w', encoding='utf-8') as f:
        f.write(html_content)

def main():
    parser = argparse.ArgumentParser(description="Compare Short vs Long Read Assembly-Free Taxonomic Profiles")
    parser.add_argument("--short-reports", nargs="*", default=[], help="Kraken2 reports for Short Reads")
    parser.add_argument("--long-reports", nargs="*", default=[], help="Kraken2 reports for Long Reads")
    parser.add_argument("--short-bracken", nargs="*", default=[], help="Optional Bracken species reports for Short Reads")
    parser.add_argument("-o", "--out-prefix", default="assembly_free_comparison", help="Output filename prefix")
    args = parser.parse_args()

    # Map files by sample ID
    short_map = {}
    long_map = {}
    bracken_map = {}

    for f in args.short_reports:
        sid = parse_sample_id(f, 'short')
        short_map[sid] = f

    for f in args.long_reports:
        sid = parse_sample_id(f, 'long')
        long_map[sid] = f

    for f in args.short_bracken:
        sid = parse_sample_id(f, 'short')
        bracken_map[sid] = f

    all_samples = sorted(list(set(short_map.keys()) | set(long_map.keys())))

    if not all_samples:
        print("[WARN] No matching samples found for comparison.", file=sys.stderr)
        return

    summary_rows = []
    species_rows = []
    genus_rows = []
    top_taxa_rows = []

    for sid in all_samples:
        short_rep_path = short_map.get(sid)
        long_rep_path = long_map.get(sid)

        s_data = parse_kraken_report(short_rep_path)
        l_data = parse_kraken_report(long_rep_path)

        # Species sets
        s_species = set(s_data['taxa']['S'].keys())
        l_species = set(l_data['taxa']['S'].keys())

        shared_sp = s_species & l_species
        unique_s_sp = s_species - l_species
        unique_l_sp = l_species - s_species
        union_sp = s_species | l_species

        jaccard_sp = round(len(shared_sp) / len(union_sp), 4) if union_sp else 0.0

        # Genus sets
        s_genera = set(s_data['taxa']['G'].keys())
        l_genera = set(l_data['taxa']['G'].keys())
        shared_gn = s_genera & l_genera
        union_gn = s_genera | l_genera

        # Abundance correlation over union of species (fill 0 for missing)
        s_sp_pcts = []
        l_sp_pcts = []
        for sp in sorted(list(union_sp)):
            s_val = s_data['taxa']['S'].get(sp, {}).get('pct', 0.0)
            l_val = l_data['taxa']['S'].get(sp, {}).get('pct', 0.0)
            s_sp_pcts.append(s_val)
            l_sp_pcts.append(l_val)
            species_rows.append({
                'sample': sid,
                'species': sp,
                'short_pct': s_val,
                'long_pct': l_val,
                'delta_pct': round(l_val - s_val, 4),
                'short_reads': s_data['taxa']['S'].get(sp, {}).get('clade_reads', 0),
                'long_reads': l_data['taxa']['S'].get(sp, {}).get('clade_reads', 0)
            })

        pearson_sp = compute_pearson(s_sp_pcts, l_sp_pcts) if len(s_sp_pcts) >= 2 else 0.0
        spearman_sp = compute_spearman(s_sp_pcts, l_sp_pcts) if len(s_sp_pcts) >= 2 else 0.0

        # Genus rows
        for gn in sorted(list(union_gn)):
            s_val = s_data['taxa']['G'].get(gn, {}).get('pct', 0.0)
            l_val = l_data['taxa']['G'].get(gn, {}).get('pct', 0.0)
            genus_rows.append({
                'sample': sid,
                'genus': gn,
                'short_pct': s_val,
                'long_pct': l_val,
                'delta_pct': round(l_val - s_val, 4),
                'short_reads': s_data['taxa']['G'].get(gn, {}).get('clade_reads', 0),
                'long_reads': l_data['taxa']['G'].get(gn, {}).get('clade_reads', 0)
            })

        # Top 20 taxa by maximum abundance across both platforms
        combined_sp_taxa = []
        for sp in union_sp:
            s_val = s_data['taxa']['S'].get(sp, {}).get('pct', 0.0)
            l_val = l_data['taxa']['S'].get(sp, {}).get('pct', 0.0)
            combined_sp_taxa.append({
                'sample': sid,
                'taxon': sp,
                'rank': 'Species',
                'short_pct': s_val,
                'long_pct': l_val,
                'delta_pct': round(l_val - s_val, 4),
                'max_pct': max(s_val, l_val)
            })
        combined_sp_taxa.sort(key=lambda x: x['max_pct'], reverse=True)
        top_taxa_rows.extend(combined_sp_taxa[:20])

        summary_rows.append({
            'sample': sid,
            'short_total_reads': s_data['total_reads'],
            'short_classified_pct': s_data['classified_pct'],
            'short_unclassified_pct': s_data['unclassified_pct'],
            'long_total_reads': l_data['total_reads'],
            'long_classified_pct': l_data['classified_pct'],
            'long_unclassified_pct': l_data['unclassified_pct'],
            'short_species_count': len(s_species),
            'long_species_count': len(l_species),
            'shared_species_count': len(shared_sp),
            'unique_short_species': len(unique_s_sp),
            'unique_long_species': len(unique_l_sp),
            'jaccard_index': jaccard_sp,
            'species_pearson_r': pearson_sp,
            'species_spearman_rho': spearman_sp
        })

    # Write 1. Summary TSV
    summary_tsv = f"{args.out_prefix}_summary.tsv"
    with open(summary_tsv, 'w', encoding='utf-8') as f:
        headers = [
            "sample", "short_total_reads", "short_classified_pct", "short_unclassified_pct",
            "long_total_reads", "long_classified_pct", "long_unclassified_pct",
            "short_species_count", "long_species_count", "shared_species_count",
            "unique_short_species", "unique_long_species", "jaccard_index",
            "species_pearson_r", "species_spearman_rho"
        ]
        f.write("\t".join(headers) + "\n")
        for r in summary_rows:
            f.write("\t".join(str(r[h]) for h in headers) + "\n")

    # Write 2. Species Comparison TSV
    species_tsv = f"{args.out_prefix}_species.tsv"
    with open(species_tsv, 'w', encoding='utf-8') as f:
        headers = ["sample", "species", "short_pct", "long_pct", "delta_pct", "short_reads", "long_reads"]
        f.write("\t".join(headers) + "\n")
        for r in species_rows:
            f.write("\t".join(str(r[h]) for h in headers) + "\n")

    # Write 3. Genus Comparison TSV
    genus_tsv = f"{args.out_prefix}_genus.tsv"
    with open(genus_tsv, 'w', encoding='utf-8') as f:
        headers = ["sample", "genus", "short_pct", "long_pct", "delta_pct", "short_reads", "long_reads"]
        f.write("\t".join(headers) + "\n")
        for r in genus_rows:
            f.write("\t".join(str(r[h]) for h in headers) + "\n")

    # Write 4. Top Taxa TSV
    top_taxa_tsv = f"{args.out_prefix}_top_taxa.tsv"
    with open(top_taxa_tsv, 'w', encoding='utf-8') as f:
        headers = ["sample", "taxon", "rank", "short_pct", "long_pct", "delta_pct"]
        f.write("\t".join(headers) + "\n")
        for r in top_taxa_rows:
            f.write("\t".join(str(r[h]) for h in headers) + "\n")

    # Write 5. Markdown Report
    md_path = f"{args.out_prefix}.md"
    with open(md_path, 'w', encoding='utf-8') as f:
        f.write("# 🔬 Short vs Long Reads: Assembly-Free Taxonomic Comparison\n\n")
        f.write("> [!NOTE]\n")
        f.write("> **Comparison Scope**: Direct side-by-side benchmarking of taxonomic profiling between paired **Short Reads (Illumina)** and **Long Reads (Oxford Nanopore)**.\n\n")

        f.write("## 1. Classification & Taxonomic Concordance Overview\n\n")
        f.write("| Sample | Short Reads | Short Class. (%) | Long Reads | Long Class. (%) | Shared Species | Unique (S / L) | Jaccard Index | Pearson $r$ | Spearman $\\rho$ |\n")
        f.write("|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|\n")
        for r in summary_rows:
            f.write(f"| **{r['sample']}** | {r['short_total_reads']:,} | `{r['short_classified_pct']}%` | {r['long_total_reads']:,} | `{r['long_classified_pct']}%` | **{r['shared_species_count']}** | {r['unique_short_species']} / {r['unique_long_species']} | `{r['jaccard_index']:.3f}` | `{r['species_pearson_r']:.3f}` | `{r['species_spearman_rho']:.3f}` |\n")

        f.write("\n## 2. Top Abundant Taxa Benchmark (Species Level)\n\n")
        f.write("| Sample | Species | Short Abundance (%) | Long Abundance (%) | &Delta; (Long - Short) |\n")
        f.write("|---|---|---:|---:|---:|\n")
        for r in top_taxa_rows[:25]:
            delta_str = f"+{r['delta_pct']:.2f}%" if r['delta_pct'] > 0 else f"{r['delta_pct']:.2f}%"
            f.write(f"| {r['sample']} | **{r['taxon']}** | {r['short_pct']:.2f}% | {r['long_pct']:.2f}% | `{delta_str}` |\n")

        f.write("\n\n### 💡 Key Comparative Insights\n")
        f.write("1. **Classification Yield**: Long reads often attain higher classification confidence per read due to length, while short reads offer high sequencing depth for rare taxa.\n")
        f.write("2. **Concordance & Correlation**: Higher Pearson $r$ / Spearman $\\rho$ indicates robust consistency across sequencing platforms for dominant microbial community members.\n")
        f.write("3. **Visualization Artifacts**: Corresponding Krona charts (`*_short.krona.html` and `*_long.krona.html`) provide interactive hierarchical exploration.\n")

    # Write 6. HTML Report
    html_path = f"{args.out_prefix}.html"
    generate_html_report(html_path, summary_rows, top_taxa_rows, all_samples)

    print(f"[OK] Comparison complete for {len(all_samples)} samples:")
    print(f"     - Summary TSV   : {summary_tsv}")
    print(f"     - Species TSV   : {species_tsv}")
    print(f"     - Top Taxa TSV  : {top_taxa_tsv}")
    print(f"     - Markdown      : {md_path}")
    print(f"     - HTML Report   : {html_path}")

if __name__ == '__main__':
    main()
