#!/usr/bin/env bash
# ==================================================
#  KoolDots (2026)
#  Project URL: https://github.com/LinuxBeginnings
#  License: GNU GPLv3
#  SPDX-License-Identifier: GPL-3.0-or-later
# ==================================================
# Purpose:
#   The animation chosen from the Animations menu was lost by an upgrade that
#   migrated to the Lua config. Two things combined:
#
#     * copy.sh copies the repo's UserConfigs before the migration runs, so the
#       shipped comment-only user_animations.lua is already in place;
#     * the migration kept any existing user_animations.lua, so that placeholder
#       won over the animation the user had actually picked.
#
#   On a hyprlang install the choice lives in UserConfigs/UserAnimations.conf,
#   which is what scripts/migrate-hypr-to-lua.sh now converts. These checks run
#   the real script against a sandbox XDG_CONFIG_HOME: no session, no
#   compositor, no Hyprland.
# No `set -e`: the assertion helpers return non-zero on failure, and exiting on
# the first one would hide every later check in the run.
set -uo pipefail
HERE="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=./lib_test.sh
source "$HERE/lib_test.sh"

# lib_test.sh sets SCRIPT_DIR to the scripts directory; the migration script
# lives at the repo root, three levels up. It is repo-only: it is not installed
# with config/hypr, so running from an install skips the suite.
REPO_ROOT="$SCRIPT_DIR/../../.."
MIGRATE="$REPO_ROOT/scripts/migrate-hypr-to-lua.sh"
PLACEHOLDER="$REPO_ROOT/config/hypr/UserConfigs/user_animations.lua"
SHIPPED_PRESET="$REPO_ROOT/config/hypr/animations/ML4W - classic.lua"

if [ ! -f "$MIGRATE" ] || [ ! -f "$PLACEHOLDER" ]; then
  it "the migration script is not present here (repo-only test)"
  pass_msg
  summary "test-migrate-animations"
  exit 0
fi

if ! command -v python3 >/dev/null 2>&1; then
  it "python3 is not installed; the migration cannot run here"
  pass_msg
  summary "test-migrate-animations"
  exit 0
fi

WORK="$(mktemp -d)"; trap 'rm -rf -- "$WORK"' EXIT

# run_migration <case> [existing-user_animations.lua]
# Seeds a sandbox install with the repo's shipped placeholder (what copy.sh
# leaves behind) and, when given, the user_animations.lua the user already has.
# UserAnimations.conf is read from stdin, then the migration runs. The paths of
# the run are left in CASE_ANIMATIONS and CASE_USERCONFIGS for the assertions.
run_migration() {
  local case_name="$1" existing="${2:-}"
  local case_dir="$WORK/$case_name"
  CASE_USERCONFIGS="$case_dir/cfg/hypr/UserConfigs"
  CASE_ANIMATIONS="$CASE_USERCONFIGS/user_animations.lua"
  CASE_LOG="$case_dir/migration.log"

  rm -rf -- "$case_dir"
  mkdir -p "$CASE_USERCONFIGS"
  if [ -n "$existing" ]; then
    cp -- "$existing" "$CASE_ANIMATIONS"
  else
    cp -- "$PLACEHOLDER" "$CASE_ANIMATIONS"
  fi
  cat > "$CASE_USERCONFIGS/UserAnimations.conf"

  XDG_CONFIG_HOME="$case_dir/cfg" bash "$MIGRATE" --yes >"$CASE_LOG" 2>&1
}

# --- a preset chosen before the Lua config took over ------------------------
run_migration classic <<'CONF'
# /* ---- https://github.com/LinuxBeginnings ---- */  #
#
# name "Classic"

animations {
    enabled = true
    bezier = myBezier, 0.05, 0.9, 0.1, 1.00
    animation = windows, 1, 7, myBezier
    animation = windowsOut, 1, 7, default, popin 80%
    animation = border, 1, 10, default
}
CONF
CLASSIC_ANIMATIONS="$CASE_ANIMATIONS"

it "the shipped placeholder is replaced by the animation that was chosen"
assert_not_contains "$CLASSIC_ANIMATIONS" 'Use this to override defaults' \
  "the template comment is gone" && pass_msg

it "the chosen bezier becomes a Lua curve"
assert_contains "$CLASSIC_ANIMATIONS" \
  'hl.curve("myBezier", { type = "bezier", points = { { 0.05, 0.9 }, { 0.1, 1.00 } } })' \
  "the curve is converted" && pass_msg

it "the animation entries become Lua animations"
assert_contains "$CLASSIC_ANIMATIONS" \
  'hl.animation({ leaf = "windows", enabled = true, speed = 7, bezier = "myBezier" })' \
  "a curve-less style stays absent" && pass_msg

it "a multi-word style survives the conversion"
assert_contains "$CLASSIC_ANIMATIONS" 'style = "popin 80%"' \
  "the style is quoted as one string" && pass_msg

it "the converted file passes a Lua syntax check"
if command -v luac >/dev/null 2>&1; then
  if luac -p -- "$CLASSIC_ANIMATIONS" >/dev/null 2>&1; then pass_msg
  else fail "luac rejected the converted animations"; fi
else
  pass_msg
fi

# --- the selection must not be resurrected once the user moves on -----------
it "a preset copied by the Animations menu is left untouched"
run_migration lua-preset "$SHIPPED_PRESET" <<'CONF'
animations {
    enabled = true
    bezier = stale, 0.9, 0.1, 0.1, 0.9
    animation = windows, 1, 2, stale
}
CONF
assert_eq "byte-identical to the preset" "$(cat "$SHIPPED_PRESET")" "$(cat "$CASE_ANIMATIONS")"

# --- nothing to carry -------------------------------------------------------
it "a conf with no animation settings leaves the placeholder alone"
run_migration comments <<'CONF'
# ==================================================
#  nothing but comments here
# ==================================================
CONF
assert_contains "$CASE_ANIMATIONS" 'Use this to override defaults' \
  "the placeholder is kept" && pass_msg

it "no UserAnimations.conf at all leaves the placeholder alone"
run_migration absent </dev/null
assert_contains "$CASE_ANIMATIONS" 'Use this to override defaults' \
  "the placeholder is kept" && pass_msg

# --- turning animations off is a choice too ---------------------------------
it "'enabled = no' alone is carried, so animations stay off"
run_migration disabled <<'CONF'
animations {
  enabled = no
}
CONF
assert_contains "$CASE_ANIMATIONS" 'enabled = false,' \
  "the off switch is converted" && pass_msg

# --- wiring -----------------------------------------------------------------
it "copy.sh runs the migration after the user's files are restored"
assert_order "$REPO_ROOT/copy.sh" 'restore_user_configs "$LOG"' 'migrate_hypr_to_lua_if_needed' \
  "the placeholder is in place before the migration" && pass_msg

summary "test-migrate-animations"
