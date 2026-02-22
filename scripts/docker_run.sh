#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

DOCKER_BIN="${DOCKER_BIN:-docker}"
DOCKER_IMAGE="${DOCKER_IMAGE:-qp-apktool:local}"
HOST_HOME="${HOME:-}"
HOST_UID="$(id -u)"
HOST_GID="$(id -g)"
HOST_USER="$(id -un)"

if ! command -v "$DOCKER_BIN" >/dev/null 2>&1; then
  echo "docker not found in PATH (expected command: $DOCKER_BIN)." >&2
  exit 1
fi

if [[ -z "$HOST_HOME" || ! -d "$HOST_HOME" ]]; then
  echo "Valid HOME is required for host identity passthrough." >&2
  exit 1
fi

docker_args=(
  run
  --rm
  --user "$HOST_UID:$HOST_GID"
  -e "HOME=$HOST_HOME"
  -e "USER=$HOST_USER"
  -e "LOGNAME=$HOST_USER"
  -v "$PROJECT_DIR:$PROJECT_DIR"
  -w "$PROJECT_DIR"
  -v "$HOST_HOME:$HOST_HOME"
)

if [[ -t 1 ]]; then
  docker_args+=(-it)
fi

for var in SOURCE_URL_FILE FORCE_DOWNLOAD FORCE_ANALYSIS STRICT_ANALYSIS KEEP STRICT_NO_LOCAL_SDK USE_SYSTEM_TOOLS; do
  if [[ -n "${!var-}" ]]; then
    docker_args+=(-e "$var=${!var}")
  fi
done

if [[ -n "${DOCKER_RUN_ARGS:-}" ]]; then
  # shellcheck disable=SC2206
  extra_args=(${DOCKER_RUN_ARGS})
  docker_args+=("${extra_args[@]}")
fi

if [[ "$#" -eq 0 ]]; then
  set -- make rebuild-patched
fi

exec "$DOCKER_BIN" "${docker_args[@]}" "$DOCKER_IMAGE" "$@"
