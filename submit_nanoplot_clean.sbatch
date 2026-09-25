#!/bin/bash
# ==============================================================================
# submit_nanoplot_clean.sbatch — SLURM Job Script for NanoPlot on Clean Long Reads
# ==============================================================================
#SBATCH --job-name=nanoplot_clean
#SBATCH --output=slurm_nanoplot-%j.out
#SBATCH --error=slurm_nanoplot-%j.err
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=8
#SBATCH --mem=32G
#SBATCH --time=02:00:00
#SBATCH --partition=cpu
# #SBATCH --account=your_project   # ปลด comment หาก HPC บังคับระบุชื่อ account/project

set -eo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WORK_DIR="${SLURM_SUBMIT_DIR:-${SCRIPT_DIR}}"
cd "${WORK_DIR}"

mkdir -p logs_slurm

# โหลด Conda เข้าสู่ Non-interactive Shell และ Activate env 'metagenomics'
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

if conda env list | grep -q "metagenomics"; then
    echo "🔄 Activating Conda environment: metagenomics..."
    conda activate metagenomics
fi

chmod +x ./run_nanoplot_clean.sh
./run_nanoplot_clean.sh conda
