# Analysis Directory Guide

This directory keeps managed JADX output only. Analysis execution is optional and separate from rebuild/sign flow.

## Structure

- `jadx/<run-name>/`: a versioned JADX run for one source APK.
- `jadx/latest`: symlink to the current run.
- `jadx/INDEX.md`: index of all managed runs with provenance.

## Recommended Commands

```bash
make analysis
make analysis-refresh
make analysis-prune
```

Prerequisite: run `make toolchain-bootstrap` first so pinned `jadx` is available locally.
Note: `make check-env` enforces `jadx` as part of baseline toolchain validation.

## Management Rules

- Do not edit `jadx/<run-name>/` manually.
- Generate through `scripts/run_jadx_analysis.sh` only.
- Keep manual notes under `docs/` (for example `docs/JADX_FINDINGS.md`).
