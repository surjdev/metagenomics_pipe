#!/usr/bin/env python3
"""
Generate tiny synthetic FASTQ + host reference FASTA for Phase 1 testing.
Produces:
  test/data/tiny_illumina/sample1_R1.fastq.gz
  test/data/tiny_illumina/sample1_R2.fastq.gz
  test/data/tiny_nanopore/sample1_long.fastq.gz
  test/data/tiny_databases/host_ref.fasta
  test/data/samplesheet.csv
"""
import gzip, random, os, string

random.seed(42)

def rand_seq(n):
    return ''.join(random.choices('ACGT', k=n))

def rand_qual(n, min_q=30, max_q=40):
    return ''.join(chr(random.randint(min_q, max_q) + 33) for _ in range(n))

def write_fastq_gz(path, n_reads=500, read_len=150):
    os.makedirs(os.path.dirname(path), exist_ok=True)
    with gzip.open(path, 'wt') as f:
        for i in range(n_reads):
            seq  = rand_seq(read_len)
            qual = rand_qual(read_len)
            f.write(f'@read{i}\n{seq}\n+\n{qual}\n')
    print(f'  Written: {path}  ({n_reads} reads x {read_len} bp)')

def write_long_fastq_gz(path, n_reads=100, read_len=5000):
    os.makedirs(os.path.dirname(path), exist_ok=True)
    with gzip.open(path, 'wt') as f:
        for i in range(n_reads):
            seq  = rand_seq(read_len)
            qual = rand_qual(read_len, 20, 35)
            f.write(f'@long_read{i}\n{seq}\n+\n{qual}\n')
    print(f'  Written: {path}  ({n_reads} reads x {read_len} bp)')

def write_fasta(path, n_seqs=3, seq_len=10000):
    os.makedirs(os.path.dirname(path), exist_ok=True)
    with open(path, 'w') as f:
        for i in range(n_seqs):
            f.write(f'>host_chr{i+1}\n')
            seq = rand_seq(seq_len)
            for j in range(0, len(seq), 80):
                f.write(seq[j:j+80] + '\n')
    print(f'  Written: {path}  ({n_seqs} sequences x {seq_len} bp)')

def write_samplesheet(path, illumina_r1, illumina_r2, long_reads):
    os.makedirs(os.path.dirname(path), exist_ok=True)
    with open(path, 'w') as f:
        f.write('sample,fastq_1,fastq_2,long_reads,platform\n')
        f.write(f'SAMPLE001,{illumina_r1},{illumina_r2},{long_reads},hybrid\n')
    print(f'  Written: {path}')

# ── Paths ─────────────────────────────────────────────────────────────────────
base = os.path.dirname(os.path.abspath(__file__))

illumina_r1 = os.path.join(base, 'tiny_illumina', 'sample1_R1.fastq.gz')
illumina_r2 = os.path.join(base, 'tiny_illumina', 'sample1_R2.fastq.gz')
long_reads  = os.path.join(base, 'tiny_nanopore',  'sample1_long.fastq.gz')
host_ref    = os.path.join(base, 'tiny_databases', 'host_ref.fasta')
samplesheet = os.path.join(base, 'samplesheet.csv')

print('Generating Phase 1 test data...')
write_fastq_gz(illumina_r1)
write_fastq_gz(illumina_r2)
write_long_fastq_gz(long_reads)
write_fasta(host_ref)
write_samplesheet(samplesheet, illumina_r1, illumina_r2, long_reads)
print('Done.')
