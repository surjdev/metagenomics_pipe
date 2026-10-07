#!/bin/bash
# ==============================================================================
# submit_chicken.sbatch — SLURM Batch Submission for Chicken Metagenomics Pipeline
# ==============================================================================
#SBATCH --job-name=chicken_meta
#SBATCH --output=logs_slurm/chicken_%j.out
#SBATCH --error=logs_slurm/chicken_%j.err
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=16
#SBATCH --mem=64G
#SBATCH --time=24:00:00
#SBATCH --partition=cpu

set -eo pipefail

echo "=============================================================================="
echo " 🐔 SLURM Job: ${SLURM_JOB_NAME} (Job ID: ${SLURM_JOB_ID})"
echo " 🖥️  Compute Node     : $(hostname)"
echo " ⚙️  Allocated CPUs   : ${SLURM_CPUS_PER_TASK:-16}"
echo " 💾 Allocated Memory : 64G"
echo " ⏱️  Start Time       : $(date '+%Y-%m-%d %H:%M:%S')"
echo "=============================================================================="

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WORK_DIR="${SLURM_SUBMIT_DIR:-${SCRIPT_DIR}}"
cd "${WORK_DIR}"

mkdir -p logs_slurm

# โหลด Conda Environment
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

echo "🔄 Activating Conda environment: metagenomics..."
conda activate metagenomics 2>/dev/null || true

if ! command -v nextflow &> /dev/null; then
    echo "❌ [ERROR] 'nextflow' command not found. กรุณาตรวจสอบ Conda environment"
    exit 1
fi

export NXF_ANSI_LOG=false
chmod +x ./run_chicken.sh

# รับโหมดจาก argument (ค่าเริ่มต้น: profile)
# ตัวอย่าง: sbatch submit_chicken.sbatch profile
#        sbatch submit_chicken.sbatch smoke
#        sbatch submit_chicken.sbatch assembly
MODE="${1:-profile}"

echo "🚀 Launching run_chicken.sh in mode: ${MODE}..."
./run_chicken.sh "${MODE}" conda "${@:2}"

echo "=============================================================================="
echo " ⏱️  End Time: $(date '+%Y-%m-%d %H:%M:%S')"
echo " ✅ SLURM Job Completed Successfully!"
echo "=============================================================================="
