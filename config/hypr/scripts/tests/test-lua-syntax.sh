#!/usr/bin/env bash
# ==================================================
#  KoolDots (2026)
#  Project URL: https://github.com/LinuxBeginnings
#  License: GNU GPLv3
#  SPDX-License-Identifier: GPL-3.0-or-later
# ==================================================
# Purpose:
#   Every .lua file under the config is loaded by Hyprland's Lua VM, and a single
#   syntax error in any one of them takes the whole config load down with it -
#   silently, if the file is loaded through a pcall, which is how the UserConfigs
#   files are loaded. So they are parsed here with a real parser rather than
#   trusted.
#
#   This is also the check that catches a broken file sitting in the config tree
#   by accident, such as a hand-made backup of a file that was already broken.
#
#   `luac` is not a dependency of the dots, so where it is missing this reports
#   and passes instead of failing.
# No `set -e`: the assertion helpers return non-zero on failure, and exiting on
# the first one would hide every later check in the run.
set -uo pipefail

HERE="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=./lib_test.sh
source "$HERE/lib_test.sh"

# The whole config tree, not just what the repo ships: run from the repo this is
# config/hypr, and run from an install it is ~/.config/hypr, so a user's own
# files are covered too.
ROOT="$(cd -- "$SCRIPT_DIR/.." && pwd)"

if ! command -v luac >/dev/null 2>&1; then
  it "luac is not installed, so the Lua files were not parsed"
  pass_msg
  summary "test-lua-syntax"
  exit 0
fi

it "every .lua file under the config parses"
count=0
bad=""
while IFS= read -r f; do
  count=$((count + 1))
  luac -p "$f" >/dev/null 2>&1 || bad="$bad ${f#"$ROOT"/}"
done < <(find "$ROOT" -name '*.lua' -type f 2>/dev/null | sort)
if [[ -n $bad ]]; then
  fail "luac rejected:$bad"
elif (( count == 0 )); then
  fail "found no .lua files under $ROOT"
else
  pass_msg
fi

it "the generated monitors.lua is covered by that sweep"
# It is written by DisplayProfile.sh, so it is the one file here that is not
# under version control; if it were excluded the sweep would be worth little.
if [[ -f "$ROOT/UserConfigs/monitors.lua" ]]; then
  luac -p "$ROOT/UserConfigs/monitors.lua" >/dev/null 2>&1 \
    && pass_msg || fail "UserConfigs/monitors.lua does not parse"
else
  pass_msg
fi

summary "test-lua-syntax"
