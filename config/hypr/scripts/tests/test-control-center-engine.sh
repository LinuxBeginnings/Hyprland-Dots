#!/usr/bin/env bash
# ==================================================
#  KoolDots (2026)
#  Project URL: https://github.com/LinuxBeginnings
#  License: GNU GPLv3
#  SPDX-License-Identifier: GPL-3.0-or-later
# ==================================================
# Purpose:
#   Unit tests for KoolSettingsEngine.sh (KoolDots Control Center backend).
#   Verifies system info, keybind parsing, syntax/duplicate validation,
#   window rules parsing, backup/revert, and error logging.

set -uo pipefail

HERE="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=./lib_test.sh
source "$HERE/lib_test.sh"

ENGINE="$SCRIPT_DIR/KoolSettingsEngine.sh"

WORK="$(mktemp -d)"; trap 'rm -rf -- "$WORK"' EXIT

INST="$WORK/home"
HYPR="$INST/hypr"
UC="$HYPR/UserConfigs"
SYS="$HYPR/configs"
STATE="$WORK/state"

seed_test_env() {
  rm -rf "$INST"
  mkdir -p "$UC" "$SYS" "$STATE/hypr"

  # Seed user_keybinds.lua
  cat >"$UC/user_keybinds.lua" <<'LUA'
bind("SUPER", "Return", exec_cmd("kitty"), { description = "Terminal" })
bind("SUPER", "E", exec_cmd("thunar"), { description = "File Manager" })
unbind("SUPER", "Q")
LUA

  # Seed system_keybinds.lua
  cat >"$SYS/system_keybinds.lua" <<'LUA'
bind("SUPER", "C", exec_cmd("google-chrome"), { description = "Browser" })
bind("SUPER", "Q", dispatch("killactive"), { description = "Close Window" })
LUA

  # Seed user_window_rules.lua
  cat >"$UC/user_window_rules.lua" <<'LUA'
apply_window_rule({
  name = "test-float-pavu",
  match = { class = "^(pavucontrol)$" },
  float = true,
  center = true,
  size = "600 400",
})
LUA

  # Seed user_startup.lua
  cat >"$UC/user_startup.lua" <<'LUA'
local startup_commands = {
  "blueman-applet",
  -- "kdeconnect-app",
  "nm-applet --indicator",
}
LUA
}

run_engine() {
  env KOOLDOTS_HYPR_DIR="$HYPR" \
      KOOLDOTS_USER_CONFIGS="$UC" \
      KOOLDOTS_SYSTEM_CONFIGS="$SYS" \
      KOOLDOTS_SCRIPTS_DIR="$SCRIPT_DIR" \
      KOOLDOTS_BACKUP_DIR="$STATE/hypr/backups" \
      KOOLDOTS_ERROR_LOG="$STATE/hypr/kooldots-settings-errors.log" \
      XDG_STATE_HOME="$STATE" \
      bash "$ENGINE" "$@"
}

# --- 1. System Info -----------------------------------------------------------
seed_test_env

it "reports system info as valid JSON"
info_json=$(run_engine get-info)
assert_contains "$info_json" '"dots_version":' "dots_version missing"
assert_contains "$info_json" '"hyprland_version":' "hyprland_version missing"
assert_contains "$info_json" '"distro":' "distro missing" && pass_msg

# --- 2. Keybindings Listing & Source Tagging ----------------------------------
it "lists keybinds and accurately tags User vs System sources"
kb_json=$(run_engine list-keybinds)
assert_contains "$kb_json" '"chord": "SUPER+Return"' "SUPER+Return missing"
assert_contains "$kb_json" '"source": "user"' "user source missing"
assert_contains "$kb_json" '"chord": "SUPER+C"' "SUPER+C missing"
assert_contains "$kb_json" '"source": "system"' "system source missing" && pass_msg

it "identifies unbind calls in UserConfigs"
assert_contains "$kb_json" '"is_unbind": true' "unbind record missing" && pass_msg

# --- 3. Keybind Validation (Syntax & Duplicates) ------------------------------
it "passes validation on clean user_keybinds.lua"
val_clean=$(run_engine validate-keybinds)
assert_contains "$val_clean" '"valid": true' "clean file should be valid" && pass_msg

it "detects duplicate key combinations in user_keybinds.lua"
cat >>"$UC/user_keybinds.lua" <<'LUA'
bind("SUPER", "Return", exec_cmd("ghostty"), { description = "Duplicate" })
LUA
val_dup=$(run_engine validate-keybinds)
assert_contains "$val_dup" '"valid": false' "duplicate should be invalid"
assert_contains "$val_dup" 'Duplicate key combinations' "duplicate error missing" && pass_msg

it "detects syntax errors in user_keybinds.lua"
cat >"$UC/user_keybinds.lua" <<'LUA'
bind("SUPER", "Return", BROKEN SYNTAX {{{
LUA
val_syn=$(run_engine validate-keybinds || true)
assert_contains "$val_syn" '"valid": false' "syntax error should be invalid" && pass_msg

# --- 4. Window Rules Listing --------------------------------------------------
seed_test_env

it "lists window rules from UserConfigs"
rules_json=$(run_engine list-rules)
assert_contains "$rules_json" '"name": "test-float-pavu"' "rule name missing"
assert_contains "$rules_json" '"source": "user"' "user source missing"
assert_contains "$rules_json" '"float": true' "float action missing" && pass_msg

# --- 5. Startup Commands Listing ----------------------------------------------
it "lists startup commands with enabled status"
startup_json=$(run_engine list-startup)
assert_contains "$startup_json" '"command": "blueman-applet", "enabled": true' "blueman enabled missing"
assert_contains "$startup_json" '"command": "kdeconnect-app", "enabled": false' "kdeconnect disabled missing" && pass_msg

# --- 6. Backup & Revert -------------------------------------------------------
seed_test_env

it "creates backups and reverts file to pre-edit state"
target="$UC/user_keybinds.lua"
orig_content=$(cat "$target")

# Make an edit via apply-keybind
run_engine apply-keybind "SUPER ALT" "K" "exec" "pavucontrol" "Volume mixer" "" "" >/dev/null

assert_contains "$target" 'SUPER ALT' "keybind was not added"
assert_contains "$target" 'pavucontrol' "command was not added"

# Revert
revert_out=$(run_engine revert "$target")
assert_contains "$revert_out" '"reverted": true' "revert failed"
assert_eq "file restored to original content" "$orig_content" "$(cat "$target")"

# --- 7. Error Log Recording & Copying -----------------------------------------
it "records error log entries on failed operations"
log_file="$STATE/hypr/kooldots-settings-errors.log"
assert_contains "$log_file" 'syntax' "syntax step not logged in error log"
assert_contains "$log_file" 'ENVIRONMENT: KoolDots' "environment context missing from error log" && pass_msg

summary "test-control-center-engine"
