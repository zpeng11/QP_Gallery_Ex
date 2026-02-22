#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

URL_FILE="${1:-${SOURCE_URL_FILE:-$PROJECT_DIR/original/stable.url}}"
ORIGINAL_DIR="${2:-${ORIGINAL_DIR:-$PROJECT_DIR/original}}"

if [[ ! -f "$URL_FILE" ]]; then
  echo "URL file not found: $URL_FILE" >&2
  exit 1
fi

SOURCE_URL="$(sed -e 's/#.*$//' "$URL_FILE" | awk 'NF { print; exit }' | tr -d '\r')"
if [[ -z "$SOURCE_URL" ]]; then
  echo "No valid URL found in: $URL_FILE" >&2
  exit 1
fi

file_name="${SOURCE_URL##*/}"
file_name="${file_name%%\?*}"
if [[ -z "$file_name" ]]; then
  file_name="stable.apk"
fi

name_no_ext="${file_name%.*}"
ext="${file_name##*.}"
if [[ "$name_no_ext" == "$ext" ]]; then
  name_no_ext="$file_name"
  ext="apk"
fi

version=""
if [[ "$SOURCE_URL" =~ /download/([^/]+)/ ]]; then
  version="${BASH_REMATCH[1]}"
fi
version="$(echo "$version" | tr -cd 'A-Za-z0-9._-')"

if [[ -n "$version" ]]; then
  echo "$ORIGINAL_DIR/${name_no_ext}-${version}.${ext}"
else
  echo "$ORIGINAL_DIR/$file_name"
fi
