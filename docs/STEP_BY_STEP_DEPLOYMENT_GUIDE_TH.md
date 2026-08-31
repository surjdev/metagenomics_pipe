# 🤝 คู่มือปฏิบัติการแบบจับมือทำ: การติดตั้ง ตั้งค่า และรัน Metagenomics Pipeline บนทุกสภาพแวดล้อม
> **Step-by-Step Hands-On Deployment & Run Guide for Hybrid Metagenomics Pipeline**  
> คู่มือสอนทีละขั้นตอน (Step-by-step) สำหรับผู้เริ่มต้น ตั้งแต่ติดตั้งโปรแกรม จัดเตรียมไฟล์ข้อมูล ดาวน์โหลดฐานข้อมูล เลือกรันบนสภาพแวดล้อมต่างๆ (Local / Docker / Singularity / SLURM HPC) ไปจนถึงการเปิดดูรายงานผล

---

## 🧭 สารบัญการเรียนรู้ (Table of Contents)
- [ขั้นตอนที่ 1: ตรวจสอบและติดตั้งโปรแกรมพื้นฐาน (Prerequisites)](#ขั้นตอนที่-1-ตรวจสอบและติดตั้งโปรแกรมพื้นฐาน-prerequisites)
- [ขั้นตอนที่ 2: การเลือกและเตรียมสภาพแวดล้อม (Environment Setup)](#ขั้นตอนที่-2-การเลือกและเตรียมสภาพแวดล้อม-environment-setup)
  - [ทางเลือก A: รันผ่าน Pixi / Conda (รันตรงบนเครื่องโดยไม่ต้องใช้ Root/Sudo)](#ทางเลือก-a-รันผ่าน-pixi--conda-รันตรงบนเครื่องโดยไม่ต้องใช้-rootsudo)
  - [ทางเลือก B: รันผ่าน Docker (สำหรับ PC / Server ทั่วไป)](#ทางเลือก-b-รันผ่าน-docker-สำหรับ-pc--server-ทั่วไป)
  - [ทางเลือก C: รันผ่าน Singularity / Apptainer (สำหรับเครื่องเซิร์ฟเวอร์ส่วนกลาง)](#ทางเลือก-c-รันผ่าน-singularity--apptainer-สำหรับเครื่องเซิร์ฟเวอร์ส่วนกลาง)
  - [ทางเลือก D: รันบน HPC Cluster ด้วยระบบจัดการคิว SLURM](#ทางเลือก-d-รันบน-hpc-cluster-ด้วยระบบจัดการคิว-slurm)
- [ขั้นตอนที่ 3: การเตรียมไฟล์ตัวอย่าง (Samplesheet Preparation)](#ขั้นตอนที่-3-การเตรียมไฟล์ตัวอย่าง-samplesheet-preparation)
  - [แบบที่ 1: ข้อมูล Illumina Short Reads (Paired-end)](#แบบที่-1-ข้อมูล-illumina-short-reads-paired-end)
  - [แบบที่ 2: ข้อมูล Oxford Nanopore Long Reads](#แบบที่-2-ข้อมูล-oxford-nanopore-long-reads)
  - [แบบที่ 3: ข้อมูล Hybrid (Short + Long Reads)](#แบบที่-3-ข้อมูล-hybrid-short--long-reads)
- [ขั้นตอนที่ 4: การดาวน์โหลดและติดตั้งฐานข้อมูลอ้างอิง (Reference Databases)](#ขั้นตอนที่-4-การดาวน์โหลดและติดตั้งฐานข้อมูลอ้างอิง-reference-databases)
- [ขั้นตอนที่ 5: การรัน Pipeline จริงทีละสเต็ป (Execution Commands)](#ขั้นตอนที่-5-การรัน-pipeline-จริงทีละสเต็ป-execution-commands)
  - [5.1 รันแบบทดสอบความถูกต้องอย่างรวดเร็ว (Smoke Test / Dry-Run)](#51-รันแบบทดสอบความถูกต้องอย่างรวดเร็ว-smoke-test--dry-run)
  - [5.2 รันข้อมูลจริงเต็มรูปแบบ (Full Production Run)](#52-รันข้อมูลจริงเต็มรูปแบบ-full-production-run)
  - [5.3 การใช้คำสั่ง `-resume` เมื่อต้องการรันต่อจากจุดเดิม](#53-การใช้คำสั่ง--resume-เมื่อต้องการรันต่อจากจุดเดิม)
- [ขั้นตอนที่ 6: การตรวจสอบและเปิดดูผลลัพธ์ (Checking Output Reports)](#ขั้นตอนที่-6-การตรวจสอบและเปิดดูผลลัพธ์-checking-output-reports)
- [ขั้นตอนที่ 7: วิธีแก้ปัญหาที่พบบ่อย (Troubleshooting & FAQs)](#ขั้นตอนที่-7-วิธีแก้ปัญหาที่พบบ่อย-troubleshooting--faqs)

---

# ขั้นตอนที่ 1: ตรวจสอบและติดตั้งโปรแกรมพื้นฐาน (Prerequisites)

ก่อนเริ่มใช้งาน ให้เปิด Terminal บน Linux/macOS หรือ WSL2 (Windows Subsystem for Linux) แล้วตรวจสอบโปรแกรม 2 ตัวหลัก:

### 1.1 ตรวจสอบ Java (ต้องเป็นเวอร์ชัน 11 ขึ้นไป)
```bash
java -version
```
*ถ้ายังไม่มี ให้ติดตั้งด้วยคำสั่ง:*
```bash
# บน Ubuntu / Debian:
sudo apt update && sudo apt install -y openjdk-17-jre-headless
```

### 1.2 ติดตั้ง Nextflow
Nextflow คือหัวใจหลักที่ใช้ควบคุมการทำงานของทุกเครื่องมือใน Pipeline:
```bash
# ดาวน์โหลดตัวติดตั้ง Nextflow
curl -s https://get.nextflow.io | bash

# ย้ายไปไว้ที่โฟลเดอร์ bin ในเครื่องเพื่อให้เรียกใช้ได้ทุกที่
mkdir -p ~/.local/bin
mv nextflow ~/.local/bin/
export PATH="$HOME/.local/bin:$PATH"

# ตรวจสอบการติดตั้ง
nextflow -v
# ตัวอย่างผลลัพธ์: nextflow version 24.04.2.5914 หรือใหม่กว่า
```

---

# ขั้นตอนที่ 2: การเลือกและเตรียมสภาพแวดล้อม (Environment Setup)

Pipeline นี้ถูกออกแบบให้รันได้ 4 สภาพแวดล้อมหลัก ให้คุณเลือก **1 ทางเลือก** ที่ตรงกับเครื่องของคุณมากที่สุด:

```
                  ┌────────────────────────────────────────┐
                  │ คุณต้องการรัน Pipeline บนระบบใด?         │
                  └───────────────────┬────────────────────┘
                                      │
         ┌────────────────────────────┼────────────────────────────┐
         ▼                            ▼                            ▼
  [ทางเลือก A: Pixi/Conda]     [ทางเลือก B: Docker]     [ทางเลือก C: Singularity / HPC SLURM]
  เหมาะสำหรับ PC/Workstation   เหมาะสำหรับ Server/PC    เหมาะสำหรับ Supercomputer / HPC
  ไม่ต้องใช้สิทธิ์ root         ที่มี Docker service     ที่มีระบบ Singularity และ SLURM
```

---

### ทางเลือก A: รันผ่าน Pixi / Conda (รันตรงบนเครื่องโดยไม่ต้องใช้ Root/Sudo)
> 💡 **เหมาะสำหรับ**: ผู้ที่ใช้งานบน Workstation หรือ Server ส่วนตัว และไม่มีสิทธิ์ `sudo` หรือไม่ต้องการเปิด Docker service

ในโปรเจกต์นี้มีระบบจัดการ Environment ด้วย **Pixi** เตรียมไว้แล้ว:
```bash
# 1. ติดตั้ง Pixi (ครั้งเดียวจบ)
curl -fsSL https://pixi.sh/install.sh | bash
export PATH="$HOME/.pixi/bin:$PATH"

# 2. เข้าสู่โฟลเดอร์โปรเจกต์
cd /path/to/metagenomics-pipeline

# 3. ติดตั้งเครื่องมือชีวสารสนเทศทั้งหมดอัตโนมัติจากไฟล์ pixi.lock
pixi install

# 4. ทดสอบรันด้วย Profile local
nextflow run main.nf -profile local,test
```

---

### ทางเลือก B: รันผ่าน Docker (สำหรับ PC / Server ทั่วไป)
> 💡 **เหมาะสำหรับ**: ผู้ที่มี Docker ติดตั้งอยู่แล้วบนเครื่อง

1. ตรวจสอบว่า Docker Daemon กำลังทำงาน:
   ```bash
   docker ps
   ```
2. เมื่อรัน Pipeline ให้ใส่พารามิเตอร์ `-profile docker`:
   ```bash
   nextflow run main.nf -profile docker,test
   ```
   *Nextflow จะทำการดาวน์โหลด Docker Containers ของแต่ละเครื่องมือ (เช่น FastQC, Flye, MetaBAT2) จาก Biocontainers มาให้อัตโนมัติ โดยที่คุณไม่ต้องลงโปรแกรมเองเลย*

---

### ทางเลือก C: รันผ่าน Singularity / Apptainer (สำหรับเครื่องเซิร์ฟเวอร์ส่วนกลาง)
> 💡 **เหมาะสำหรับ**: สภาพแวดล้อมที่ไม่อนุญาตให้ใช้ Docker เนื่องจากเหตุผลด้านความปลอดภัย

```bash
# รันด้วย Profile singularity
nextflow run main.nf -profile singularity,test
```
*Singularity จะดาวน์โหลด Image และแปลงเป็นไฟล์ `.sif` เก็บไว้ในแคชอัตโนมัติ*

---

### ทางเลือก D: รันบน HPC Cluster ด้วยระบบจัดการคิว SLURM
> 💡 **เหมาะสำหรับ**: มหาวิทยาลัยหรือสถาบันวิจัยที่มีระบบ Supercomputer / Cluster

ไฟล์คอนฟิก [`conf/slurm.config`](file:///home/surj/Workspace/metagenomics-pipeline/conf/slurm.config) ถูกตั้งค่าไว้รองรับ SLURM Executor แล้ว:
```bash
# รันบน Cluster โดยส่ง Job ผ่าน SLURM + Singularity
nextflow run main.nf \
    -profile slurm,singularity \
    -c conf/slurm.config \
    --input samplesheet.csv \
    --outdir results_hpc \
    -bg
```
*(คำสั่ง `-bg` จะทำให้ Nextflow ทำงานอยู่เบื้องหลัง แม้เราจะปิดหน้าต่าง SSH ไปแล้วก็ตาม)*

---

# ขั้นตอนที่ 3: การเตรียมไฟล์ตัวอย่าง (Samplesheet Preparation)

ก่อนสั่งรัน คุณต้องบอก Pipeline ว่าคุณมีตัวอย่างชื่ออะไรบ้าง และไฟล์ FASTQ เก็บอยู่ที่ไหน โดยสร้างไฟล์ตาราง `.csv`

### แบบที่ 1: ข้อมูล Illumina Short Reads (Paired-end)
สร้างไฟล์ชื่อ `samplesheet_illumina.csv`:
```csv
sample,short_reads_1,short_reads_2
gut_sample_01,/data/illumina/sample01_R1.fastq.gz,/data/illumina/sample01_R2.fastq.gz
gut_sample_02,/data/illumina/sample02_R1.fastq.gz,/data/illumina/sample02_R2.fastq.gz
```

---

### แบบที่ 2: ข้อมูล Oxford Nanopore Long Reads
สร้างไฟล์ชื่อ `samplesheet_ont.csv`:
```csv
sample,long_reads
barcode01,/data/ont/barcode01/reads.fastq.gz
barcode02,/data/ont/barcode02/reads.fastq.gz
```

---

### แบบที่ 3: ข้อมูล Hybrid (Short + Long Reads)
สร้างไฟล์ชื่อ `samplesheet_hybrid.csv`:
```csv
sample,short_reads_1,short_reads_2,long_reads
soil_sample_01,/data/short_R1.fastq.gz,/data/short_R2.fastq.gz,/data/long_reads.fastq.gz
```

> 🪄 **เคล็ดลับพิเศษ**: คุณสามารถใช้สคริปต์ Python ที่เตรียมไว้ในโฟลเดอร์ `bin/` ช่วยสแกนและสร้าง Samplesheet ให้อัตโนมัติ:
> ```bash
> python3 bin/generate_samplesheet_meta_npi.py
> ```

---

# ขั้นตอนที่ 4: การดาวน์โหลดและติดตั้งฐานข้อมูลอ้างอิง (Reference Databases)

เครื่องมือบางตัว เช่น **Kraken2** (ระบุสปีชีส์), **CheckM2** (ตรวจคุณภาพ MAGs), **GTDB-Tk** (ระบุ Taxonomy), และ **geNomad** (ตรวจไวรัส/พลาสมิด) จำเป็นต้องมีฐานข้อมูลอ้างอิง

### 4.1 ดาวน์โหลดผ่าน Script อัตโนมัติ:
```bash
chmod +x databases/download.sh

# ทางเลือกที่ 1: ดาวน์โหลดฐานข้อมูลขนาดเล็กสำหรับทดสอบ (Tiny DBs)
# ฐานข้อมูลนี้มีพร้อมอยู่ในโปรเจกต์แล้วที่: test/data/tiny_databases/

# ทางเลือกที่ 2: ดาวน์โหลดฐานข้อมูลจริงสำหรับการวิเคราะห์งานวิจัย (Production DBs)
./databases/download.sh --kraken2 /data/databases/kraken2_standard
./databases/download.sh --checkm2 /data/databases/checkm2_db
./databases/download.sh --genomad /data/databases/genomad_db
```

### 4.2 การระบุพาร์ทฐานข้อมูลในไฟล์ Config
เปิดไฟล์ [`params/databases.yaml`](file:///home/surj/Workspace/metagenomics-pipeline/params/databases.yaml) หรือส่งผ่านคำสั่งรัน:
```yaml
params {
    host_genome  = "/data/databases/human_GRCh38.fasta"
    kraken2_db   = "/data/databases/kraken2_standard"
    checkm2_db   = "/data/databases/checkm2_db"
    genomad_db   = "/data/databases/genomad_db"
}
```

---

# ขั้นตอนที่ 5: การรัน Pipeline จริงทีละสเต็ป (Execution Commands)

---

### 5.1 รันแบบทดสอบความถูกต้องอย่างรวดเร็ว (Smoke Test / Dry-Run)

#### วิธีที่ 1: ใช้ Script ผู้ช่วยสำเร็จรูป (`run_meta_npi.sh`)
```bash
chmod +x run_meta_npi.sh

# ตรวจสอบการต่อสาย DAG โดยไม่รันเครื่องมือจริง
./run_meta_npi.sh dry-run local

# รัน Smoke Test (ตัวอย่าง Barcode14 & Barcode16 ใช้เวลา ~2 นาที)
./run_meta_npi.sh smoke local
```

#### วิธีที่ 2: ใช้คำสั่ง Nextflow โดยตรง
```bash
nextflow run main.nf \
    -profile local,test \
    -c conf/meta_npi.config \
    --input samplesheet_meta_npi_smoke.csv \
    --outdir results_smoke
```

---

### 5.2 รันข้อมูลจริงเต็มรูปแบบ (Full Production Run)

#### คำสั่งสำหรับ Nanopore Long Reads (เช่น ชุดข้อมูล Meta_NPI ทั้งหมด 17 Barcodes):
```bash
./run_meta_npi.sh full local
```
หรือรันด้วย Nextflow:
```bash
nextflow run main.nf \
    -profile local \
    -c conf/meta_npi.config \
    --input samplesheet_meta_npi_full.csv \
    --outdir results_meta_npi_full \
    -with-report results_meta_npi_full/pipeline_info/execution_report.html \
    -with-timeline results_meta_npi_full/pipeline_info/execution_timeline.html \
    -with-trace results_meta_npi_full/pipeline_info/execution_trace.txt \
    -with-dag results_meta_npi_full/pipeline_info/pipeline_dag.html
```

#### คำสั่งสำหรับ Illumina Short Reads:
```bash
nextflow run main.nf \
    -profile docker \
    -params-file params/illumina.yaml \
    --input samplesheet_illumina.csv \
    --outdir results_illumina
```

#### คำสั่งสำหรับ Hybrid (Illumina + Nanopore):
```bash
nextflow run main.nf \
    -profile docker \
    -params-file params/hybrid.yaml \
    --input samplesheet_hybrid.csv \
    --outdir results_hybrid
```

---

### 5.3 การใช้คำสั่ง `-resume` เมื่อต้องการรันต่อจากจุดเดิม

> ⚡ **ฟีเจอร์เด็ดของ Nextflow**: หากเครื่องไฟดับ หรือคุณต้องการเพิ่มตัวอย่างใหม่ Nextflow จะไม่เริ่มนับหนึ่งใหม่ แต่จะดึงแคชจากโฟลเดอร์ `work/` มารันต่อจากจุดล่าสุดทันที!

เพียงเติม `-resume` ท้ายคำสั่งเดิม:
```bash
nextflow run main.nf -profile local --input samplesheet.csv --outdir results/ -resume
```

---

# ขั้นตอนที่ 6: การตรวจสอบและเปิดดูผลลัพธ์ (Checking Output Reports)

เมื่อประมวลผลเสร็จสิ้น ผลลัพธ์ทั้งหมดจะถูกรวบรวมอย่างเป็นระเบียบไว้ที่โฟลเดอร์ `--outdir` ที่คุณกำหนด (เช่น `results_meta_npi_full/`):

```
results_meta_npi_full/
├── 📊 reporting/
│   ├── multiqc/multiqc_report.html            <-- แดชบอร์ดสรุป QC รวมทุกเครื่องมือ (เปิดด้วยเว็บเบราว์เซอร์)
│   └── pipeline_report.html                  <-- รายงานสรุปผลภาพรวมทั้ง Pipeline (Jinja2 HTML)
├── 🦠 assembly_free/
│   ├── krona/barcode14.krona.html            <-- แผนภูมิพายอินเทอร์แอคทีฟแสดงสปีชีส์จุลินทรีย์ (คลิกซูมได้)
│   ├── kraken2/barcode14_kraken2_report.txt  <-- ตารางแจกแจงจำนวน Reads ตาม Taxonomy
│   └── biom/table.biom                       <-- ไฟล์ตาราง Abundance สำหรับนำเข้า R/QIIME2
├── 🧩 assembly_qc/
│   └── quast/barcode14/report.html           <-- กราฟและตารางประเมินคุณภาพ Contigs (N50, ความยาวรวม)
├── 📦 binning/
│   └── metabat2/barcode14/                   <-- โฟลเดอร์เก็บไฟล์ FASTA ของแต่ละ MAG Bins
├── 🧬 annotation/
│   └── prokka/barcode14/barcode14.gff        <-- ไฟล์ระบุตำแหน่งยีนและโปรตีน
└── 📈 pipeline_info/
    ├── execution_report.html                 <-- สถิติการใช้ CPU/RAM ของคอมพิวเตอร์
    └── execution_timeline.html               <-- แผนภูมิระยะเวลาการทำงานของแต่ละ Process
```

### 🖥️ วิธีเปิดดูรายงาน HTML บนเครื่องของคุณ:
* **ถ้าอยู่บนเครื่องตนเอง**: ดับเบิลคลิกไฟล์ `.html` เพื่อเปิดบน Chrome / Firefox / Safari ได้ทันที
* **ถ้าอยู่บน Remote Server**: ดาวน์โหลดไฟล์รายงานลงมาดูด้วย `scp` หรือ `rsync`:
  ```bash
  scp user@server:/path/to/results_meta_npi_full/reporting/multiqc/multiqc_report.html ./
  ```

---

# ขั้นตอนที่ 7: วิธีแก้ปัญหาที่พบบ่อย (Troubleshooting & FAQs)

| อาการ / ข้อผิดพลาด | สาเหตุที่เป็นไปได้ | วิธีแก้ไข |
|---|---|---|
| `failed to connect to docker API` / `docker.sock: connect: no such file or directory` | Docker service ไม่ได้เปิดทำงาน หรือไม่มีสิทธิ์เข้าถึง Docker | สลับไปใช้ Profile **`-profile local`** หรือเปิดใช้งาน Docker daemon ด้วย `sudo systemctl start docker` |
| `Process '...' was terminated (exit code 137)` | หน่วยความจำ RAM ของเครื่องไม่พอ (Out of Memory - OOM) | ปรับเพิ่ม RAM ใน `conf/meta_npi.config` ตรง `max_memory = '16.GB'` หรือ Nextflow จะ Retry รอบ 2 ให้อัตโนมัติ |
| `Command 'nextflow' not found` | ไม่ได้เพิ่ม Path ของ Nextflow ใน `.bashrc` | สั่ง `export PATH="$HOME/.local/bin:$PATH"` หรือเปิดไฟล์ `~/.bashrc` แล้วเพิ่มบรรทัดนี้ไว้ท้ายไฟล์ |
| `Input file does not exist: ...` | พาร์ทไฟล์ใน Samplesheet CSV ผิด | แนะนำให้ใช้ **Absolute Path** (พาร์ทเต็ม เช่น `/home/user/data/reads.fastq`) แทน Relative Path |
| `Kraken2 database not found` | ยังไม่ได้ระบุพาร์ทฐานข้อมูล | ตรวจสอบค่า `kraken2_db` ในไฟล์ `conf/meta_npi.config` หรือ `params/databases.yaml` ให้ชี้ไปยังโฟลเดอร์ฐานข้อมูลที่ถูกต้อง |

---

> 🎉 **ยินดีด้วย!** ตอนนี้คุณพร้อมแล้วที่จะนำ Pipeline นี้ไปประมวลผลงานวิจัย Metagenomics บนทุกสภาพแวดล้อมได้อย่างมั่นใจ!
