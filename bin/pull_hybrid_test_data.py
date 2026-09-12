#!/usr/bin/env python3
"""
bin/pull_hybrid_test_data.py
Pull paired Short (Illumina) and Long (Nanopore) reads for 2 test subjects
from short_long_metadata.csv to test the Nextflow Hybrid Pipeline.

Features:
- Matches Illumina paired-end and Nanopore single-end runs by Subject ID.
- Automatically selects the smallest 2 subjects (TD22 and TD3) by default,
  or custom subjects (e.g. TD78, CD35).
- Queries ENA (European Nucleotide Archive) API for high-speed direct HTTP FASTQ links.
- Supports '--mode smoke' (subsamples 50,000 short read pairs and 10,000 long reads
  via on-the-fly streaming) for lightning-fast pipeline validation (~5 min run time).
- Supports '--mode full' to download full complete FASTQ datasets.
- Automatically outputs 'samplesheet_hybrid.csv' ready for './run_hybrid.sh'.
"""

import argparse
import csv
import gzip
import io
import json
import os
import re
import sys
import time
import urllib.request
import urllib.error

ENA_API_URL = "https://www.ebi.ac.uk/ena/portal/api/filereport?accession={acc}&result=read_run&fields=run_accession,fastq_ftp,fastq_bytes&format=json"

def find_matched_subjects(metadata_path):
    """Parses short_long_metadata.csv and returns dictionary of matched subjects."""
    if not os.path.exists(metadata_path):
        print(f"[ERROR] Metadata file not found: {metadata_path}", file=sys.stderr)
        sys.exit(1)

    with open(metadata_path, mode="r", encoding="utf-8") as f:
        rows = list(csv.DictReader(f))

    illumina_map = {}
    ont_map = {}

    for r in rows:
        plat = r.get("Platform", "").upper()
        sname = r.get("Sample Name", "")
        if plat == "ILLUMINA":
            m = re.search(r"(TD\d+|CD\d+)", sname)
            if m:
                illumina_map[m.group(1)] = r
        elif plat in ["OXFORD_NANOPORE", "NANOPORE", "ONT"]:
            m = re.search(r"(TD\d+|CD\d+)", sname)
            if m:
                ont_map[m.group(1)] = r

    matched = []
    for sid, il_row in illumina_map.items():
        if sid in ont_map:
            on_row = ont_map[sid]
            il_bytes = int(il_row.get("Bytes") or 0)
            on_bytes = int(on_row.get("Bytes") or 0)
            matched.append({
                "subject_id": sid,
                "illumina_run": il_row.get("Run"),
                "illumina_sample": il_row.get("Sample Name"),
                "illumina_bytes": il_bytes,
                "illumina_gb": round(il_bytes / (1024**3), 2),
                "ont_run": on_row.get("Run"),
                "ont_sample": on_row.get("Sample Name"),
                "ont_bytes": on_bytes,
                "ont_gb": round(on_bytes / (1024**3), 2),
                "total_gb": round((il_bytes + on_bytes) / (1024**3), 2),
                "illumina_bases_mb": round(int(il_row.get("Bases") or 0) / 1e6, 1),
                "ont_bases_mb": round(int(on_row.get("Bases") or 0) / 1e6, 1)
            })

    # Sort by total size ascending
    matched.sort(key=lambda x: x["total_gb"])
    return matched

def get_ena_fastq_urls(accession):
    """Queries ENA API for fastq FTP/HTTP download URLs for a run accession."""
    url = ENA_API_URL.format(acc=accession)
    req = urllib.request.Request(url, headers={"User-Agent": "MetagenomicsPipeline/1.0"})
    try:
        with urllib.request.urlopen(req, timeout=30) as resp:
            data = json.loads(resp.read().decode("utf-8"))
            if data and len(data) > 0:
                ftp_str = data[0].get("fastq_ftp", "")
                if ftp_str:
                    # Each URL is separated by semicolon
                    urls = ["https://" + u.replace("ftp.sra.ebi.ac.uk", "ftp.sra.ebi.ac.uk") if not u.startswith("http") else u
                            for u in ftp_str.split(";")]
                    return urls
    except Exception as e:
        print(f"[WARN] Failed to query ENA API for {accession}: {e}", file=sys.stderr)

    # Fallback to standard ENA directory structure
    # Format: ftp.sra.ebi.ac.uk/vol1/fastq/<first 6>/<last 3 if 8-9 digits>/<accession>/<accession>...
    acc_len = len(accession)
    if acc_len == 11: # e.g. SRR18491097
        prefix = accession[:6]
        sub = "0" + accession[-2:] if len(accession) == 10 else "0" + accession[-2:] # standard rule
        # fallback single / paired
        return [
            f"https://ftp.sra.ebi.ac.uk/vol1/fastq/{prefix}/{accession[-3:]}/{accession}/{accession}_1.fastq.gz",
            f"https://ftp.sra.ebi.ac.uk/vol1/fastq/{prefix}/{accession[-3:]}/{accession}/{accession}_2.fastq.gz"
        ]
    return []

