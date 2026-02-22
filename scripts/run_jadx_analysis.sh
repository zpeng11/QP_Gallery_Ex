#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
# shellcheck disable=SC1091
source "$SCRIPT_DIR/toolchain_env.sh"
toolchain_apply_path

ANALYSIS_DIR="${2:-$PROJECT_DIR/analysis}"
SOURCE_URL_FILE="${3:-${SOURCE_URL_FILE:-$PROJECT_DIR/original/stable.url}}"
FORCE_ANALYSIS="${FORCE_ANALYSIS:-0}"
STRICT_ANALYSIS="${STRICT_ANALYSIS:-0}"
DEFAULT_APK="$("$SCRIPT_DIR/resolve_source_apk_path.sh" "$SOURCE_URL_FILE" "$PROJECT_DIR/original")"
APK_PATH="${1:-$DEFAULT_APK}"

JADX_ROOT="$ANALYSIS_DIR/jadx"
LATEST_LINK="$JADX_ROOT/latest"

if [[ ! -f "$APK_PATH" ]]; then
  echo "APK not found: $APK_PATH" >&2
  exit 1
fi

if ! command -v jadx >/dev/null 2>&1; then
  echo "jadx not found in PATH." >&2
  exit 1
fi

source_url=""
if [[ -f "$SOURCE_URL_FILE" ]]; then
  source_url="$(sed -e 's/#.*$//' "$SOURCE_URL_FILE" | awk 'NF { print; exit }' | tr -d '\r')"
fi

apk_base="$(basename "$APK_PATH")"
apk_stem="${apk_base%.apk}"
version=""
if [[ -n "$source_url" && "$source_url" =~ /download/([^/]+)/ ]]; then
  version="${BASH_REMATCH[1]}"
fi
version="$(echo "$version" | tr -cd 'A-Za-z0-9._-')"
if [[ -n "$version" && "$apk_stem" != *"-$version" ]]; then
  run_name="${apk_stem}-${version}"
else
  run_name="$apk_stem"
fi

RUN_DIR="$JADX_ROOT/$run_name"
mkdir -p "$JADX_ROOT"

run_dir_is_complete() {
  local dir="$1"
  [[ -d "$dir" && -d "$dir/sources" && -d "$dir/resources" && -f "$dir/ANALYSIS_META.txt" ]]
}

analysis_status="cached"
jadx_exit_code=0
run_log="$RUN_DIR/JADX_RUN.log"
regenerated=0

if [[ "$FORCE_ANALYSIS" == "1" ]]; then
  rm -rf "$RUN_DIR"
fi

if run_dir_is_complete "$RUN_DIR"; then
  echo "JADX run already exists, skip decompile: $RUN_DIR"
else
  if [[ -d "$RUN_DIR" ]]; then
    echo "Existing JADX run is incomplete, rebuilding: $RUN_DIR"
    rm -rf "$RUN_DIR"
  fi

  mkdir -p "$RUN_DIR"
  set +e
  jadx -d "$RUN_DIR" "$APK_PATH" 2>&1 | tee "$run_log"
  jadx_exit_code="${PIPESTATUS[0]}"
  set -e
  regenerated=1

  if [[ "$jadx_exit_code" -eq 0 ]]; then
    analysis_status="ok"
    echo "Generated JADX run: $RUN_DIR"
  else
    analysis_status="partial"
    echo "jadx finished with non-zero exit ($jadx_exit_code). Output may be partial: $RUN_DIR" >&2
  fi

  if [[ ! -d "$RUN_DIR/sources" || ! -d "$RUN_DIR/resources" ]]; then
    echo "JADX output missing expected directories (sources/resources): $RUN_DIR" >&2
    exit 1
  fi
fi

ln -sfn "$RUN_DIR" "$LATEST_LINK"

if [[ "$regenerated" -eq 1 ]]; then
  apk_sha256="$(sha256sum "$APK_PATH" | awk '{print $1}')"
  apk_size_bytes="$(stat -c '%s' "$APK_PATH")"
  jadx_version="$(jadx --version | head -n 1)"
  generated_utc="$(date -u +%Y-%m-%dT%H:%M:%SZ)"

  cat > "$RUN_DIR/ANALYSIS_META.txt" <<EOF
run_name=$run_name
generated_utc=$generated_utc
apk_path=$APK_PATH
apk_sha256=$apk_sha256
apk_size_bytes=$apk_size_bytes
source_url=$source_url
jadx_version=$jadx_version
analysis_status=$analysis_status
jadx_exit_code=$jadx_exit_code
run_log=$run_log
EOF

  if [[ "$analysis_status" == "partial" && "$STRICT_ANALYSIS" == "1" ]]; then
    echo "Analysis failed in strict mode (STRICT_ANALYSIS=1). See log: $run_log" >&2
    exit 1
  fi
fi

INDEX_FILE="$JADX_ROOT/INDEX.md"
{
  echo "# JADX Analysis Index"
  echo ""
  echo "| Run | Status | Generated UTC | SHA256 | Source URL |"
  echo "| --- | --- | --- | --- | --- |"
  find "$JADX_ROOT" -mindepth 1 -maxdepth 1 -type d -printf "%f\n" | sort | while IFS= read -r run; do
      meta="$JADX_ROOT/$run/ANALYSIS_META.txt"
      if [[ -f "$meta" ]]; then
        status="$(sed -n 's/^analysis_status=//p' "$meta")"
        status="${status:-unknown}"
        gen="$(sed -n 's/^generated_utc=//p' "$meta")"
        sha="$(sed -n 's/^apk_sha256=//p' "$meta")"
        url="$(sed -n 's/^source_url=//p' "$meta")"
      else
        status="missing-meta"
        gen=""
        sha=""
        url=""
      fi
      echo "| $run | $status | $gen | \`$sha\` | $url |"
    done
} > "$INDEX_FILE"

echo "Updated latest link: $LATEST_LINK -> $RUN_DIR"
echo "Updated analysis index: $INDEX_FILE"
