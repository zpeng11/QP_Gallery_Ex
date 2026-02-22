#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
DECODED_DIR="${1:-$PROJECT_DIR/decoded}"
UNSIGNED_OUT="${2:-$PROJECT_DIR/build/stable-rebuilt-unsigned.apk}"

# shellcheck disable=SC1091
source "$SCRIPT_DIR/toolchain_env.sh"
toolchain_apply_path

if [[ ! -d "$DECODED_DIR" ]]; then
  echo "Decoded directory not found: $DECODED_DIR" >&2
  exit 1
fi

mkdir -p "$(dirname "$UNSIGNED_OUT")"
mkdir -p "$APKTOOL_FRAMEWORK_DIR"

# This APK fails with legacy aapt1 due to resource symbol parsing.
# Force aapt2 for deterministic rebuild.
apktool b --use-aapt2 -p "$APKTOOL_FRAMEWORK_DIR" "$DECODED_DIR" -o "$UNSIGNED_OUT"
echo "Unsigned APK built: $UNSIGNED_OUT"
