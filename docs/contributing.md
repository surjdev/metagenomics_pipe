# Contributing Guidelines

Thank you for your interest in contributing to the **Hybrid Metagenomics Pipeline**!

---

## Code of Conduct

Please treat all contributors with respect and professionalism.

---

## Submitting Contributions

1. **Fork the repository** and create a feature branch (`feature/my-new-tool` or `fix/issue-description`).
2. **Implement changes** following the 5-layer architecture rules in [`docs/developer.md`](developer.md) and [`framework_plan.md`](../framework_plan.md).
3. **Verify tests pass**:
   ```bash
   nextflow run main.nf -profile docker,test
   ```
4. **Commit with clear commit messages** describing what changed and why.
5. **Open a Pull Request** with a summary of the added features, container images, and verification output.

---

## Style Guide

- One bioinformatics tool per module (`modules/local/<tool>/main.nf`).
- Pinned container images only (`quay.io/biocontainers/tool:1.0.0--tag`).
- No hardcoded paths inside `.nf` scripts.
- Document any new configuration parameters in `params/` and `nextflow.config`.
