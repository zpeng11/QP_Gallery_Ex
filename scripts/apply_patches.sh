#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
TARGET_DIR="${1:-$PROJECT_DIR}"
SERIES_FILE="${2:-$PROJECT_DIR/patches/series}"

if [[ ! -f "$SERIES_FILE" ]]; then
  echo "Patch series file not found: $SERIES_FILE" >&2
  exit 1
fi

PATCH_DIR="$(cd "$(dirname "$SERIES_FILE")" && pwd)"

cd "$TARGET_DIR"
while IFS= read -r raw_line; do
  line="${raw_line%%#*}"
  line="$(echo "$line" | xargs)"
  if [[ -z "$line" ]]; then
    continue
  fi

  patch_file="$PATCH_DIR/$line"
  if [[ ! -f "$patch_file" ]]; then
    echo "Patch file not found: $patch_file" >&2
    exit 1
  fi

  if patch --dry-run -p0 < "$patch_file" >/dev/null 2>&1; then
    patch -p0 < "$patch_file" >/dev/null
    echo "Applied patch: $line"
    continue
  fi

  if patch --dry-run -R -p0 < "$patch_file" >/dev/null 2>&1; then
    echo "Patch already applied, skipping: $line"
    continue
  fi

  echo "Failed to apply patch: $line" >&2
  exit 1
done < "$SERIES_FILE"

echo "Patch series applied: $SERIES_FILE"
