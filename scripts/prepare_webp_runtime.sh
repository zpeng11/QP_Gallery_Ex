#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

RUNTIME_SRC_DIR="${1:-$PROJECT_DIR/third_party/webp-runtime/1.0.8}"
RUNTIME_CACHE_DIR="${2:-$PROJECT_DIR/.cache/webp-runtime/1.0.8}"

if [[ ! -d "$RUNTIME_SRC_DIR" ]]; then
  echo "Runtime source directory not found: $RUNTIME_SRC_DIR" >&2
  exit 1
fi

if [[ ! -f "$RUNTIME_SRC_DIR/SHA256SUMS" ]]; then
  echo "Runtime checksums file missing: $RUNTIME_SRC_DIR/SHA256SUMS" >&2
  exit 1
fi

verify_runtime_dir() {
  local dir="$1"
  (cd "$dir" && sha256sum -c SHA256SUMS >/dev/null)
}

if verify_runtime_dir "$RUNTIME_SRC_DIR"; then
  :
else
  echo "Runtime source checksum validation failed: $RUNTIME_SRC_DIR" >&2
  exit 1
fi

if [[ -d "$RUNTIME_CACHE_DIR" ]] && verify_runtime_dir "$RUNTIME_CACHE_DIR"; then
  echo "CACHE_HIT webp-runtime $RUNTIME_CACHE_DIR"
  exit 0
fi

rm -rf "$RUNTIME_CACHE_DIR"
mkdir -p "$(dirname "$RUNTIME_CACHE_DIR")"
cp -a "$RUNTIME_SRC_DIR" "$RUNTIME_CACHE_DIR"

if verify_runtime_dir "$RUNTIME_CACHE_DIR"; then
  echo "CACHE_MISS webp-runtime $RUNTIME_CACHE_DIR"
else
  echo "Runtime cache checksum validation failed after copy: $RUNTIME_CACHE_DIR" >&2
  exit 1
fi
