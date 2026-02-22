#!/usr/bin/env bash

# Shared toolchain environment helpers.
# This file is intended to be sourced by other scripts.

TOOLCHAIN_ENV_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [[ -z "${PROJECT_DIR:-}" ]]; then
  PROJECT_DIR="$(cd "$TOOLCHAIN_ENV_DIR/.." && pwd)"
fi

TOOLCHAIN_LOCK_FILE="${TOOLCHAIN_LOCK_FILE:-$PROJECT_DIR/toolchain.lock}"
TOOLCHAIN_DIR="${TOOLCHAIN_DIR:-$PROJECT_DIR/.tooling/android}"
TOOLCHAIN_BIN_DIR="${TOOLCHAIN_BIN_DIR:-$PROJECT_DIR/.tooling/bin}"
APKTOOL_FRAMEWORK_DIR="${APKTOOL_FRAMEWORK_DIR:-$PROJECT_DIR/.tooling/apktool-framework}"
USE_SYSTEM_TOOLS="${USE_SYSTEM_TOOLS:-0}"

export TOOLCHAIN_LOCK_FILE
export TOOLCHAIN_DIR
export TOOLCHAIN_BIN_DIR
export APKTOOL_FRAMEWORK_DIR
export USE_SYSTEM_TOOLS

toolchain_apply_path() {
  if [[ "$USE_SYSTEM_TOOLS" == "1" ]]; then
    return 0
  fi
  export PATH="$TOOLCHAIN_BIN_DIR:$PATH"
}

toolchain_load_lock() {
  if [[ ! -f "$TOOLCHAIN_LOCK_FILE" ]]; then
    echo "Toolchain lock file not found: $TOOLCHAIN_LOCK_FILE" >&2
    return 1
  fi

  # shellcheck disable=SC1090
  source "$TOOLCHAIN_LOCK_FILE"

  if [[ -z "${APKTOOL_VERSION:-}" || -z "${ANDROID_BUILD_TOOLS_VERSION:-}" || -z "${JADX_VERSION:-}" ]]; then
    echo "Invalid lock file content: $TOOLCHAIN_LOCK_FILE" >&2
    return 1
  fi
}
