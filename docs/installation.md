# Installation & Environment Setup

This guide details system requirements, dependency installations, container runtime setup, and HPC configuration for the **Hybrid Metagenomics Pipeline**.

---

## 1. System Requirements

### Hardware Requirements
- **Local / Workstation**: 4+ CPU cores, 16+ GB RAM, 50+ GB free disk space.
- **HPC Cluster**: SLURM workload manager, node memory scaling up to 128+ GB for large-scale MAG binning or GTDB-Tk.

### Software Requirements
- **Linux OS** (Ubuntu 20.04+, CentOS 7+, RHEL 8+) or **macOS** (with Docker Desktop).
- **Java**: OpenJDK 11, 17, or 21.
- **Nextflow**: Version `>= 22.10.0`.
- **Container Engine**: Docker, Singularity (>= 3.8), or Apptainer (>= 1.0).

---

## 2. Installing Nextflow

Install Nextflow with a single command:

```bash
# Download and install Nextflow binary
curl -shttps://get.nextflow.io | bash

# Move to system path
chmod +x nextflow
sudo mv nextflow /usr/local/bin/

# Verify version
nextflow -v
```

---

## 3. Container Runtime Setup

### Docker (Local Workstations)
Ensure Docker is installed and running, and your user is added to the `docker` group:

```bash
sudo usermod -aG docker $USER
newgrp docker
docker run hello-world
```

### Singularity / Apptainer (HPC Clusters)
No root privileges are needed. Verify Singularity/Apptainer is installed:

```bash
singularity --version
# or
apptainer --version
```

Configure Nextflow singularity cache directory in your `~/.bashrc`:

```bash
export NXF_SINGULARITY_CACHEDIR="/scratch/singularity_cache"
```

---

## 4. SLURM Cluster Setup

To run on SLURM, specify the `slurm` profile alongside `singularity`:

```bash
nextflow run main.nf -profile slurm,singularity ...
```

Process resource allocations are defined in [`conf/slurm.config`](../conf/slurm.config) with standard queues and label limits:
- `process_low`: 2 CPUs, 4 GB RAM, 2 hours
- `process_medium`: 8 CPUs, 32 GB RAM, 8 hours
- `process_high`: 16 CPUs, 64 GB RAM, 24 hours
- `process_gpu`: 8 CPUs, 32 GB RAM, 1 GPU, 12 hours
