#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

UNSIGNED_APK="${1:-$PROJECT_DIR/build/stable-rebuilt-unsigned.apk}"
ALIGNED_APK="${2:-$PROJECT_DIR/build/stable-rebuilt-aligned.apk}"
SIGNED_APK="${3:-$PROJECT_DIR/build/stable-rebuilt-signed.apk}"
KEYSTORE_PATH="${4:-$PROJECT_DIR/build/debug.keystore}"
KEY_ALIAS="${5:-androiddebugkey}"
KEYSTORE_PASS="${6:-android}"
KEY_PASS="${7:-android}"

# shellcheck disable=SC1091
source "$SCRIPT_DIR/toolchain_env.sh"
toolchain_apply_path

if [[ ! -f "$UNSIGNED_APK" ]]; then
  echo "Unsigned APK not found: $UNSIGNED_APK" >&2
  exit 1
fi

if [[ ! -f "$KEYSTORE_PATH" ]]; then
  keytool -genkeypair \
    -v \
    -storetype PKCS12 \
    -keystore "$KEYSTORE_PATH" \
    -alias "$KEY_ALIAS" \
    -keyalg RSA \
    -keysize 2048 \
    -validity 10000 \
    -storepass "$KEYSTORE_PASS" \
    -keypass "$KEY_PASS" \
    -dname "CN=Android Debug,O=Android,C=US"
fi

zipalign -f 4 "$UNSIGNED_APK" "$ALIGNED_APK"

jarsigner \
  -keystore "$KEYSTORE_PATH" \
  -storepass "$KEYSTORE_PASS" \
  -keypass "$KEY_PASS" \
  -signedjar "$SIGNED_APK" \
  "$ALIGNED_APK" \
  "$KEY_ALIAS"

jarsigner -verify "$SIGNED_APK" >/dev/null
echo "Signed APK built: $SIGNED_APK"
