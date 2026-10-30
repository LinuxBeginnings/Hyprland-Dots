#!/usr/bin/env bash
# ==================================================
#  KoolDots (2026)
#  Project URL: https://github.com/LinuxBeginnings
#  License: GNU GPLv3
#  SPDX-License-Identifier: GPL-3.0-or-later
# ==================================================
# Purpose:
#   Tests the resolution order in WallustConfig.sh.
#
#   wallust is the default and butterpal is opt-in. butterpal is not installed
#   by default, so resolving to it whenever it happens to be on PATH made the
#   source depend on the machine rather than on the choice.
#
#   Each case runs in its own bash with its own environment and prints the
#   resolved palette_source, so nothing leaks between them.
# No `set -e`: the assertion helpers return non-zero on failure, and exiting on
# the first one would hide every later check in the run.
set -uo pipefail
HERE="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=./lib_test.sh
source "$HERE/lib_test.sh"

CONFIG="$SCRIPT_DIR/WallustConfig.sh"
WORK="$(mktemp -d)"
trap 'rm -rf -- "$WORK"' EXIT

for choice in wallust butterpal; do
  mkdir -p "$WORK/state-$choice/hypr"
  printf '%s\n' "$choice" >"$WORK/state-$choice/hypr/palette_source"
done
mkdir -p "$WORK/emptybin"

# check <label> <expected> <command...>
check() {
  local label="$1" expected="$2"
  shift 2
  local got
  got="$("$@" /bin/bash -c ". '$CONFIG' >/dev/null 2>&1; printf '%s' \"\$palette_source\"")"
  assert_eq "$label" "$expected" "$got"
}

check "no environment, no state file" wallust \
  env -u KOOLDOTS_PALETTE_SOURCE XDG_STATE_HOME="$WORK/state-none"
check "state file says wallust" wallust \
  env -u KOOLDOTS_PALETTE_SOURCE XDG_STATE_HOME="$WORK/state-wallust"
check "state file says butterpal" butterpal \
  env -u KOOLDOTS_PALETTE_SOURCE XDG_STATE_HOME="$WORK/state-butterpal"
check "the environment beats the state file" butterpal \
  env KOOLDOTS_PALETTE_SOURCE=butterpal XDG_STATE_HOME="$WORK/state-wallust"
check "an unrecognised value falls back" wallust \
  env KOOLDOTS_PALETTE_SOURCE=nonsense XDG_STATE_HOME="$WORK/state-none"
check "butterpal chosen but not on PATH" wallust \
  env -u KOOLDOTS_PALETTE_SOURCE PATH="$WORK/emptybin" XDG_STATE_HOME="$WORK/state-butterpal"

summary "test-palette-source"
