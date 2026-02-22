#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
URL_FILE="${SOURCE_URL_FILE:-$PROJECT_DIR/original/stable.url}"
# shellcheck disable=SC1091
source "$SCRIPT_DIR/toolchain_env.sh"

APK_PATH="${1:-}"
if [[ -z "$APK_PATH" ]]; then
  APK_PATH="$("$SCRIPT_DIR/resolve_source_apk_path.sh" "$URL_FILE" "$PROJECT_DIR/original")"
fi
DECODED_DIR="${2:-$PROJECT_DIR/decoded}"

if [[ ! -f "$APK_PATH" ]]; then
  echo "APK not found: $APK_PATH" >&2
  echo "Run fetch first: ./scripts/fetch_source_apk.sh \"$URL_FILE\" \"$PROJECT_DIR/original\"" >&2
  exit 1
fi

rm -rf "$DECODED_DIR"
if [[ "$USE_SYSTEM_TOOLS" != "1" ]]; then
  # Ensure framework cache is regenerated with the current apktool version/source APK.
  rm -rf "$APKTOOL_FRAMEWORK_DIR"
fi
"$SCRIPT_DIR/decompile.sh" "$APK_PATH" "$DECODED_DIR"
echo "Baseline decoded directory ready: $DECODED_DIR"
