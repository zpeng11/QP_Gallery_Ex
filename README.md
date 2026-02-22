# APK Reverse Engineering Project

## Directory Layout
- `original/`: upstream APK URL and downloaded source APKs (versioned filenames only).
- `decoded/`: apktool decode workspace (regenerated during baseline/rebuild).
- `build/`: unsigned/aligned/signed rebuilt APK outputs.
- `patches/`: smali patch series (`series` + `.patch` files).
- `scripts/`: reproducible fetch/decode/patch/build/sign/analysis scripts.
- `analysis/`: managed JADX outputs (`jadx/<run-name>` + `latest` symlink).
- `docs/`: feature and architecture notes.

## Source APK Provenance
Upstream URL file is configurable with `SOURCE_URL_FILE`.
Default is `original/stable.url` (first non-empty line).  
The download path is derived from release tag; example:

- URL: `.../releases/download/9.7/stable.apk`
- file: `original/stable-9.7.apk`

Commands:

```bash
make fetch-apk     # reuse local versioned APK when present
make refresh-apk   # force redownload from SOURCE_URL_FILE
```

Use a different upstream URL file:

```bash
make fetch-apk SOURCE_URL_FILE=original/beta.url
make rebuild-patched SOURCE_URL_FILE=original/beta.url
```

## Install Dependencies (Ubuntu)
Host builds use a **project-local pinned toolchain** for `apktool`, `aapt2`, `zipalign`, `jadx`.
Install only base prerequisites with apt:

```bash
sudo apt-get update
sudo apt-get install -y \
  make curl patch unzip \
  openjdk-21-jdk
```

Then bootstrap pinned tools and validate:

```bash
make toolchain-bootstrap
make check-env
make toolchain-status
```

Notes:
- Ubuntu 20.04 apt ships `apktool 2.4.0`, which is too old for this project.
- `make toolchain-bootstrap` installs pinned versions under `.tooling/`.
- Apktool framework cache is stored project-locally at `.tooling/apktool-framework`.
- To intentionally bypass lock checks and use system tools: `USE_SYSTEM_TOOLS=1 make check-env`.

Optional packages:
- `adb`: only needed for local device install/verification.
- `ripgrep`: improves `make verify-patch` speed and compatibility.

Validate local environment:

```bash
make check-env
```

## Optional Docker Workflow
Docker can run the same `make`/`scripts` pipeline without setting up local toolchains.

Build the local image once:

```bash
make docker-image
```

If Docker Hub is slow/unreachable, override base image through build args:

```bash
make docker-image \
  DOCKER_BUILD_ARGS="--build-arg BASE_IMAGE=docker.m.daocloud.io/library/ubuntu:24.04"
```

Run common targets in container (project directory and host user identity are passed through):

```bash
make docker-check-env
make docker-rebuild
make docker-verify
make docker-all
```

Open an interactive shell in the build container:

```bash
make docker-shell
```

Use another source channel the same way:

```bash
make docker-rebuild SOURCE_URL_FILE=original/beta.url
```

Notes:
- Docker mode reuses current project directory (`-v "$PWD:$PWD" -w "$PWD"`).
- Container runs as host `UID:GID` and mounts host `HOME` (writable) for user-level config/cache parity.
- Docker image includes `jadx` so `check-env` and `analysis` targets can run in container mode.
- Wireless ADB is intentionally excluded from repository workflow.
- Docker targets run with `USE_SYSTEM_TOOLS=1` inside container by default.

## Main Build Workflow
Recommended one-shot flow:

```bash
make rebuild-patched
make verify-patch
```

Step-by-step equivalent:

```bash
make fetch-apk
make baseline
make patch-apply
make build
make sign
```

All commands above accept `SOURCE_URL_FILE=...` to switch source channel.

Notes:
- `build.sh` enforces `apktool --use-aapt2`.
- WebP animated patch details: `docs/WEBP_ANIMATED_PATCH.md`.

## Optional JADX Workflow

`jadx` is included in the pinned toolchain and required by `make check-env`.
Static analysis execution is still optional.

```bash
make analysis              # generate/reuse current run
make analysis-refresh      # force regenerate current run
STRICT_ANALYSIS=1 make analysis-refresh # fail if JADX exits non-zero
make analysis-prune KEEP=2 # keep N latest runs (default 3)
make analysis-clean
```

`make analysis` / `make analysis-refresh` now tolerate non-zero `jadx` exit codes by default
when `sources/` and `resources/` are still generated, and mark the run as `partial` in
`ANALYSIS_META.txt` and `analysis/jadx/INDEX.md`.

See `analysis/README.md` for directory rules and `docs/JADX_FINDINGS.md` for manual findings.

## Convenience Targets
- `make all` runs rebuild/sign only.
- `make all-with-analysis` runs rebuild/sign + analysis (requires `jadx`).
- `make docker-all` runs rebuild/sign in container.
- `make docker-all-with-analysis` runs `all-with-analysis` in container.