def download_full_file(url, output_path):
    """Downloads a complete remote file with resume support and progress logging."""
    if os.path.exists(output_path) and os.path.getsize(output_path) > 1024:
        print(f"  ✓ Existing file found ({os.path.getsize(output_path) / (1024*1024):.1f} MB): {output_path}")
        return output_path

    tmp_path = output_path + ".part"
    start_byte = 0
    if os.path.exists(tmp_path):
        start_byte = os.path.getsize(tmp_path)

    req = urllib.request.Request(url, headers={"User-Agent": "MetagenomicsPipeline/1.0"})
    if start_byte > 0:
        req.add_header("Range", f"bytes={start_byte}-")

    print(f"  ⬇ Downloading: {url}")
    print(f"    Target: {output_path} (resume offset: {start_byte} bytes)")

    try:
        with urllib.request.urlopen(req, timeout=60) as response:
            mode = "ab" if start_byte > 0 else "wb"
            total_size = response.getheader("Content-Length")
            total_size = int(total_size) + start_byte if total_size else None

            downloaded = start_byte
            chunk_size = 1024 * 1024 # 1MB
            last_print = time.time()

            with open(tmp_path, mode) as out_f:
                while True:
                    chunk = response.read(chunk_size)
                    if not chunk:
                        break
                    out_f.write(chunk)
                    downloaded += len(chunk)
                    if time.time() - last_print > 3:
                        if total_size:
                            pct = (downloaded / total_size) * 100
                            print(f"    ... {downloaded / (1024**2):.1f} MB / {total_size / (1024**2):.1f} MB ({pct:.1f}%)")
                        else:
                            print(f"    ... {downloaded / (1024**2):.1f} MB downloaded")
                        last_print = time.time()

        os.rename(tmp_path, output_path)
        print(f"  ✓ Completed: {output_path} ({os.path.getsize(output_path)/(1024**2):.1f} MB)")
        return output_path
    except Exception as e:
        print(f"[ERROR] Failed downloading {url}: {e}", file=sys.stderr)
        if os.path.exists(tmp_path):
            print(f"    Partial download kept at: {tmp_path}")
        raise

def stream_subsample_fastq_gz(url, output_path, max_reads=50000):
    """
    Streams a remote fastq.gz via HTTP, decompresses in memory on-the-fly,
    takes the first max_reads (4 lines per read), re-compresses to gzip,
    and terminates the HTTP connection early.
    This saves gigabytes of download bandwidth and hours of assembly time for smoke tests!
    """
    if os.path.exists(output_path) and os.path.getsize(output_path) > 1024:
        print(f"  ✓ Existing smoke test subset found: {output_path} ({os.path.getsize(output_path) / 1024:.1f} KB)")
        return output_path

    print(f"  ⚡ Subsampling {max_reads:,} reads directly from remote stream: {url}")
    req = urllib.request.Request(url, headers={"User-Agent": "MetagenomicsPipeline/1.0"})

    try:
        with urllib.request.urlopen(req, timeout=60) as resp:
            # We wrap the HTTP response into a custom streaming buffer for gzip
            gz_stream = gzip.GzipFile(fileobj=resp, mode="rb")
            tmp_path = output_path + ".tmp"

            with gzip.open(tmp_path, "wb") as out_gz:
                read_count = 0
                while read_count < max_reads:
                    # A FASTQ record is 4 lines: header, seq, +, qual
                    h = gz_stream.readline()
                    if not h:
                        break
                    s = gz_stream.readline()
                    p = gz_stream.readline()
                    q = gz_stream.readline()

                    if not (s and p and q):
                        break

                    out_gz.write(h)
                    out_gz.write(s)
                    out_gz.write(p)
                    out_gz.write(q)
                    read_count += 1

                    if read_count % 10000 == 0:
                        print(f"    ... extracted {read_count:,} / {max_reads:,} reads")

            os.rename(tmp_path, output_path)
            print(f"  ✓ Smoke subset ready: {output_path} ({read_count:,} reads, {os.path.getsize(output_path)/1024:.1f} KB)")
            return output_path
    except Exception as e:
        print(f"[WARN] Stream subsampling error on {url}: {e}", file=sys.stderr)
        print("  Retrying via full file download fallback...", file=sys.stderr)
        full_file = download_full_file(url, output_path.replace(".smoke.fastq.gz", ".full.fastq.gz"))
        # Local subsample
        print(f"  Extracting {max_reads:,} reads from local file...")
        with gzip.open(full_file, "rt") as in_f, gzip.open(output_path, "wt") as out_f:
            reads = 0
            for i, line in enumerate(in_f):
                out_f.write(line)
                if (i + 1) % 4 == 0:
                    reads += 1
                    if reads >= max_reads:
                        break
        return output_path

