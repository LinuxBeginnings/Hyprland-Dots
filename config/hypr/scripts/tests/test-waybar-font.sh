#!/usr/bin/env bash
# ==================================================
#  KoolDots (2026)
#  Project URL: https://github.com/LinuxBeginnings
#  License: GNU GPLv3
#  SPDX-License-Identifier: GPL-3.0-or-later
# ==================================================
# Purpose:
#   Tests for WaybarFont.sh engine and patches/45-waybar-font.sh.
#   Verifies reading, applying, restoring font family and font size overrides,
#   persisting to user_env.lua, updating stylesheets, and update patch sync.

set -uo pipefail

HERE="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=./lib_test.sh
source "$HERE/lib_test.sh"

ENGINE="$SCRIPT_DIR/WaybarFont.sh"
PATCH_DIR="$SCRIPT_DIR/../../../patches"
PATCH="$PATCH_DIR/45-waybar-font.sh"

WORK="$(mktemp -d)"; trap 'rm -rf -- "$WORK"' EXIT

INST="$WORK/home"
HYPR="$INST/hypr"
UC="$HYPR/UserConfigs"
USER_ENV="$UC/user_env.lua"
WB="$HYPR/waybar"
STYLES="$WB/style"

seed_test_env() {
  rm -rf "$INST"
  mkdir -p "$UC" "$STYLES"

  # Seed template user_env.lua
  cat >"$USER_ENV" <<'LUA'
-- User environment overrides template
hl.env("WEATHER_UNITS", "metric")
-- hl.env("WAYBAR_FONT", "JetBrainsMono Nerd Font")
-- hl.env("WAYBAR_FONT_SIZE", "14")
LUA

  # Seed standard waybar stylesheet
  cat >"$STYLES/Standard.css" <<'CSS'
* {
  font-family: "JetBrainsMono Nerd Font";
  font-weight: bold;
}

window#waybar {
  /* Waybar scaling: adjust font-size to scale the bar */
  font-size: 14px;
}

tooltip label {
  /* Waybar scaling: adjust font-size to scale the bar */
  font-size: 14px;
}
CSS

  # Seed multi-font style like Oglo Chicklets
  cat >"$STYLES/Oglo.css" <<'CSS'
* {
  font-family:
    "JetBrainsMono Nerd Font", FontAwesome, Roboto;
  font-size: 14px;
}

window#waybar {
  font-size: 14px;
}
CSS
}

run_engine() {
  env KOOLDOTS_HYPR_DIR="$HYPR" \
      KOOLDOTS_USER_ENV_LUA="$USER_ENV" \
      KOOLDOTS_WAYBAR_DIR="$WB" \
      KOOLDOTS_STYLES_DIR="$STYLES" \
      KOOLDOTS_SCRIPTS_DIR="$SCRIPT_DIR" \
      bash "$ENGINE" "$@"
}

run_patch() {
  env KOOLDOTS_CONFIG_HOME="$INST" \
      KOOLDOTS_REPO_ROOT="$SCRIPT_DIR/../../.." \
      KOOLDOTS_LOG="$WORK/patch.log" \
      bash "$PATCH"
}

# --- 1. Initial State / Defaults ---------------------------------------------
seed_test_env

it "reports default font and size when overrides are not active"
json=$(run_engine get)
assert_contains "$json" '"font":"JetBrainsMono Nerd Font"' "default font missing from json"
assert_contains "$json" '"size":"14"' "default size missing from json"
assert_contains "$json" '"override_active":false' "override should not be active" && pass_msg

it "is-active exits non-zero on default state"
if run_engine is-active; then
  fail "is-active should fail when overrides are commented out"
else
  pass_msg
fi

# --- 2. Apply Custom Font and Size -------------------------------------------
it "applies custom font and size without restarting Waybar in test"
run_engine apply "FiraCode Nerd Font" "18" --no-restart || fail "apply command failed"
pass_msg

it "writes custom font and size to user_env.lua"
assert_contains "$USER_ENV" 'hl.env("WAYBAR_FONT", "FiraCode Nerd Font")' "WAYBAR_FONT not written to user_env.lua"
assert_contains "$USER_ENV" 'hl.env("WAYBAR_FONT_SIZE", "18")' "WAYBAR_FONT_SIZE not written to user_env.lua" && pass_msg

