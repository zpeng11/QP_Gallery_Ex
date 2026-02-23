#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

URL_FILE="${SOURCE_URL_FILE:-$PROJECT_DIR/original/stable.url}"
DEFAULT_APK="$("$SCRIPT_DIR/resolve_source_apk_path.sh" "$URL_FILE" "$PROJECT_DIR/original")"
APK="${1:-$DEFAULT_APK}"
DECODED="${2:-$PROJECT_DIR/decoded}"
UNSIGNED="${3:-$PROJECT_DIR/build/stable-rebuilt-unsigned.apk}"
ALIGNED="${4:-$PROJECT_DIR/build/stable-rebuilt-aligned.apk}"
SIGNED="${5:-$PROJECT_DIR/build/stable-rebuilt-signed.apk}"
PATCH_SERIES="${6:-$PROJECT_DIR/patches/series}"

"$SCRIPT_DIR/prepare_baseline.sh" "$APK" "$DECODED"
"$SCRIPT_DIR/apply_patches.sh" "$PROJECT_DIR" "$PATCH_SERIES"
"$SCRIPT_DIR/build.sh" "$DECODED" "$UNSIGNED"
"$SCRIPT_DIR/prepare_webp_runtime.sh"
"$SCRIPT_DIR/inject_webp_runtime.sh" "$UNSIGNED"
"$SCRIPT_DIR/sign.sh" "$UNSIGNED" "$ALIGNED" "$SIGNED"

echo "Rebuild from patch series complete: $SIGNED"