def main():
    parser = argparse.ArgumentParser(
        description="Pull paired Illumina + Nanopore reads for 2 test subjects from short_long_metadata.csv"
    )
    parser.add_argument("--metadata", "-m", default="short_long_metadata.csv",
                        help="Path to short_long_metadata.csv (default: short_long_metadata.csv)")
    parser.add_argument("--subjects", "-s", nargs="*", default=["TD22", "TD3"],
                        help="Subject IDs to pull (default: TD22 TD3 - the 2 smallest matched subjects)")
    parser.add_argument("--outdir", "-o", default="test_data/hybrid_test",
                        help="Output directory for downloaded reads (default: test_data/hybrid_test)")
    parser.add_argument("--samplesheet", default="samplesheet_hybrid.csv",
                        help="Output samplesheet path (default: samplesheet_hybrid.csv)")
    parser.add_argument("--mode", choices=["smoke", "full"], default="smoke",
                        help="Download mode: 'smoke' (subsample for fast pipeline testing) or 'full' (complete dataset)")
    parser.add_argument("--short-reads", type=int, default=50000,
                        help="Number of read pairs to keep in smoke mode (default: 50,000)")
    parser.add_argument("--long-reads", type=int, default=10000,
                        help="Number of long reads to keep in smoke mode (default: 10,000)")
    parser.add_argument("--dry-run", action="store_true",
                        help="Simulate and print matched samples, URLs, and samplesheet without downloading")

    args = parser.parse_args()

    project_dir = os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))
    metadata_file = os.path.abspath(args.metadata) if os.path.isabs(args.metadata) else os.path.join(project_dir, args.metadata)
    out_dir = os.path.abspath(args.outdir) if os.path.isabs(args.outdir) else os.path.join(project_dir, args.outdir)
    samplesheet_file = os.path.abspath(args.samplesheet) if os.path.isabs(args.samplesheet) else os.path.join(project_dir, args.samplesheet)

    print("=" * 80)
    print("   🧬 Hybrid Test Data Downloader (Illumina + Nanopore) 🧬")
    print("=" * 80)
    print(f" 📂 Project Directory : {project_dir}")
    print(f" 📋 Metadata File     : {metadata_file}")
    print(f" 🎯 Target Subjects   : {', '.join(args.subjects)}")
    print(f" ⚙️ Download Mode      : {args.mode.upper()} ({'Fast test subset' if args.mode == 'smoke' else 'Full files'})")
    print(f" 📁 Output Directory  : {out_dir}")
    print(f" 📄 Target Samplesheet: {samplesheet_file}")
    if args.mode == "smoke":
        print(f" ✂️ Subsample Limits   : Short={args.short_reads:,} pairs | Long={args.long_reads:,} reads")
    print("=" * 80 + "\n")

    matched_all = find_matched_subjects(metadata_file)
    matched_dict = {m["subject_id"]: m for m in matched_all}

    # Verify selected subjects exist
    selected = []
    for sid in args.subjects:
        if sid in matched_dict:
            selected.append(matched_dict[sid])
        else:
            print(f"[ERROR] Subject '{sid}' not found in metadata with both Illumina & ONT runs!", file=sys.stderr)
            print(f"Available subjects with both platforms ({len(matched_all)} total):", file=sys.stderr)
            print(", ".join([m["subject_id"] for m in matched_all[:15]]) + "...", file=sys.stderr)
            sys.exit(1)

    print(f"Selected {len(selected)} subjects for hybrid pipeline testing:\n")
    for s in selected:
        print(f"  • Subject {s['subject_id']}:")
        print(f"      Illumina (Short) : Run={s['illumina_run']} | Sample={s['illumina_sample']} | Size={s['illumina_gb']} GB ({s['illumina_bases_mb']} Mb)")
        print(f"      Nanopore (Long)  : Run={s['ont_run']} | Sample={s['ont_sample']} | Size={s['ont_gb']} GB ({s['ont_bases_mb']} Mb)")
        print(f"      Total Compressed : {s['total_gb']} GB\n")

    os.makedirs(out_dir, exist_ok=True)
    samplesheet_rows = []

    for s in selected:
        sid = s["subject_id"]
        il_run = s["illumina_run"]
        ont_run = s["ont_run"]

        print(f"🔍 Resolving ENA download endpoints for Subject {sid}...")
        il_urls = get_ena_fastq_urls(il_run)
        ont_urls = get_ena_fastq_urls(ont_run)

        # Illumina paired-end URLs
        il_r1_url = None
        il_r2_url = None
        for u in il_urls:
            if "_1.fastq" in u:
                il_r1_url = u
            elif "_2.fastq" in u:
                il_r2_url = u

        # Nanopore single-end URL
        ont_url = ont_urls[0] if ont_urls else None

        print(f"   Illumina R1 URL : {il_r1_url}")
        print(f"   Illumina R2 URL : {il_r2_url}")
        print(f"   Nanopore URL    : {ont_url}")

        if args.dry_run:
            fq1_path = os.path.join(out_dir, f"{sid}_illumina_1.fastq.gz").replace("\\", "/")
            fq2_path = os.path.join(out_dir, f"{sid}_illumina_2.fastq.gz").replace("\\", "/")
            long_path = os.path.join(out_dir, f"{sid}_nanopore.fastq.gz").replace("\\", "/")
            samplesheet_rows.append((sid, fq1_path, fq2_path, long_path))
            continue

        # Download / Subsample paths
        suffix = ".smoke.fastq.gz" if args.mode == "smoke" else ".fastq.gz"
        fq1_path = os.path.join(out_dir, f"{sid}_illumina_1{suffix}")
        fq2_path = os.path.join(out_dir, f"{sid}_illumina_2{suffix}")
        long_path = os.path.join(out_dir, f"{sid}_nanopore{suffix}")

        print(f"\n📥 Preparing files for {sid}...")
        if args.mode == "smoke":
            stream_subsample_fastq_gz(il_r1_url, fq1_path, max_reads=args.short_reads)
            stream_subsample_fastq_gz(il_r2_url, fq2_path, max_reads=args.short_reads)
            stream_subsample_fastq_gz(ont_url, long_path, max_reads=args.long_reads)
        else:
            download_full_file(il_r1_url, fq1_path)
            download_full_file(il_r2_url, fq2_path)
        # Normalize path separators to forward slash for cross-platform and Nextflow container compatibility
        fq1_path = fq1_path.replace("\\", "/")
        fq2_path = fq2_path.replace("\\", "/")
        long_path = long_path.replace("\\", "/")

        samplesheet_rows.append((sid, fq1_path, fq2_path, long_path))

    # Write samplesheet_hybrid.csv
    print(f"\n📝 Writing Samplesheet to: {samplesheet_file}")
    with open(samplesheet_file, "w", newline="", encoding="utf-8") as f:
        writer = csv.writer(f)
        writer.writerow(["sample", "fastq_1", "fastq_2", "long_reads"])
        for row in samplesheet_rows:
            writer.writerow(row)
            print(f"  • {row[0]}:")
            print(f"      fastq_1    = {row[1]}")
            print(f"      fastq_2    = {row[2]}")
            print(f"      long_reads = {row[3]}")

    print("\n" + "=" * 80)
    print(" 🎉 Hybrid Test Dataset is Ready! 🎉")
    print("=" * 80)
    print(f" 📋 Samplesheet: {samplesheet_file}")
    print("\nคุณสามารถเริ่มทดสอบรัน Hybrid Pipeline ได้ทันทีด้วยคำสั่ง:")
    print("   chmod +x run_hybrid.sh")
    print("   ./run_hybrid.sh docker")
    print(" หรือ:")
    print("   ./run_hybrid.sh conda")
    print("=" * 80 + "\n")

if __name__ == "__main__":
    main()
