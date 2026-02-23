#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

UNSIGNED_APK="${1:-$PROJECT_DIR/build/stable-rebuilt-unsigned.apk}"
RUNTIME_DIR="${2:-$PROJECT_DIR/.cache/webp-runtime/1.0.8}"

if [[ ! -f "$UNSIGNED_APK" ]]; then
  echo "Unsigned APK not found: $UNSIGNED_APK" >&2
  exit 1
fi

if [[ ! -d "$RUNTIME_DIR" ]]; then
  echo "Runtime directory not found: $RUNTIME_DIR" >&2
  exit 1
fi

if [[ ! -f "$RUNTIME_DIR/classes2.dex" ]]; then
  echo "Runtime dex not found: $RUNTIME_DIR/classes2.dex" >&2
  exit 1
fi

runtime_entries=(
  "classes2.dex"
  "lib/armeabi/libsharpyuv.so"
  "lib/armeabi/libwebp.so"
  "lib/armeabi/libwebpcodec_jni.so"
  "lib/armeabi/libwebpdemux.so"
  "lib/armeabi/libwebpmux.so"
  "lib/x86/libsharpyuv.so"
  "lib/x86/libwebp.so"
  "lib/x86/libwebpcodec_jni.so"
  "lib/x86/libwebpdemux.so"
  "lib/x86/libwebpmux.so"
)

zip -q -d "$UNSIGNED_APK" "${runtime_entries[@]}" >/dev/null 2>&1 || true
(
  cd "$RUNTIME_DIR"
  zip -q -r "$UNSIGNED_APK" "${runtime_entries[@]}"
)

listing="$(unzip -l "$UNSIGNED_APK")"
echo "$listing" | rg -n "classes2.dex" >/dev/null
echo "$listing" | rg -n "lib/armeabi/libwebpcodec_jni.so" >/dev/null
echo "$listing" | rg -n "lib/x86/libwebpcodec_jni.so" >/dev/null

echo "Injected animated-webp runtime payload into: $UNSIGNED_APK"
