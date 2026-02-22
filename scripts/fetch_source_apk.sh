#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

URL_FILE="${1:-${SOURCE_URL_FILE:-$PROJECT_DIR/original/stable.url}}"
ORIGINAL_DIR="${2:-${ORIGINAL_DIR:-$PROJECT_DIR/original}}"
FORCE_DOWNLOAD="${FORCE_DOWNLOAD:-0}"

if [[ ! -f "$URL_FILE" ]]; then
  echo "URL file not found: $URL_FILE" >&2
  echo "Create it and put source APK URL in first non-empty line." >&2
  exit 1
fi

mkdir -p "$ORIGINAL_DIR"
SOURCE_URL="$(sed -e 's/#.*$//' "$URL_FILE" | awk 'NF { print; exit }' | tr -d '\r')"
if [[ -z "$SOURCE_URL" ]]; then
  echo "No valid URL found in: $URL_FILE" >&2
  exit 1
fi
VERSIONED_APK="$("$SCRIPT_DIR/resolve_source_apk_path.sh" "$URL_FILE" "$ORIGINAL_DIR")"

if [[ -f "$VERSIONED_APK" && "$FORCE_DOWNLOAD" != "1" ]]; then
  echo "Versioned APK already exists, skip download: $VERSIONED_APK"
  exit 0
fi

download_with_curl() {
  curl -fL --retry 3 --retry-delay 2 -o "$VERSIONED_APK" "$SOURCE_URL"
}

download_with_wget() {
  wget -O "$VERSIONED_APK" "$SOURCE_URL"
}

if command -v curl >/dev/null 2>&1; then
  download_with_curl
elif command -v wget >/dev/null 2>&1; then
  download_with_wget
else
  echo "Neither curl nor wget is available for download." >&2
  exit 1
fi

echo "Source URL: $SOURCE_URL"
echo "Versioned APK: $VERSIONED_APK"
