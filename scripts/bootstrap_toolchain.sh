#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

# shellcheck disable=SC1091
source "$SCRIPT_DIR/toolchain_env.sh"

usage() {
  cat <<'EOF'
Usage: ./scripts/bootstrap_toolchain.sh [--force]

Downloads pinned build and analysis tools into project-local .tooling path
and installs wrappers in .tooling/bin.
EOF
}

FORCE=0
while [[ $# -gt 0 ]]; do
  case "$1" in
    --force)
      FORCE=1
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "Unknown argument: $1" >&2
      usage >&2
      exit 1
      ;;
  esac
  shift
done

toolchain_load_lock

if [[ "$USE_SYSTEM_TOOLS" == "1" ]]; then
  echo "USE_SYSTEM_TOOLS=1 is set; bootstrap is only for local pinned toolchain." >&2
  exit 1
fi

for cmd in curl sha256sum unzip java chmod mkdir cp mv rm; do
  if ! command -v "$cmd" >/dev/null 2>&1; then
    echo "Missing required command for bootstrap: $cmd" >&2
    exit 1
  fi
done

DOWNLOAD_DIR="${TOOLCHAIN_DOWNLOAD_DIR:-$PROJECT_DIR/.tooling/downloads}"
APKTOOL_ARCHIVE="$DOWNLOAD_DIR/apktool_${APKTOOL_VERSION}.jar"
BUILD_TOOLS_ARCHIVE="$DOWNLOAD_DIR/$(basename "$ANDROID_BUILD_TOOLS_ARCHIVE_URL")"
JADX_ARCHIVE="$DOWNLOAD_DIR/$(basename "$JADX_ARCHIVE_URL")"
APKTOOL_INSTALL_DIR="$TOOLCHAIN_DIR/apktool/$APKTOOL_VERSION"
BUILD_TOOLS_INSTALL_DIR="$TOOLCHAIN_DIR/build-tools/$ANDROID_BUILD_TOOLS_VERSION"
JADX_INSTALL_DIR="$TOOLCHAIN_DIR/jadx/$JADX_VERSION"

mkdir -p "$DOWNLOAD_DIR" "$TOOLCHAIN_BIN_DIR" "$APKTOOL_INSTALL_DIR"

download_with_checksum() {
  local url="$1"
  local destination="$2"
  local expected_sha="$3"
  local actual_sha

  if [[ "$FORCE" == "1" || ! -f "$destination" ]]; then
    echo "Downloading: $url"
    curl -fL "$url" -o "$destination"
  fi

  actual_sha="$(sha256sum "$destination" | awk '{print $1}')"
  if [[ "$actual_sha" != "$expected_sha" ]]; then
    if [[ "$FORCE" == "0" ]]; then
      echo "Checksum mismatch for $destination, retrying download..." >&2
      curl -fL "$url" -o "$destination"
      actual_sha="$(sha256sum "$destination" | awk '{print $1}')"
    fi
  fi

  if [[ "$actual_sha" != "$expected_sha" ]]; then
    echo "Checksum mismatch for $destination" >&2
    echo "Expected: $expected_sha" >&2
    echo "Actual:   $actual_sha" >&2
    exit 1
  fi
}

download_with_checksum "$APKTOOL_URL" "$APKTOOL_ARCHIVE" "$APKTOOL_SHA256"
download_with_checksum "$ANDROID_BUILD_TOOLS_ARCHIVE_URL" "$BUILD_TOOLS_ARCHIVE" "$ANDROID_BUILD_TOOLS_ARCHIVE_SHA256"
download_with_checksum "$JADX_ARCHIVE_URL" "$JADX_ARCHIVE" "$JADX_ARCHIVE_SHA256"

cp -f "$APKTOOL_ARCHIVE" "$APKTOOL_INSTALL_DIR/apktool.jar"
chmod 0644 "$APKTOOL_INSTALL_DIR/apktool.jar"

tmp_extract="$(mktemp -d)"
trap 'rm -rf "$tmp_extract"' EXIT

rm -rf "$BUILD_TOOLS_INSTALL_DIR"
mkdir -p "$(dirname "$BUILD_TOOLS_INSTALL_DIR")"
unzip -q -o "$BUILD_TOOLS_ARCHIVE" -d "$tmp_extract"

if [[ ! -d "$tmp_extract/$ANDROID_BUILD_TOOLS_EXTRACT_DIR" ]]; then
  echo "Expected directory not found in build-tools archive: $ANDROID_BUILD_TOOLS_EXTRACT_DIR" >&2
  exit 1
fi

mv "$tmp_extract/$ANDROID_BUILD_TOOLS_EXTRACT_DIR" "$BUILD_TOOLS_INSTALL_DIR"
chmod +x "$BUILD_TOOLS_INSTALL_DIR/aapt2" "$BUILD_TOOLS_INSTALL_DIR/zipalign"

rm -rf "$JADX_INSTALL_DIR"
mkdir -p "$JADX_INSTALL_DIR"
unzip -q -o "$JADX_ARCHIVE" -d "$JADX_INSTALL_DIR"

if [[ ! -f "$JADX_INSTALL_DIR/$JADX_BIN_RELATIVE_PATH" ]]; then
  echo "Expected jadx binary not found after extraction: $JADX_BIN_RELATIVE_PATH" >&2
  exit 1
fi

chmod +x "$JADX_INSTALL_DIR/bin/jadx" "$JADX_INSTALL_DIR/bin/jadx-gui"

cat > "$TOOLCHAIN_BIN_DIR/apktool" <<EOF
#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="\$(cd "\$(dirname "\${BASH_SOURCE[0]}")" && pwd)"
exec java -jar "\$SCRIPT_DIR/../android/apktool/${APKTOOL_VERSION}/apktool.jar" "\$@"
EOF

cat > "$TOOLCHAIN_BIN_DIR/aapt2" <<EOF
#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="\$(cd "\$(dirname "\${BASH_SOURCE[0]}")" && pwd)"
exec "\$SCRIPT_DIR/../android/build-tools/${ANDROID_BUILD_TOOLS_VERSION}/aapt2" "\$@"
EOF

cat > "$TOOLCHAIN_BIN_DIR/zipalign" <<EOF
#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="\$(cd "\$(dirname "\${BASH_SOURCE[0]}")" && pwd)"
exec "\$SCRIPT_DIR/../android/build-tools/${ANDROID_BUILD_TOOLS_VERSION}/zipalign" "\$@"
EOF

cat > "$TOOLCHAIN_BIN_DIR/jadx" <<EOF
#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="\$(cd "\$(dirname "\${BASH_SOURCE[0]}")" && pwd)"
exec "\$SCRIPT_DIR/../android/jadx/${JADX_VERSION}/bin/jadx" "\$@"
EOF

chmod +x "$TOOLCHAIN_BIN_DIR/apktool" "$TOOLCHAIN_BIN_DIR/aapt2" "$TOOLCHAIN_BIN_DIR/zipalign" "$TOOLCHAIN_BIN_DIR/jadx"

echo "Pinned toolchain installed:"
echo "  apktool : $("$TOOLCHAIN_BIN_DIR/apktool" --version)"
echo "  aapt2   : $("$TOOLCHAIN_BIN_DIR/aapt2" version 2>&1 | head -n 1)"
echo "  zipalign: $("$TOOLCHAIN_BIN_DIR/zipalign" 2>&1 | head -n 1)"
echo "  jadx    : $("$TOOLCHAIN_BIN_DIR/jadx" --version)"
