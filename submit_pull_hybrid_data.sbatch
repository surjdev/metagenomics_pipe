#!/bin/bash
# ==============================================================================
# submit_pull_hybrid_data.sbatch — SLURM Job Script to Pull Hybrid Metagenomics Data
# ==============================================================================
#SBATCH --job-name=pull_hybrid_data
#SBATCH --output=slurm_pull_%j.out
#SBATCH --error=slurm_pull_%j.err
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=8
#SBATCH --mem=32G
#SBATCH --time=06:00:00
#SBATCH --partition=cpu

set -eo pipefail

echo "=============================================================================="
echo " 📥 Starting SLURM Job: ${SLURM_JOB_NAME:-pull_hybrid_data} (Job ID: ${SLURM_JOB_ID})"
echo " 🖥️  Running on Node   : $(hostname)"
echo " ⚙️  Allocated CPUs    : ${SLURM_CPUS_PER_TASK:-8}"
echo " 💾 Allocated Memory  : 32G"
echo " ⏱️  Start Time        : $(date '+%Y-%m-%d %H:%M:%S')"
echo "=============================================================================="

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "${SCRIPT_DIR}"

# 1. โหลด Conda Environment
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
fi

echo "🔄 Activating Conda environment..."
conda activate metagenomics || true

# 2. ตรวจสอบ dependencies (fasterq-dump, prefetch, pigz)
if ! command -v fasterq-dump &> /dev/null || ! command -v prefetch &> /dev/null; then
    echo "❌ [ERROR] ไม่พบคำสั่ง 'fasterq-dump' หรือ 'prefetch' กรุณาติดตั้ง sra-tools: conda install -c bioconda sra-tools pigz -y"
    exit 1
fi

# ตรวจสอบการเชื่อมต่ออินเทอร์เน็ตเบื้องต้นของ Compute Node
echo "🌐 Checking network connectivity to NCBI SRA AWS S3..."
if curl -Is --connect-timeout 6 https://sra-pub-run-odp.s3.amazonaws.com > /dev/null 2>&1; then
    echo "  ✓ Network connection to SRA repository is active."
else
    echo "  ⚠️ [WARNING] ไม่สามารถเชื่อมต่อกับ SRA AWS S3 ได้จาก Node นี้ ($(hostname))"
    echo "     โหนดคำนวณ (Compute Node) บน HPC ส่วนใหญ่มักถูกตัดอินเทอร์เน็ตภายนอก"
    echo "     หากดาวน์โหลดล้มเหลว แนะนำให้รันบน Login Node หรือ Data Node โดยตรง:"
    echo "       ./bin/pull_hybrid_data_fasterq.sh --full"
fi

chmod +x ./bin/pull_hybrid_data_fasterq.sh

# 3. รันการดาวน์โหลดข้อมูลสำหรับ samplesheet_hybrid.csv (CD22, CD3, TD22, TD3 - ข้าม CD35, TD35 เนื่องจากติดตั้งแล้ว)
# ค่าเริ่มต้น: --full (ดึงข้อมูลเต็ม) หากต้องการทดสอบก่อน ให้เปลี่ยนเป็น --test
MODE="${1:---full}"

echo "🚀 Executing ./bin/pull_hybrid_data_fasterq.sh ${MODE} --threads ${SLURM_CPUS_PER_TASK:-8}..."
./bin/pull_hybrid_data_fasterq.sh ${MODE} --threads "${SLURM_CPUS_PER_TASK:-8}"

echo "=============================================================================="
echo " 🎉 Download Job Finished! (Job ID: ${SLURM_JOB_ID})"
echo " ⏱️  End Time: $(date '+%Y-%m-%d %H:%M:%S')"
echo "=============================================================================="
