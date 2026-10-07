#!/bin/bash
#SBATCH --job-name=chicken_meta
#SBATCH --output=slurm-%j.out
#SBATCH --error=slurm-%j.err
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=16
#SBATCH --mem=64G
#SBATCH --time=24:00:00
#SBATCH --partition=cpu

set -e

cd "${SLURM_SUBMIT_DIR}"

# Make Conda available in this non-interactive Slurm shell.
if command -v conda >/dev/null 2>&1; then
    CONDA_BASE="$(conda info --base)"
elif [ -f "${HOME}/miniconda3/etc/profile.d/conda.sh" ]; then
    CONDA_BASE="${HOME}/miniconda3"
elif [ -f "${HOME}/anaconda3/etc/profile.d/conda.sh" ]; then
    CONDA_BASE="${HOME}/anaconda3"
fi
if [ -n "${CONDA_BASE:-}" ] && [ -f "${CONDA_BASE}/etc/profile.d/conda.sh" ]; then
    source "${CONDA_BASE}/etc/profile.d/conda.sh"
fi

if ! command -v conda >/dev/null 2>&1; then
    echo "ERROR: conda is unavailable in the Slurm job." >&2
    exit 1
fi
conda activate "${CHICKEN_CONDA_ENV:-metagenomics}"

if ! command -v nextflow >/dev/null 2>&1; then
    echo "ERROR: nextflow is unavailable in the active Conda environment." >&2
    exit 1
fi

# รันสคริปต์
bash ./run_chicken.sh
