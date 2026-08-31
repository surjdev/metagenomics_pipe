#!/usr/bin/env python3
"""
generate_walkthrough_notebook.py
Generates the comprehensive Jupyter Notebook 'notebooks/Meta_NPI_Workflow_Walkthrough.ipynb'
for exploring and running the Hybrid Metagenomics Pipeline on the Meta_NPI dataset.
"""

import json
import os

def create_notebook():
    nb = {
        "cells": [],
        "metadata": {
            "kernelspec": {
                "display_name": "Python 3 (ipykernel)",
                "language": "python",
                "name": "python3"
            },
            "language_info": {
                "codemirror_mode": {"name": "ipython", "version": 3},
                "file_extension": ".py",
                "mimetype": "text/x-python",
                "name": "python",
                "nbconvert_exporter": "python",
                "pygments_lexer": "ipython3",
                "version": "3.10.0"
            }
        },
        "nbformat": 4,
        "nbformat_minor": 5
    }

    def md_cell(source):
        nb["cells"].append({
            "cell_type": "markdown",
            "metadata": {},
            "source": [line + "\n" for line in source.split("\n")]
        })

    def code_cell(source):
        nb["cells"].append({
            "cell_type": "code",
            "execution_count": None,
            "metadata": {},
            "outputs": [],
            "source": [line + "\n" for line in source.split("\n")]
        })

    # ──────────────────────────────────────────────────────────────────────────
    # TITLE & INTRODUCTION
    # ──────────────────────────────────────────────────────────────────────────
    md_cell("""# 🧬 Hybrid Metagenomics Pipeline — Meta_NPI ONT Interactive Walkthrough
## คู่มือและสมุดบันทึกเชิงปฏิบัติการ: การวิเคราะห์ข้อมูล Metagenomics จาก Oxford Nanopore (Meta_NPI) แบบทีละขั้นตอน

---

### 🎯 วัตถุประสงค์ (Objectives)
1. **ทำความเข้าใจโครงสร้างและการทำงานของ 11 Workflow Stages** ใน Nextflow DSL2 Pipeline
2. **สำรวจลักษณะของชุดข้อมูลจริง (Meta_NPI)** ที่ผ่านการ Basecall ด้วย Dorado Super Accuracy Mode (`SQK-RBK114-24`, Q17.6+)
3. **เรียนรู้หน้าที่ คำสั่ง และพารามิเตอร์ของชีวสารสนเทศศาสตร์ (Bioinformatics Tools)** แต่ละตัว
4. **ทดลองรัน Pipeline ทั้งแบบ Smoke Test, Benchmark, และคำสั่งเดี่ยว (Standalone Commands)**
5. **วิเคราะห์และแสดงผลลัพธ์แบบโต้ตอบ (Interactive Visualizations)** เช่น กราฟ QUAST, Krona Chart, MultiQC, และ MAG Bins

---

### 🏗️ โครงสร้างสถาปัตยกรรม 11 ขั้นตอน (11-Stage Workflow DAG)

```
[Raw Long Reads / Meta_NPI]
          │
          ▼
   ┌────────────────────────────────────────────────────────┐
   │ 1. Preprocessing (NanoPlot, Filtlong, Dorado, Porechop) │
   └──────────────────────┬─────────────────────────────────┘
                          │
                          ▼
   ┌────────────────────────────────────────────────────────┐
   │ 2. Host Removal (Minimap2 vs Host Genome Reference)     │
   └──────────┬───────────────────────────────┬─────────────┘
              │ (Microbial Long Reads)        │
              ▼                               ▼
   ┌──────────────────────┐        ┌─────────────────────────┐
   │ 3. Assembly (Flye)   │        │ 9. Read-Based Profiling │
   └──────────┬───────────┘        │    (Kraken2, Krona)     │
              │                    └─────────────────────────┘
              ▼
   ┌──────────────────────┐
   │ 4. Polishing (Medaka)│ (ข้ามได้สำหรับ Dorado SUP Q17+)
   └──────────┬───────────┘
              │
              ▼
   ┌────────────────────────────────────────────────────────┐
   │ 5. Assembly QC (QUAST Contig Statistics)               │
   └──────────┬─────────────────────────────────────────────┘
              │
              ▼
   ┌────────────────────────────────────────────────────────┐
   │ 6. Read Mapping & Coverage (Minimap2 + Samtools Depth) │
   └──────────┬─────────────────────────────────────────────┘
              │
              ▼
   ┌────────────────────────────────────────────────────────┐
   │ 7. MAG Binning (MetaBAT2, SemiBin2, DAS Tool)          │
   └──────────┬─────────────────────────────────────────────┘
              │
              ▼
   ┌────────────────────────────────────────────────────────┐
   │ 8. MAG QC & Taxonomy (CheckM2, GUNC, GTDB-Tk)           │
   └────────────────────────────────────────────────────────┘
              │
              ▼
   ┌────────────────────────────────────────────────────────┐
   │ 10. Annotation (Prokka CDS/tRNA, geNomad Phage/Plasmid)│
   └──────────┬─────────────────────────────────────────────┘
              │
              ▼
   ┌────────────────────────────────────────────────────────┐
   │ 11. Reporting (MultiQC, Custom HTML/MD Report)         │
   └────────────────────────────────────────────────────────┘
```""")

    # ──────────────────────────────────────────────────────────────────────────
    # SECTION 0: ENVIRONMENT SETUP & DATA INSPECTION
    # ──────────────────────────────────────────────────────────────────────────
    md_cell("""## 📦 ส่วนที่ 0: ตรวจสอบสภาพแวดล้อมและสำรวจข้อมูลดิบ (Meta_NPI Exploration)

ข้อมูลใน `Meta_NPI/1_basecalled_fastq/` เป็นผลลัพธ์จากการซีเควนซ์ด้วย Oxford Nanopore R10.4.1 Flowcell ร่วมกับชุด Rapid Barcoding Kit 24 (`SQK-RBK114-24`) และผ่านการแปลงสัญญาณดิบด้วยโมเดล `dna_r10.4.1_e8.2_400bps_sup@v5.0.0` (Dorado SUP)""")

    code_cell("""# นำเข้าโมดูล Python ที่จำเป็น
import os
import sys
import glob
import gzip
import pandas as pd
import matplotlib.pyplot as plt
import seaborn as sns
from pathlib import Path
try:
    from IPython.display import display, HTML, IFrame
except ImportError:
    display = print
    HTML = None
    IFrame = None

# ตั้งค่าสไตล์ของกราฟ
plt.style.use('seaborn-v0_8-whitegrid' if 'seaborn-v0_8-whitegrid' in plt.style.available else 'default')
plt.rcParams['figure.figsize'] = (10, 5)
plt.rcParams['font.size'] = 11

# กำหนดเส้นทางหลักของโปรเจกต์
WORKSPACE_DIR = Path("/home/surj/Workspace/metagenomics-pipeline")
FASTQ_DIR = WORKSPACE_DIR / "Meta_NPI" / "1_basecalled_fastq"

print(f"✅ Workspace Directory: {WORKSPACE_DIR}")
print(f"✅ FASTQ Directory    : {FASTQ_DIR}")
print(f"✅ โฟลเดอร์ FASTQ มีอยู่จริงหรือไม่: {FASTQ_DIR.exists()}")""")

    code_cell("""# สำรวจจำนวนไฟล์ FASTQ และ Barcode ทั้งหมด
barcode_dirs = sorted([d for d in FASTQ_DIR.iterdir() if d.is_dir()])
print(f"🔍 พบ Barcode ทั้งหมด: {len(barcode_dirs)} barcodes\\n")

data_catalog = []

for b_dir in barcode_dirs:
    fq_files = list(b_dir.glob("*.fastq")) + list(b_dir.glob("*.fastq.gz"))
    for fq in fq_files:
        size_mb = fq.stat().st_size / (1024 * 1024)
        
        # นับจำนวน Reads อย่างรวดเร็ว (FASTQ มี 4 บรรทัดต่อ 1 Read)
        with open(fq, 'r', encoding='utf-8', errors='ignore') as f:
            lines = sum(1 for _ in f)
            read_count = lines // 4
            
        tier = "Tier 1 (Smoke Test)" if b_dir.name in ["barcode14", "barcode16"] else \
               "Tier 2 (Benchmark)" if read_count >= 3000 else \
               "Tier 1 (Light)" if read_count >= 50 else "Debug / Edge Case"
               
        data_catalog.append({
            "Barcode": b_dir.name,
            "Filename": fq.name,
            "Read_Count": read_count,
            "Size_MB": round(size_mb, 2),
            "Tier": tier,
            "Path": str(fq)
        })

df_catalog = pd.DataFrame(data_catalog)
display(df_catalog.sort_values(by="Read_Count", ascending=False).reset_index(drop=True))""")

    code_cell("""# วาดกราฟเปรียบเทียบจำนวน Reads และขนาดไฟล์ของแต่ละ Barcode
fig, (ax1, ax2) = plt.subplots(1, 2, figsize=(16, 6))

# กราฟแท่งแสดงจำนวน Reads
sns.barplot(data=df_catalog, x="Barcode", y="Read_Count", hue="Tier", dodge=False, ax=ax1, palette="viridis")
ax1.set_title("Read Counts per Barcode (ONT Dorado SUP)", fontsize=14, fontweight='bold')
ax1.set_xlabel("Barcode")
ax1.set_ylabel("Read Count")
ax1.tick_params(axis='x', rotation=45)
ax1.grid(True, linestyle='--', alpha=0.6)

# กราฟแท่งแสดงขนาดไฟล์ (MB)
sns.barplot(data=df_catalog, x="Barcode", y="Size_MB", hue="Tier", dodge=False, ax=ax2, palette="magma")
ax2.set_title("FASTQ File Size (MB)", fontsize=14, fontweight='bold')
ax2.set_xlabel("Barcode")
ax2.set_ylabel("Size (MB)")
ax2.tick_params(axis='x', rotation=45)
ax2.grid(True, linestyle='--', alpha=0.6)

plt.tight_layout()
plt.show()""")

    # ──────────────────────────────────────────────────────────────────────────
    # SECTION 1: WORKFLOW STAGES DEEP DIVE
    # ──────────────────────────────────────────────────────────────────────────
    md_cell("""---
## 🔬 ส่วนที่ 1: เจาะลึกการทำงานของ 11 Workflow Stages และ Tools

ในส่วนนี้เราจะมาทำความเข้าใจว่าแต่ละขั้นตอนทำหน้าที่อะไร ทำไมต้องใช้ Tool ตัวนี้ พารามิเตอร์สำคัญมีอะไรบ้าง และหากต้องการรันคำสั่งเดี่ยวๆ เพื่อทดสอบ ต้องเขียนอย่างไร""")

    # Stage 1
    md_cell("""### 🛠️ Stage 1: Preprocessing & Quality Control (การเตรียมข้อมูลและตรวจสอบคุณภาพ)

#### วัตถุประสงค์:
ตรวจสอบคุณภาพของสายลำดับเบส กรองอ่านสายที่มีคุณภาพต่ำหรือสั้นเกินไป และตัด Adapter ที่อาจหลงเหลือ

#### Tools ที่ใช้:
1. **`NanoPlot`**: สร้างรายงานสถิติเชิงลึกสำหรับ Long Reads (ความยาวเฉลี่ย, N50, ค่าเฉลี่ย Quality Score, กราฟแจกแจงความยาวเทียบกับ Q-score)
2. **`Filtlong`**: กรอง Long Reads ตามเงื่อนไขคุณภาพและความยาว โดยสำหรับ Dorado SUP (Q17.6+) เราจะตั้งค่าขั้นต่ำที่ `min_quality = 10` และ `min_length = 300 - 500 bp`
3. **`Porechop-ABI`**: (Optional) ค้นหาและตัด Nanopore Adapters/Barcodes (ข้ามได้เนื่องจาก Dorado ทำ Demultiplexing มาแล้ว)
4. **`FastQC` / `fastp`**: ใช้สำหรับฝั่ง Illumina Short Reads (หากเป็น Hybrid mode)

#### ตัวอย่างคำสั่ง Standalone:
```bash
# 1. รัน NanoPlot ตรวจสอบคุณภาพ Long reads
nanoplot --fastq Meta_NPI/1_basecalled_fastq/barcode14/*.fastq -o nanoplot_out --plots hex dot

# 2. รัน Filtlong กรองเบส Q10+ และยาว >= 300bp
filtlong --min_length 300 --min_mean_q 10 input.fastq > clean_filtered.fastq
```""")

    # Stage 2
    md_cell("""### 🧬 Stage 2: Host DNA Removal (การกำจัด DNA ของโฮสต์/สิ่งเจือปน)

#### วัตถุประสงค์:
ในตัวอย่าง Metagenomics (เช่น ทางเดินอาหาร, น้ำลาย, ดิน, พืช) มักมี DNA ของโฮสต์ปะปนอยู่จำนวนมาก การกำจัด Host DNA ก่อนทำ Assembly จะช่วยลดภาระการคำนวณและป้องกันการประกอบจีโนมที่ผิดพลาด

#### Tools ที่ใช้:
1. **`Minimap2`**: เครื่องมือ Aligner สำหรับ Long Reads ที่มีความเร็วสูงมาก นำ Reads ไป Map กับ Reference Genome ของโฮสต์ (เช่น มนุษย์, หนู, ข้าว)
2. **`Samtools` / Python Script (`bin/extract_nonhost.py`)**: คัดกรองเฉพาะ Reads ที่ **ไม่ Map กับ Host** (`SAM flag 4 - unmapped`) ส่งต่อไปยังขั้นตอนถัดไป
3. **`Bowtie2`**: ใช้สำหรับการคัดกรอง Host DNA ในฝั่ง Short Reads

#### ตัวอย่างคำสั่ง Standalone:
```bash
# นำ Long Reads ไป Align กับ Host Reference Genome และดึงเฉพาะ Unmapped Reads ออกมา
minimap2 -ax map-ont -t 4 host_reference.fasta filtered_reads.fastq | \\
samtools view -b -f 4 - | \\
samtools fastq - > microbial_clean_reads.fastq
```""")

    # Stage 3
    md_cell("""### 🧩 Stage 3: Metagenome De Novo Assembly (การประกอบจีโนมจุลชีพ)

#### วัตถุประสงค์:
นำสายอ่านสั้น/ยาวที่ผ่านการคัดกรองแล้วมาประกอบต่อกันเป็นสายยาวต่อเนื่องเรียกว่า **Contigs** เพื่อสร้างจีโนมของสิ่งมีชีวิตในชุมชนจุลชีพ

#### Tools ที่ใช้:
1. **`Flye`**: เครื่องมือ De novo assembler ที่ดีที่สุดสำหรับ Oxford Nanopore Long Reads
   - โหมด `--nano-hq` : ออกแบบมาเฉพาะสำหรับ Dorado SUP / R10.4.1 ที่มี Quality สูง (Error rate < 3-5%)
   - อาร์กิวเมนต์ `--meta` : โหมดสำหรับ Metagenomics เพื่อจัดการกับความลึกการอ่านที่ไม่สม่ำเสมอ (Uneven coverage across species)
2. **`MEGAHIT`**: De Bruijn graph assembler ประสิทธิภาพสูงสำหรับ Illumina Short Reads
3. **`Opera-MS`**: Hybrid assembler ที่ผสานข้อดีของ Short reads (ความแม่นยำสูง) และ Long reads (ช่วยเชื่อมช่องว่างซ้ำซ้อน)

#### ตัวอย่างคำสั่ง Standalone:
```bash
# รัน Flye ประกอบจีโนมจุลชีพสำหรับ Dorado SUP reads
flye --nano-hq microbial_clean_reads.fastq \\
     --meta \\
     --out-dir flye_output \\
     --threads 4 \\
     --min-overlap 1000
```""")

    # Stage 4
    md_cell("""### 💎 Stage 4: Contig Polishing (การปรับปรุงความถูกต้องของลำดับเบส)

#### วัตถุประสงค์:
แก้ไขข้อผิดพลาดประเภท Indels (Insertions/Deletions) และ Homopolymers ที่อาจเกิดจากการซีเควนซ์

#### Tools ที่ใช้:
1. **`Medaka`**: Neural network-based consensus polisher พัฒนาโดย ONT โดยเฉพาะ
2. **`Racon`**: Fast consensus module ใช้ Long reads หรือ Short reads
3. **`NextPolish`**: ใช้ความแม่นยำของ Illumina Short reads มา Polish Contigs ของ Long reads

> **💡 คำแนะนำสำหรับ Dorado SUP (Q17.6+):**
> เนื่องจากข้อมูล ONT R10.4.1 Dorado SUP มีความแม่นยำสูงมากอยู่แล้ว ในการตั้งค่า `conf/meta_npi.config` เราจึงสามารถตั้ง `run_polishing = false` เพื่อประหยัดเวลาและทรัพยากรการคำนวณได้""")

    # Stage 5
    md_cell("""### 📊 Stage 5: Assembly Quality Assessment (การประเมินคุณภาพ Contigs)

#### วัตถุประสงค์:
วัดค่าสถิติเชิงคุณภาพของชิ้นส่วน Contigs ที่ประกอบได้ เพื่อดูว่าการประกอบจีโนมมีคุณภาพและความต่อเนื่องเพียงใด

#### Tool ที่ใช้:
- **`QUAST` (Quality Assessment Tool for Genome Assemblies)**:
  - **N50**: ความยาว Contig ที่เมื่อรวมจากยาวสุดลงมา จะได้ 50% ของความยาวทั้งหมด (ยิ่งสูงยิ่งดี)
  - **L50**: จำนวน Contig ที่ต้องใช้เพื่อให้ได้ความยาวถึง N50 (ยิ่งต่ำยิ่งดี)
  - **Total Length**: ความยาวรวมของ Contigs ทั้งหมด
  - **GC Content (%)**: สัดส่วนเบส G และ C

#### ตัวอย่างคำสั่ง Standalone:
```bash
quast.py flye_output/assembly.fasta -o quast_report --min-contig 500 --threads 4
```""")

    # Stage 6
    md_cell("""### 🗺️ Stage 6: Read Mapping & Contig Coverage Calculation (การคำนวณความลึกในการอ่าน)

#### วัตถุประสงค์:
นำ Reads กลับไป Map กับ Contigs ที่ประกอบได้ เพื่อคำนวณว่าแต่ละ Contig มีความลึกการอ่าน (Coverage depth) เท่าใด ซึ่งค่านี้เป็นข้อมูลสำคัญที่สุดที่อัลกอริทึม Binning ใช้แยกสปีชีส์

#### Tools ที่ใช้:
1. **`Minimap2`**: Align long reads เข้าหา `assembly.fasta`
2. **`Samtools`**: แปลง SAM เป็น Sorted BAM และสร้าง Index (`.bai`)
3. **`jgi_summarize_bam_contig_depths`** (จาก MetaBAT2) หรือ **`CoverM`**: คำนวณตาราง Depth Matrix

#### ตัวอย่างคำสั่ง Standalone:
```bash
# 1. Map reads กลับหา Contigs
minimap2 -ax map-ont -t 4 assembly.fasta clean_reads.fastq | \\
samtools sort -@ 4 -o contig_alignment.sorted.bam -
samtools index contig_alignment.sorted.bam

# 2. คำนวณตาราง Depth
jgi_summarize_bam_contig_depths --outputDepth depth.txt contig_alignment.sorted.bam
```""")

    # Stage 7
    md_cell("""### 📦 Stage 7: Metagenome-Assembled Genomes (MAG) Binning (การจัดกลุ่มจีโนม)

#### วัตถุประสงค์:
แยก Contigs ที่ปะปนกันอยู่ในชุมชนจุลชีพ ออกเป็นกลุ่มๆ (Bins) โดยแต่ละ Bin เป็นตัวแทนของจีโนม 1 สปีชีส์ (Metagenome-Assembled Genome หรือ MAG)

#### อัลกอริทึมที่ใช้พิจารณา:
1. **Tetranucleotide Frequency (TNF)**: ความถี่ของชุด 4 เบสที่เป็นลายเซ็นเฉพาะตัวของสิ่งมีชีวิตแต่ละชนิด
2. **Differential Coverage**: Contigs ที่มาจากสิ่งมีชีวิตตัวเดียวกัน จะมีความลึกของ Coverage สอดคล้องกัน

#### Tools ที่ใช้:
1. **`MetaBAT2`**: มาตรฐานสากลสำหรับ Metagenome Binning ที่รวดเร็วและแม่นยำ
2. **`SemiBin2`**: ใช้ Deep Learning (Siamese Neural Network) เหมาะมากสำหรับ Long-read Metagenomics
3. **`MaxBin2` / `CONCOCT`**: Binner เสริม
4. **`DAS Tool`**: รวมผลลัพธ์จากหลายๆ Binner และคัดเลือกชุดที่ดีที่สุด (De-replication & Refinement)

#### ตัวอย่างคำสั่ง Standalone:
```bash
metabat2 -i assembly.fasta -a depth.txt -o metabat_bins/bin -m 1500 --saveCls
```""")

    # Stage 8
    md_cell("""### 🏆 Stage 8: MAG Quality Control & Taxonomic Assignment (การตรวจสอบคุณภาพ MAGs)

#### วัตถุประสงค์:
ประเมินความสมบูรณ์และการปนเปื้อนของ MAGs ตามมาตรฐาน **MIMAG (Minimum Information about a Metagenome-Assembled Genome)**:
- **High-Quality MAG**: Completeness > 90% และ Contamination < 5%
- **Medium-Quality MAG**: Completeness ≥ 50% และ Contamination < 10%

#### Tools ที่ใช้:
1. **`CheckM2`**: ประเมิน Completeness & Contamination โดยใช้โมเดล Machine Learning (Gradient Boosted Trees)
2. **`GUNC` (Genome Unclutterer)**: ตรวจสอบความผิดปกติของสายพันธุกรรมแบบผสมข้ามสายพันธุ์ (Chimerism detection)
3. **`GTDB-Tk`**: ระบุชื่อสปีชีส์และสายวิวัฒนาการตามฐานข้อมูล Genome Taxonomy Database (GTDB)""")

    # Stage 9
    md_cell("""### 🌿 Stage 9: Assembly-Free Taxonomic & Functional Profiling (การระบุสปีชีส์โดยตรงจาก Reads)

#### วัตถุประสงค์:
วิเคราะห์โครงสร้างประชากรจุลชีพโดยตรงจาก Raw Reads โดยไม่ต้องรอ Assembly ทำให้ตรวจจับจุลชีพที่มีปริมาณน้อย (Low-abundance taxa) ที่ไม่สามารถประกอบเป็น Contig ได้

#### Tools ที่ใช้:
1. **`Kraken2`**: โปรแกรมจำแนกสปีชีส์ที่เร็วที่สุด โดยใช้วิธีจับคู่ k-mer (Exact k-mer matching) กับฐานข้อมูล NCBI Taxonomy
2. **`Bracken`**: ใช้วิธีทางสถิติแบบ Bayesian เพื่อประมาณการสัดส่วนความชุกชุม (Abundance estimation) ที่ระดับ Species/Genus
3. **`Krona`**: สร้างแผนภูมิวงกลมแบบอินเทอร์แอคทีฟ (Multi-layered Interactive Pie Chart) ให้ผู้ใช้คลิกสำรวจลำดับขั้นทางอนุกรมวิธาน
4. **`HUMAnN3`**: วิเคราะห์ศักยภาพการทำงานและวิถีทางเมแทบอลิซึม (Metabolic Pathways / UniRef / MetaCyc)

#### ตัวอย่างคำสั่ง Standalone:
```bash
# รัน Kraken2 กับ Long Reads
kraken2 --db /path/to/kraken2_db \\
        --threads 4 \\
        --report sample.kraken.report.txt \\
        --output sample.kraken.out \\
        microbial_clean_reads.fastq

# แปลงผลลัพธ์เป็นกราฟ Krona HTML
ktImportTaxonomy -q 2 -t 3 sample.kraken.report.txt -o sample.krona.html
```""")

    # Stage 10 & 11
    md_cell("""### 🧬 Stage 10: Functional & Structural Annotation (การทำนายหน้าที่ของยีน)

#### Tools ที่ใช้:
1. **`Prokka`**: เครื่องมือทำนายตำแหน่งยีน (Gene prediction) อย่างรวดเร็ว ค้นหาตำแหน่ง Coding Sequences (CDS), tRNA, rRNA, และ Signal peptides
2. **`geNomad`**: ระบุชิ้นส่วนของไวรัส/แบคทีริโอเฟจ (Phages/Viruses) และพลาสมิด (Plasmids) ที่แฝงอยู่ในชุมชนจุลชีพ

---

### 📑 Stage 11: Multi-Omics Aggregated Reporting (การสรุปรายงานผลลัพธ์)

#### Tools ที่ใช้:
1. **`MultiQC`**: รวมผลลัพธ์การตรวจสอบคุณภาพจากทุกโมดูล (FastQC, NanoPlot, Fastp, QUAST, Kraken2) ไว้ในหน้าเว็บ HTML เดียว
2. **`generate_report.py`**: สคริปต์ Python สำหรับสร้างรายงานสรุปผลลัพธ์ในรูปแบบ Markdown และ HTML Dashboard""")

    # ──────────────────────────────────────────────────────────────────────────
    # SECTION 2: RUNNING PIPELINE MODES
    # ──────────────────────────────────────────────────────────────────────────
    md_cell("""---
## 🚀 ส่วนที่ 2: สั่งรัน Pipeline ด้วย Nextflow จาก Jupyter Notebook

เราสามารถรัน Pipeline ผ่านคำสั่งเชลล์ `run_meta_npi.sh` หรือเรียกคำสั่ง `nextflow run` โดยตรงได้ 3 รูปแบบ:
1. **Dry-Run (`-preview`)**: ตรวจสอบการเชื่อมต่อ Channel โดยไม่ต้องรันจริง
2. **Smoke Test (`smoke`)**: ทดสอบด้วย Barcode14 และ Barcode16 (ใช้เวลา ~2-5 นาที)
3. **Benchmark Mode (`benchmark`)**: รันประกอบจีโนมเต็มรูปแบบด้วย Barcode01 และ Barcode21""")

    code_cell("""# 1. ตรวจสอบการเชื่อมต่อ DAG ของ Nextflow (Dry-run Preview)
!./run_meta_npi.sh dry-run""")

    code_cell("""# 2. คำสั่งรัน Smoke Test (Barcode14 & Barcode16)
# ปลดคอมเมนต์บรรทัดด้านล่างเมื่อต้องการสั่งรันจริง
# !./run_meta_npi.sh smoke docker

print("💡 ทิป: สามารถสั่งรันใน Terminal ด้วยคำสั่ง: ./run_meta_npi.sh smoke docker")""")

    # ──────────────────────────────────────────────────────────────────────────
    # SECTION 3: RESULTS VISUALIZATION & DATA SCIENCE
    # ──────────────────────────────────────────────────────────────────────────
    md_cell("""---
## 📈 ส่วนที่ 3: การวิเคราะห์และแสดงผลข้อมูลผลลัพธ์ (Interactive Visualizations)

เมื่อ Pipeline รันเสร็จสิ้น ผลลัพธ์จะถูกจัดเก็บไว้ในโฟลเดอร์ `results_meta_npi_smoke/` หรือ `results_meta_npi_benchmark/`""")

    code_cell("""# ฟังก์ชันตัวอย่างสำหรับการโหลดและพล็อตกราฟ QUAST Assembly Metrics
def plot_quast_metrics(report_path):
    if not os.path.exists(report_path):
        print(f"ℹ️ ยังไม่พบไฟล์รายงาน QUAST ที่: {report_path} (จะปรากฏหลังรัน Pipeline เสร็จสิ้น)")
        return
        
    df_quast = pd.read_csv(report_path, sep='\t')
    display(df_quast)

# ตัวอย่างการอ่านไฟล์ QUAST จากผลลัพธ์ Benchmark
quast_benchmark_path = WORKSPACE_DIR / "results_meta_npi_benchmark" / "assembly_qc" / "quast" / "barcode01_quast_report.tsv"
plot_quast_metrics(quast_benchmark_path)""")

    code_cell("""# ฟังก์ชันสำหรับอ่านและพล็อตกราฟ Taxonomic Composition จาก Kraken2 Report
def plot_kraken2_composition(report_path, top_n=10):
    if not os.path.exists(report_path):
        print(f"ℹ️ ยังไม่พบไฟล์ Kraken2 Report ที่: {report_path}")
        return
        
    columns = ["pct", "reads_clade", "reads_direct", "rank", "tax_id", "name"]
    df = pd.read_csv(report_path, sep='\\t', names=columns)
    df['name'] = df['name'].str.strip()
    
    # กรองเฉพาะระดับ Genus (G) หรือ Species (S)
    df_genus = df[df['rank'] == 'G'].sort_values(by='reads_clade', ascending=False).head(top_n)
    
    if df_genus.empty:
        print("ไม่พบข้อมูลระดับ Genus")
        return
        
    plt.figure(figsize=(10, 5))
    sns.barplot(data=df_genus, x="reads_clade", y="name", palette="Blues_r")
    plt.title(f"Top {top_n} Abundant Genera (Kraken2 Profiling)", fontsize=13, fontweight='bold')
    plt.xlabel("Clade Reads")
    plt.ylabel("Genus")
    plt.grid(True, linestyle='--', alpha=0.5)
    plt.show()

# ตัวอย่างการอ่านรายงาน Kraken2
kraken_sample_path = WORKSPACE_DIR / "results_meta_npi_smoke" / "assembly_free" / "kraken2" / "barcode14.kraken2.report.txt"
plot_kraken2_composition(kraken_sample_path)""")

    code_cell("""# ฟังก์ชันสำหรับแสดงรายงานแบบ Interactive Dashboard ใน Notebook (MultiQC & Krona)
def display_html_dashboard(html_path, height=600):
    if os.path.exists(html_path):
        return IFrame(src=str(html_path), width="100%", height=height)
    else:
        print(f"ℹ️ ยังไม่พบไฟล์รายงาน HTML ที่: {html_path}")

# ตัวอย่างการแสดง MultiQC Report
multiqc_path = WORKSPACE_DIR / "results_meta_npi_smoke" / "reporting" / "multiqc" / "multiqc_report.html"
display_html_dashboard(multiqc_path)""")

    # ──────────────────────────────────────────────────────────────────────────
    # SECTION 4: BEST PRACTICES & SUMMARY
    # ──────────────────────────────────────────────────────────────────────────
    md_cell("""---
## 💡 ส่วนที่ 4: สรุปและแนวทางปฏิบัติที่ดี (Best Practices & FAQ)

### 📌 สรุปเทคนิคสำคัญสำหรับ Oxford Nanopore Metagenomics:
1. **Dorado SUP Reads**: ให้ใช้ `flye_mode = '--nano-hq'` ร่วมกับ `--meta` เพื่อผลลัพธ์การประกอบที่ดีที่สุด
2. **การกรองคุณภาพ**: แนะนำ `min_quality_long = 10` และ `min_length_long = 300 - 500 bp` เพื่อลดความผิดพลาดในการประกอบ Contigs
3. **การประหยัดเวลาคำนวณ**: สามารถข้ามขั้นตอน Polishing (`run_polishing = false`) สำหรับข้อมูล SUP Q17+ โดยไม่สูญเสียความแม่นยำของจีโนม
4. **การรันซ้ำอย่างมีประสิทธิภาพ**: ใช้แฟล็ก `-resume` ของ Nextflow เสมอ เพื่อให้รันต่อจากจุดเดิมโดยไม่ต้องเริ่มกระบวนการใหม่ทั้งหมด

---
**จัดทำโดย**: Antigravity AI & Metagenomics Pipeline Team 🚀""")

    # Write out the notebook JSON
    output_path = "/home/surj/Workspace/metagenomics-pipeline/notebooks/Meta_NPI_Workflow_Walkthrough.ipynb"
    with open(output_path, "w", encoding="utf-8") as f:
        json.dump(nb, f, indent=2, ensure_ascii=False)
    print(f"✅ Notebook successfully created at: {output_path}")

if __name__ == "__main__":
    create_notebook()
