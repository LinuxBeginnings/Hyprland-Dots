#!/usr/bin/env bash
# ==================================================
#  KoolDots (2026)
#  Project URL: https://github.com/LinuxBeginnings
#  License: GNU GPLv3
#  SPDX-License-Identifier: GPL-3.0-or-later
# ==================================================
# Purpose:
#   Runs every display-layout suite and prints one line each. Exits non-zero if
#   any suite failed, so it is usable as a single gate.
set -uo pipefail
HERE="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
OUT_DIR="${TMPDIR:-/tmp}/kooldots-display-tests.$$"
mkdir -p -- "$OUT_DIR"
trap 'rm -rf -- "$OUT_DIR"' EXIT

total_failed=0
total_run=0
for t in "$HERE"/test-*.sh; do
  name="$(basename -- "$t" .sh)"
  # Long output goes to a file; only the summary line is printed.
  timeout 600 bash "$t" >"$OUT_DIR/$name.out" 2>&1
  line="$(grep -E '^[a-z-]+: [0-9]+ run, [0-9]+ failed$' "$OUT_DIR/$name.out" | tail -1)"
  if [[ -z $line ]]; then
    printf '%-32s NO SUMMARY (crashed or timed out)\n' "$name"
    sed -n '$p' "$OUT_DIR/$name.out" | sed 's/^/    /'
    total_failed=$((total_failed + 1))
    continue
  fi
  run="$(printf '%s' "$line" | sed 's/.*: \([0-9]*\) run.*/\1/')"
  failed="$(printf '%s' "$line" | sed 's/.*run, \([0-9]*\) failed/\1/')"
  total_run=$((total_run + run))
  total_failed=$((total_failed + failed))
  printf '%-32s %s run, %s failed\n' "$name" "$run" "$failed"
  if (( failed > 0 )); then grep -A1 '^FAIL' "$OUT_DIR/$name.out" | sed 's/^/    /'; fi
done

printf '\n%d checks, %d failed\n' "$total_run" "$total_failed"
(( total_failed == 0 ))
