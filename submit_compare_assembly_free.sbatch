#!/bin/bash
# ==============================================================================
# submit_compare_assembly_free.sbatch — SLURM Job Script for Short vs Long Comparison
# ==============================================================================
#SBATCH --job-name=compare_af
#SBATCH --output=slurm-%j.out
#SBATCH --error=slurm-%j.err
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=16
#SBATCH --mem=64G
#SBATCH --time=04:00:00
#SBATCH --partition=cpu

set -eo pipefail

echo "=============================================================================="
echo " 🔬 Starting SLURM Job: ${SLURM_JOB_NAME:-compare_af} (Job ID: ${SLURM_JOB_ID})"
echo " 🖥️  Running on Node   : $(hostname)"
echo " ⚙️  Allocated CPUs    : ${SLURM_CPUS_PER_TASK:-16}"
echo " 💾 Allocated Memory  : 64G"
echo " ⏱️  Start Time        : $(date '+%Y-%m-%d %H:%M:%S')"
echo "=============================================================================="

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WORK_DIR="${SLURM_SUBMIT_DIR:-${SCRIPT_DIR}}"
cd "${WORK_DIR}"

mkdir -p logs_slurm

# Load Conda
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
conda activate metagenomics || true

if ! command -v nextflow &> /dev/null; then
    echo "❌ [ERROR] 'nextflow' command not found in active environment"
    exit 1
fi

export NXF_ANSI_LOG=false
chmod +x ./run_compare_assembly_free.sh

# Run from clean reads by default (samplesheet_hybrid_clean.csv)
echo "🚀 Submitting Assembly-Free Comparison via run_compare_assembly_free.sh..."
./run_compare_assembly_free.sh clean conda \
    --max_cpus "${SLURM_CPUS_PER_TASK:-16}" \
    --max_memory "64.GB"

echo "=============================================================================="
echo " 🎉 SLURM Job Finished Successfully! (Job ID: ${SLURM_JOB_ID})"
echo " ⏱️  End Time: $(date '+%Y-%m-%d %H:%M:%S')"
echo "=============================================================================="
