#!/usr/bin/env bash
set -euo pipefail

if [[ $# -lt 1 ]]; then
  echo "Usage: $0 <apk_path> [output_dir]" >&2
  exit 1
fi

APK_PATH="$1"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
OUTPUT_DIR="${2:-$PROJECT_DIR/decoded}"

# shellcheck disable=SC1091
source "$SCRIPT_DIR/toolchain_env.sh"
toolchain_apply_path

if [[ ! -f "$APK_PATH" ]]; then
  echo "APK not found: $APK_PATH" >&2
  exit 1
fi

mkdir -p "$PROJECT_DIR"
mkdir -p "$APKTOOL_FRAMEWORK_DIR"
apktool d -f -p "$APKTOOL_FRAMEWORK_DIR" -o "$OUTPUT_DIR" "$APK_PATH"
echo "Decompiled to: $OUTPUT_DIR"
