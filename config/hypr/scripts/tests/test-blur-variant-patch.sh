#!/usr/bin/env bash
# ==================================================
#  KoolDots (2026)
#  Project URL: https://github.com/LinuxBeginnings
#  License: GNU GPLv3
#  SPDX-License-Identifier: GPL-3.0-or-later
# ==================================================
# Purpose:
#   Tests for patches/92-blur-variant-block.sh. copy.sh only ADDS missing
#   UserConfigs files, so an install made before the 0.57 blur-variant and
#   wobble blocks shipped keeps its old user_decorations.lua, and the blur
#   strength cycle keeps working while `variant` and wobble stay absent.
#   What is checked here is that the patch adds both blocks, that it never
#   resets a variant the user already picked, that it is content-idempotent,
#   and that it skips cleanly when there is nothing to patch.
# No `set -e`: the assertion helpers return non-zero on failure, and exiting on
# the first one would hide every later check in the run.
set -uo pipefail

HERE="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=./lib_test.sh
source "$HERE/lib_test.sh"

# lib_test.sh sets SCRIPT_DIR to the scripts directory; patches live at the
# repo root, three levels up.
PATCH_DIR="$SCRIPT_DIR/../../../patches"
PATCH="$PATCH_DIR/92-blur-variant-block.sh"
WORK="$(mktemp -d)"; trap 'rm -rf -- "$WORK"' EXIT

# The suite is installed with the rest of config/hypr, but patches/ is repo-side
# and the installer runs it from there. Running from ~/.config/hypr/scripts/tests
# therefore finds no patches, so say so and report clean.
if [[ ! -f "$PATCH" ]]; then
  it "the installer patches are not present here (repo-only test)"
  pass_msg
  summary "test-blur-variant-patch"
  exit 0
fi

INST="$WORK/home"
UC="$INST/hypr/UserConfigs"
DECOR="$UC/user_decorations.lua"

# The file shipped before the 0.57 blocks: a blur table, no `variant`, no wobble,
# and values the patch has no business changing.
seed_old() {
  rm -rf "$INST"
  mkdir -p "$UC"
  cat >"$DECOR" <<'LUA'
local active_col = "rgba(8db4ffff)"

hl.config({
  general = {
    border_size = 1,
    gaps_in = 4,
  },
})

hl.config({
  decoration = {
    rounding = 10,
    blur = {
      enabled = true,
      size = 6,
      passes = 3,
      new_optimizations = true,
      xray = false,
      ignore_opacity = true,
      special = true,
      popups = true,
    },
  },
})
LUA
}

run_patch() {  # [config-home]
  env KOOLDOTS_CONFIG_HOME="${1:-$INST}" KOOLDOTS_LOG="$WORK/patch.log" bash "$PATCH"
}

# --- activation -------------------------------------------------------------
seed_old
it "the patch runs cleanly on an install that predates the blocks"
run_patch && pass_msg || fail "the patch exited non-zero"

it "the blur-variant block is appended"
assert_contains "$DECOR" 'kooldots-patch: blur-variant-block' "" && pass_msg

it "the variant block is gated on the running compositor, not a version"
assert_contains "$DECOR" 'pcall(hl.get_config, key)' "the capability probe is missing"
assert_contains "$DECOR" 'if kd_has_option("decoration.blur.variant") then' \
  "the gate is missing" && pass_msg

it "it writes the default variant, so applying it changes nothing on its own"
assert_contains "$DECOR" 'variant = "kawase",' "" && pass_msg

it "the wobble block is appended with the shipped physics"
assert_contains "$DECOR" 'kooldots-patch: wobble-block' "the wobble sentinel is missing"
assert_contains "$DECOR" 'if kd_has_option("decoration.wobble.enabled") then' "the gate is missing"
assert_contains "$DECOR" 'stiffness = 240,' "the physics is not the shipped set" && pass_msg

it "the user's own decoration values survive"
assert_contains "$DECOR" 'passes = 3,' "the blur table was rewritten"
assert_contains "$DECOR" 'gaps_in = 4,' "the general table was rewritten" && pass_msg

# --- idempotency ------------------------------------------------------------
before="$(cat "$DECOR")"
it "a second run changes nothing"
run_patch >/dev/null 2>&1 || fail "the second run exited non-zero"
assert_eq "the file is byte-identical after a second run" "$before" "$(cat "$DECOR")"

it "each block was appended exactly once"
assert_count 1 "$DECOR" 'kooldots-patch: blur-variant-block'
assert_count 1 "$DECOR" 'kooldots-patch: wobble-block' && pass_msg

# --- never reset a choice the user already made -----------------------------
it "a file that already sets variant is left alone, wobble still added"
rm -rf "$INST"; mkdir -p "$UC"
cat >"$DECOR" <<'LUA'
hl.config({
  decoration = {
    blur = {
      variant = "frost",
    },
  },
})
LUA
run_patch >/dev/null 2>&1 || fail "the patch exited non-zero"
assert_not_contains "$DECOR" 'kooldots-patch: blur-variant-block' \
  "the variant block was appended over a chosen variant"
assert_contains "$DECOR" 'kooldots-patch: wobble-block' "wobble was not added"
assert_count 1 "$DECOR" 'variant = "frost"' && pass_msg

it "a file that already has a wobble table is not given a second one"
rm -rf "$INST"; mkdir -p "$UC"
cat >"$DECOR" <<'LUA'
hl.config({ decoration = { wobble = { enabled = false } } })
LUA
run_patch >/dev/null 2>&1 || fail "the patch exited non-zero"
assert_contains "$DECOR" 'kooldots-patch: blur-variant-block' "the variant block was not added"
assert_not_contains "$DECOR" 'kooldots-patch: wobble-block' "a second wobble table was added"
assert_count 1 "$DECOR" 'wobble = {' && pass_msg

it "the shipped template is recognised and left untouched"
rm -rf "$INST"; mkdir -p "$UC"
cp "$SCRIPT_DIR/../UserConfigs/user_decorations.lua" "$DECOR"
before="$(cat "$DECOR")"
run_patch >/dev/null 2>&1 || fail "the patch exited non-zero"
assert_eq "the shipped file is byte-identical" "$before" "$(cat "$DECOR")"

# --- nothing to patch -------------------------------------------------------
mkdir -p "$WORK/empty"
it "a missing target is skipped cleanly"
run_patch "$WORK/empty" >/dev/null 2>&1 && pass_msg || fail "must exit 0 with nothing to patch"
it "it invents no config tree"
if [[ -e "$WORK/empty/hypr" ]]; then fail "it created files for an install that is not there"; else pass_msg; fi

summary "test-blur-variant-patch"
