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
echo "Active Conda environment: ${CONDA_DEFAULT_ENV:-unknown} (${CONDA_PREFIX:-unknown})"

# Use the project environment created by Pixi, as the other run scripts do.
PIXI_BIN="${PWD}/.pixi/envs/default/bin"
if [ ! -x "${PIXI_BIN}/nextflow" ]; then
    echo "ERROR: Pixi environment is missing at ${PIXI_BIN}; run 'pixi install' in the project directory before submitting." >&2
    exit 1
fi
export PATH="${PIXI_BIN}:${PATH}"
echo "Using Pixi environment: ${PIXI_BIN}"

# รันสคริปต์
bash ./run_chicken.sh
