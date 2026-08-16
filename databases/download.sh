#!/usr/bin/env bash
# ==============================================================================
# databases/download.sh — Reference Database Download & Preparation Script
# Metagenomics Pipeline (Nextflow DSL2 Framework)
# ==============================================================================

set -euo pipefail

# Print help message
usage() {
    cat << EOF
Usage: $(basename "$0") [OPTIONS] TARGET_DIR

Options:
  --host       Download and index Human Host reference (GRCh38)
  --kraken2    Download Kraken 2 Standard prebuilt database (PlusPFP / Standard)
  --checkm2    Download CheckM2 machine learning database
  --gtdbtk     Download GTDB-Tk reference database
  --gunc       Download GUNC Progenomes database
  --genomad    Download geNomad virus/plasmid database
  --humann3    Download HUMAnN3 ChocoPhlAn & UniRef50 databases
  --all        Download all reference databases
  -h, --help   Show this help message

Example:
  $(basename "$0") --kraken2 /data/databases/kraken2
  $(basename "$0") --all /data/databases
EOF
    exit 0
}

# Helper download function
download_file() {
    local url="$1"
    local dest="$2"
    echo "── Downloading: ${url} → ${dest}"
    if command -v aria2c &> /dev/null; then
        aria2c -x 8 -s 8 -d "$(dirname "$dest")" -o "$(basename "$dest")" "$url"
    elif command -v wget &> /dev/null; then
        wget -c -O "$dest" "$url"
    elif command -v curl &> /dev/null; then
        curl -L -C - -o "$dest" "$url"
    else
        echo "Error: Neither aria2c, wget, nor curl is installed." >&2
        exit 1
    fi
}

# Check argument count
if [[ $# -eq 0 ]]; then
    usage
fi

TARGET_DIR="${@: -1}"
mkdir -p "$TARGET_DIR"

case "$1" in
    --host)
        echo "==> Downloading Human Host Genome (GRCh38)..."
        HOST_DIR="${TARGET_DIR}/host"
        mkdir -p "$HOST_DIR"
        download_file "https://ftp.ncbi.nlm.nih.gov/genomes/all/GCA/000/001/405/GCA_000001405.15_GRCh38/seqs_for_alignment_pipelines.ucsc_ids/GCA_000001405.15_GRCh38_no_alt_analysis_set.fna.gz" "${HOST_DIR}/GRCh38_noalt.fa.gz"
        gunzip -f "${HOST_DIR}/GRCh38_noalt.fa.gz"
        echo "Host reference downloaded: ${HOST_DIR}/GRCh38_noalt.fa"
        ;;

    --kraken2)
        echo "==> Downloading Kraken2 / Bracken Standard 8GB database..."
        K2_DIR="${TARGET_DIR}/kraken2"
        mkdir -p "$K2_DIR"
        download_file "https://genome-idx.s3.amazonaws.com/kraken/k2_standard_08gb_20240112.tar.gz" "${K2_DIR}/k2_standard.tar.gz"
        tar -xzf "${K2_DIR}/k2_standard.tar.gz" -C "$K2_DIR"
        rm -f "${K2_DIR}/k2_standard.tar.gz"
        echo "Kraken2 database ready at: ${K2_DIR}"
        ;;

    --checkm2)
        echo "==> Downloading CheckM2 diamond database..."
        CM2_DIR="${TARGET_DIR}/checkm2"
        mkdir -p "$CM2_DIR"
        download_file "https://zenodo.org/record/5571251/files/checkm2_database.tar.gz" "${CM2_DIR}/checkm2_db.tar.gz"
        tar -xzf "${CM2_DIR}/checkm2_db.tar.gz" -C "$CM2_DIR"
        rm -f "${CM2_DIR}/checkm2_db.tar.gz"
        echo "CheckM2 database ready at: ${CM2_DIR}"
        ;;

    --gtdbtk)
        echo "==> Downloading GTDB-Tk reference database (r220)..."
        GTDB_DIR="${TARGET_DIR}/gtdbtk"
        mkdir -p "$GTDB_DIR"
        download_file "https://data.gtdb.ecogenomic.org/releases/release220/220.0/auxillary_files/gtdbtk_package/full_package/gtdbtk_r220_data.tar.gz" "${GTDB_DIR}/gtdbtk_data.tar.gz"
        tar -xzf "${GTDB_DIR}/gtdbtk_data.tar.gz" -C "$GTDB_DIR"
        rm -f "${GTDB_DIR}/gtdbtk_data.tar.gz"
        echo "GTDB-Tk database ready at: ${GTDB_DIR}"
        ;;

    --gunc)
        echo "==> Downloading GUNC Progenomes database..."
        GUNC_DIR="${TARGET_DIR}/gunc"
        mkdir -p "$GUNC_DIR"
        download_file "https://zenodo.org/record/4648784/files/gunc_db_progenomes2.1.dmnd.gz" "${GUNC_DIR}/gunc_db_progenomes2.1.dmnd.gz"
        gunzip -f "${GUNC_DIR}/gunc_db_progenomes2.1.dmnd.gz"
        echo "GUNC database ready at: ${GUNC_DIR}"
        ;;

    --genomad)
        echo "==> Downloading geNomad database..."
        GENOMAD_DIR="${TARGET_DIR}/genomad"
        mkdir -p "$GENOMAD_DIR"
        download_file "https://zenodo.org/record/8339387/files/genomad_db_v1.7.tar.gz" "${GENOMAD_DIR}/genomad_db.tar.gz"
        tar -xzf "${GENOMAD_DIR}/genomad_db.tar.gz" -C "$GENOMAD_DIR"
        rm -f "${GENOMAD_DIR}/genomad_db.tar.gz"
        echo "geNomad database ready at: ${GENOMAD_DIR}"
        ;;

    --all)
        echo "==> Downloading ALL reference databases into ${TARGET_DIR}..."
        $0 --host "$TARGET_DIR"
        $0 --kraken2 "$TARGET_DIR"
        $0 --checkm2 "$TARGET_DIR"
        $0 --gunc "$TARGET_DIR"
        $0 --genomad "$TARGET_DIR"
        echo "All databases downloaded."
        ;;

    -h|--help)
        usage
        ;;

    *)
        echo "Unknown option: $1" >&2
        usage
        ;;
esac
