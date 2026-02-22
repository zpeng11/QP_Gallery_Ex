#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

JADX_ROOT="${1:-$PROJECT_DIR/analysis/jadx}"
KEEP_COUNT="${2:-3}"
LATEST_LINK="$JADX_ROOT/latest"

if [[ ! -d "$JADX_ROOT" ]]; then
  echo "JADX root does not exist: $JADX_ROOT"
  exit 0
fi

if ! [[ "$KEEP_COUNT" =~ ^[0-9]+$ ]]; then
  echo "KEEP_COUNT must be an integer, got: $KEEP_COUNT" >&2
  exit 1
fi

mapfile -t run_dirs < <(
  find "$JADX_ROOT" -mindepth 1 -maxdepth 1 -type d -printf "%T@ %p\n" | sort -nr | awk '{print $2}'
)

total="${#run_dirs[@]}"
latest_target=""
if [[ -L "$LATEST_LINK" ]]; then
  latest_target="$(readlink -f "$LATEST_LINK" 2>/dev/null || true)"
  if [[ -n "$latest_target" && "$latest_target" != "$JADX_ROOT/"* ]]; then
    latest_target=""
  fi
fi

kept=0
removed=0
protected_latest=0

for run_dir in "${run_dirs[@]}"; do
  if [[ -n "$latest_target" && "$run_dir" == "$latest_target" ]]; then
    protected_latest=1
    if (( kept < KEEP_COUNT )); then
      kept=$((kept + 1))
    fi
    echo "Keeping latest run: $run_dir"
    continue
  fi

  if (( kept < KEEP_COUNT )); then
    kept=$((kept + 1))
    continue
  fi

  rm -rf "$run_dir"
  removed=$((removed + 1))
  echo "Pruned JADX run: $run_dir"
done

if (( removed == 0 )); then
  echo "No prune needed. total_runs=$total keep=$KEEP_COUNT latest_protected=$protected_latest"
else
  echo "Prune complete. total_runs=$total keep=$KEEP_COUNT removed=$removed latest_protected=$protected_latest"
fi