it "reports override active after applying"
if run_engine is-active; then
  pass_msg
else
  fail "is-active should succeed when overrides are set"
fi

it "get-font and get-size return new overrides"
assert_eq "custom font name" "FiraCode Nerd Font" "$(run_engine get-font)"
assert_eq "custom font size" "18" "$(run_engine get-size)"

it "updates font-family in stylesheets"
assert_contains "$STYLES/Standard.css" 'font-family: "FiraCode Nerd Font";' "Standard.css font-family not updated"
assert_contains "$STYLES/Oglo.css" 'font-family: "FiraCode Nerd Font";' "Oglo.css font-family not updated" && pass_msg

it "updates font-size in stylesheets"
assert_contains "$STYLES/Standard.css" 'font-size: 18px;' "Standard.css font-size not updated"
assert_contains "$STYLES/Oglo.css" 'font-size: 18px;' "Oglo.css font-size not updated" && pass_msg

# --- 3. Partial Overrides (Size Only / Font Only) ----------------------------
seed_test_env

it "applies only size override while keeping font default"
run_engine apply "" "20" --no-restart || fail "partial size apply failed"
assert_contains "$USER_ENV" 'hl.env("WAYBAR_FONT_SIZE", "20")' "WAYBAR_FONT_SIZE not written"
assert_contains "$STYLES/Standard.css" 'font-size: 20px;' "font-size not updated to 20px"
assert_contains "$STYLES/Standard.css" 'font-family: "JetBrainsMono Nerd Font";' "font-family should remain default" && pass_msg

# --- 4. Restore Defaults -----------------------------------------------------
it "restore command resets user_env.lua and stylesheets"
run_engine restore --no-restart || fail "restore command failed"
if grep -qE '^[[:space:]]*hl\.env\([[:space:]]*["'\'']WAYBAR_FONT["'\'']' "$USER_ENV"; then
  fail "active WAYBAR_FONT should be commented out"
fi
assert_contains "$USER_ENV" '-- hl.env("WAYBAR_FONT"' "commented WAYBAR_FONT should be present"
assert_contains "$STYLES/Standard.css" 'font-family: "JetBrainsMono Nerd Font";' "Standard.css font should be restored"
assert_contains "$STYLES/Standard.css" 'font-size: 14px;' "Standard.css size should be restored" && pass_msg

it "is-active exits non-zero after restore"
if run_engine is-active; then
  fail "is-active should fail after restore"
else
  pass_msg
fi

# --- 5. Update Patch (patches/45-waybar-font.sh) -----------------------------
if [[ -f "$PATCH" ]]; then
  seed_test_env

  it "patch skips cleanly when user_env.lua has no overrides"
  run_patch >/dev/null 2>&1 || fail "patch failed on clean user_env.lua"
  assert_contains "$STYLES/Standard.css" 'font-size: 14px;' "stylesheets should remain unchanged" && pass_msg

  it "patch syncs overrides when user_env.lua defines font and size"
  cat >"$USER_ENV" <<'LUA'
hl.env("WAYBAR_FONT", "Hack Nerd Font")
hl.env("WAYBAR_FONT_SIZE", "16")
LUA
  run_patch >/dev/null 2>&1 || fail "patch failed with defined overrides"
  assert_contains "$STYLES/Standard.css" 'font-family: "Hack Nerd Font";' "patch did not update font"
  assert_contains "$STYLES/Standard.css" 'font-size: 16px;' "patch did not update size" && pass_msg

  it "patch is idempotent on repeated runs"
  before="$(cat "$STYLES/Standard.css")"
  run_patch >/dev/null 2>&1 || fail "repeated patch run failed"
  assert_eq "stylesheet byte-identical after second run" "$before" "$(cat "$STYLES/Standard.css")"
fi

# --- 6. Missing Target Safety ------------------------------------------------
it "patch exits cleanly when target directory is absent"
env KOOLDOTS_CONFIG_HOME="$WORK/nonexistent" bash "$PATCH" >/dev/null 2>&1 && pass_msg || fail "patch should exit 0 on missing config"

summary "test-waybar-font"
