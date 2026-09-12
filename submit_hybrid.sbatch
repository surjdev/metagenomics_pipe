#!/bin/bash
# ==============================================================================
# submit_hybrid.sbatch — SLURM Job Script for Hybrid Metagenomics Pipeline
# ==============================================================================
#SBATCH --job-name=hybrid_meta
#SBATCH --output=slurm-%j.out
#SBATCH --error=slurm-%j.err
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=16
#SBATCH --mem=128G
#SBATCH --time=48:00:00
#SBATCH --partition=cpu
# #SBATCH --account=your_project   # ปลด comment หาก HPC บังคับระบุชื่อ account/project

set -eo pipefail

echo "=============================================================================="
echo " 🧬 Starting SLURM Job: ${SLURM_JOB_NAME:-hybrid_meta} (Job ID: ${SLURM_JOB_ID})"
echo " 🖥️  Running on Node   : $(hostname)"
echo " ⚙️  Allocated CPUs    : ${SLURM_CPUS_PER_TASK:-16}"
echo " 💾 Allocated Memory  : 128G"
echo " ⏱️  Start Time        : $(date '+%Y-%m-%d %H:%M:%S')"
echo "=============================================================================="

# 1. ย้ายไปยัง Root Directory ของ Pipeline
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WORK_DIR="${SLURM_SUBMIT_DIR:-${SCRIPT_DIR}}"
cd "${WORK_DIR}"

mkdir -p logs_slurm

# 2. โหลด Conda เข้าสู่ Non-interactive Shell และ Activate env 'metagenomics'
if command -v conda &> /dev/null; then
    CONDA_BASE="$(conda info --base)"
elif [ -d "$HOME/miniconda3" ]; then
    CONDA_BASE="$HOME/miniconda3"
elif [ -d "$HOME/anaconda3" ]; then
    CONDA_BASE="$HOME/anaconda3"
else
    CONDA_BASE="/opt/conda"
fi

if [ -f "${CONDA_BASE}/etc/profile.d/conda.sh" ]; then
    source "${CONDA_BASE}/etc/profile.d/conda.sh"
else
    echo "⚠️ ไม่พบ conda.sh พยายามใช้คำสั่ง conda activate โดยตรง"
fi

echo "🔄 Activating Conda environment: metagenomics..."
conda activate metagenomics

# ตรวจสอบคำสั่ง Nextflow
if ! command -v nextflow &> /dev/null; then
    echo "❌ [ERROR] ไม่พบคำสั่ง 'nextflow' ใน conda env 'metagenomics'"
    exit 1
fi

# ปิด ANSI escape sequences เพื่อให้ log file ใน logs_slurm สะอาดและอ่านง่าย
export NXF_ANSI_LOG=false

# 3. สั่งรัน Pipeline ผ่าน run_hybrid.sh
# - run_hybrid.sh มีคำสั่ง -resume อยู่แล้ว จึงจะหยิบ cache ที่รันเสร็จแล้ว (เช่น Bowtie2) มาใช้ต่ออัตโนมัติ
# - ส่ง --max_cpus และ --max_memory เพื่อให้ Nextflow จัดสรรทรัพยากรเต็มที่ตามที่ขอจาก SLURM
echo "🚀 Submitting Nextflow Hybrid Pipeline via run_hybrid.sh..."
chmod +x ./run_hybrid.sh

./run_hybrid.sh conda \
    --max_cpus "${SLURM_CPUS_PER_TASK:-16}" \
    --max_memory "128.GB"

echo "=============================================================================="
echo " 🎉 SLURM Job Finished Successfully! (Job ID: ${SLURM_JOB_ID})"
echo " ⏱️  End Time: $(date '+%Y-%m-%d %H:%M:%S')"
echo "=============================================================================="
