#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
# shellcheck disable=SC1091
source "$SCRIPT_DIR/toolchain_env.sh"
toolchain_apply_path

STRICT_NO_LOCAL_SDK="${STRICT_NO_LOCAL_SDK:-1}"
missing_required=0
missing_optional=0
bad_path=0
bad_lock=0

required_build=(
  bash make apktool aapt2 zipalign
  java keytool jarsigner
  patch sed awk tr find stat sha256sum xargs ln rm
)

required_fetch=(curl)
required_verify=(rg)
required_analysis=(jadx)
lock_mode=1

if [[ "$USE_SYSTEM_TOOLS" == "1" ]]; then
  lock_mode=0
fi

if [[ "$lock_mode" -eq 1 ]]; then
  if [[ ! -x "$TOOLCHAIN_BIN_DIR/apktool" || ! -x "$TOOLCHAIN_BIN_DIR/aapt2" || ! -x "$TOOLCHAIN_BIN_DIR/zipalign" || ! -x "$TOOLCHAIN_BIN_DIR/jadx" ]]; then
    echo "[missing-required] locked toolchain wrappers not found in $TOOLCHAIN_BIN_DIR"
    echo "Run: make toolchain-bootstrap" >&2
    missing_required=1
  fi

  if ! toolchain_load_lock; then
    missing_required=1
  fi
fi

check_cmd() {
  local cmd="$1"
  local level="$2"
  local path
  if ! path="$(command -v "$cmd" 2>/dev/null)"; then
    if [[ "$level" == "required" ]]; then
      echo "[missing-required] $cmd"
      missing_required=1
    else
      echo "[missing-optional] $cmd"
      missing_optional=1
    fi
    return
  fi

  if [[ "$STRICT_NO_LOCAL_SDK" == "1" && "$path" == /root/android-sdk/* ]]; then
    echo "[bad-path] $cmd -> $path (coupled to local /root/android-sdk)"
    bad_path=1
    return
  fi

  echo "[ok] $cmd -> $path"
}

echo "== Build (required) =="
for cmd in "${required_build[@]}"; do
  check_cmd "$cmd" required
done

echo
echo "== Fetch APK (required) =="
for cmd in "${required_fetch[@]}"; do
  check_cmd "$cmd" required
done

echo
echo "== Verify Patch (optional) =="
for cmd in "${required_verify[@]}"; do
  check_cmd "$cmd" optional
done

echo
echo "== JADX Analysis (required) =="
for cmd in "${required_analysis[@]}"; do
  check_cmd "$cmd" required
done

if [[ "$lock_mode" -eq 1 && "$missing_required" -eq 0 ]]; then
  apktool_version="$(apktool --version | head -n 1 | tr -d '\r')"
  aapt2_version_line="$(aapt2 version 2>&1 | head -n 1 | tr -d '\r')"
  jadx_version_line="$(jadx --version | head -n 1 | tr -d '\r')"

  if [[ "$apktool_version" != "$APKTOOL_VERSION" ]]; then
    echo "[bad-lock] apktool version mismatch: expected $APKTOOL_VERSION, got $apktool_version"
    bad_lock=1
  else
    echo "[ok-lock] apktool version: $apktool_version"
  fi

  if [[ "$aapt2_version_line" != *"$AAPT2_VERSION"* ]]; then
    echo "[bad-lock] aapt2 version mismatch: expected token $AAPT2_VERSION, got '$aapt2_version_line'"
    bad_lock=1
  else
    echo "[ok-lock] aapt2 version: $aapt2_version_line"
  fi

  if [[ "$jadx_version_line" != "$JADX_VERSION" ]]; then
    echo "[bad-lock] jadx version mismatch: expected $JADX_VERSION, got $jadx_version_line"
    bad_lock=1
  else
    echo "[ok-lock] jadx version: $jadx_version_line"
  fi

  for cmd in apktool aapt2 zipalign jadx; do
    expected="$TOOLCHAIN_BIN_DIR/$cmd"
    resolved="$(command -v "$cmd" || true)"
    if [[ "$resolved" != "$expected" ]]; then
      echo "[bad-lock] $cmd resolves to $resolved (expected $expected)"
      bad_lock=1
    else
      echo "[ok-lock] $cmd path: $resolved"
    fi
  done
fi

if [[ "$missing_required" -ne 0 ]]; then
  echo "Dependency check failed: missing required commands found." >&2
  exit 1
fi

if [[ "$bad_path" -ne 0 ]]; then
  echo "Dependency check failed: commands resolve to local /root/android-sdk." >&2
  echo "Use system PATH tools instead (distro paths like /usr/lib/android-sdk are fine)." >&2
  exit 1
fi

if [[ "$bad_lock" -ne 0 ]]; then
  echo "Dependency check failed: locked toolchain does not match expected versions/paths." >&2
  echo "Run: make toolchain-bootstrap" >&2
  echo "Or bypass lock intentionally with: USE_SYSTEM_TOOLS=1 make check-env" >&2
  exit 1
fi

if [[ "$missing_optional" -ne 0 ]]; then
  echo "Dependency check passed with optional tools missing."
  echo "Optional impacts: verify-patch may need 'rg'."
else
  if [[ "$lock_mode" -eq 1 ]]; then
    echo "Dependency check passed with locked local toolchain."
  else
    echo "Dependency check passed (system tools mode: USE_SYSTEM_TOOLS=1)."
  fi
fi
