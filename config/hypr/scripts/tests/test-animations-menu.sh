#!/usr/bin/env bash
# ==================================================
#  KoolDots (2026)
#  Project URL: https://github.com/LinuxBeginnings
#  License: GNU GPLv3
#  SPDX-License-Identifier: GPL-3.0-or-later
# ==================================================
# Purpose:
#   Tests for the marker the Animations menu puts on the preset that is loaded.
#   The menu has to work out what is loaded from the live files, so the cases
#   worth covering are: an exact copy of a preset, a file that matches nothing
#   but was recorded, a placeholder, and the marker being stripped again before
#   the choice is used as a path.
#
#   Runs the real script against a sandbox XDG_CONFIG_HOME: no session, no
#   compositor, no Hyprland.
# No `set -e`: the assertion helpers return non-zero on failure, and exiting on
# the first one would hide every later check in the run.
set -uo pipefail
HERE="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=./lib_test.sh
source "$HERE/lib_test.sh"

SCRIPT="$HERE/../Animations.sh"
WORK="$(mktemp -d)"; trap 'rm -rf -- "$WORK"' EXIT

CFG="$WORK/cfg"
BIN="$WORK/bin"
ANIM="$CFG/hypr/animations"
USERCFG="$CFG/hypr/UserConfigs"
TARGET="$USERCFG/user_animations.lua"
RECORD="$USERCFG/.current_animation"
ROWS_FILE="$WORK/rows.txt"
ROFI_LOG="$WORK/rofi.log"
NOTIFY_LOG="$WORK/notify.log"
export ROWS_FILE ROFI_LOG NOTIFY_LOG

mkdir -p "$ANIM" "$USERCFG" "$CFG/hypr/rofi" "$CFG/hypr/scripts" "$BIN"
: >"$CFG/hypr/rofi/config-Animations.rasi"
# The script backgrounds this at the end; a stub keeps the output clean.
printf '#!/usr/bin/env bash\nexit 0\n' >"$CFG/hypr/scripts/RefreshNoWaybar.sh"
chmod +x "$CFG/hypr/scripts/RefreshNoWaybar.sh"

# One plain preset and one whose name contains a space: the menu must neither
# split the name nor lose the marker on it.
printf 'hl.animation({ leaf = "windows", speed = 1 })\n' >"$ANIM/Alpha.lua"
printf 'hl.animation({ leaf = "windows", speed = 2 })\n' >"$ANIM/Beta preset.lua"

# Fake rofi: records the rows it was offered and the arguments it was given, and
# answers with FAKE_ROFI_TEXT when that is set - otherwise it exits as Escape
# does. No FAKE_ROFI_TEXT means "the user pressed Escape".
cat >"$BIN/rofi" <<'EOS'
#!/usr/bin/env bash
printf 'rofi %s\n' "$*" >>"$ROFI_LOG"
rows="$(cat)"
printf '%s\n' "$rows" >>"$ROWS_FILE"
if [[ -n ${FAKE_ROFI_TEXT+x} ]]; then printf '%s\n' "$FAKE_ROFI_TEXT"; exit 0; fi
exit 1
EOS

cat >"$BIN/notify-send" <<'EOS'
#!/usr/bin/env bash
printf 'notify-send %s\n' "$*" >>"$NOTIFY_LOG"
exit 0
EOS

cat >"$BIN/hyprctl" <<'EOS'
#!/usr/bin/env bash
exit 0
EOS

# The script kills a rofi that is already up. The fake must never reach the
# session's own rofi, so pidof always answers "not running".
cat >"$BIN/pidof" <<'EOS'
#!/usr/bin/env bash
exit 1
EOS
chmod +x "$BIN"/*

# run_menu [ENV=value...] - one menu run, logs cleared first.
run_menu() {
  : >"$ROWS_FILE"; : >"$ROFI_LOG"; : >"$NOTIFY_LOG"
  env PATH="$BIN:$PATH" XDG_CONFIG_HOME="$CFG" "$@" \
    timeout 30 bash "$SCRIPT" >"$WORK/out.txt" 2>&1
  return $?
}

# --- the loaded preset is an exact copy of a preset -------------------------
it "the loaded preset is marked and its row is pre-selected"
cp -- "$ANIM/Beta preset.lua" "$TARGET"
run_menu
assert_eq "the rows carry the marker on the loaded preset" \
  $'Alpha\n👉 Beta preset' "$(cat "$ROWS_FILE")"
assert_contains "$ROFI_LOG" '-selected-row 1' "the marked row is pre-selected"
assert_contains "$ROFI_LOG" 'Current: Beta preset' "the message line names it"

# --- choosing the marked row still applies the preset -----------------------
it "the marker is stripped before the choice is used as a path"
FAKE_ROFI_TEXT='👉 Beta preset' run_menu
assert_eq "the preset was copied" \
  "$(cat -- "$ANIM/Beta preset.lua")" "$(cat -- "$TARGET")"
assert_not_contains "$NOTIFY_LOG" 'not found' "the name was not used with the marker on"
assert_contains "$RECORD" 'Beta preset' "the choice was recorded"

# --- a file that matches no preset falls back to the recorded name ----------
it "a file that matches nothing is marked from the record"
printf 'hl.animation({ leaf = "windows", speed = 99 })\n' >"$TARGET"
printf 'Alpha\n' >"$RECORD"
run_menu
assert_eq "the recorded preset is marked" $'👉 Alpha\nBeta preset' "$(cat "$ROWS_FILE")"
assert_contains "$ROFI_LOG" 'Current: Alpha' "the message line names the record"

it "a record that names no preset marks nothing"
printf 'Gone\n' >"$RECORD"
run_menu
assert_not_contains "$ROWS_FILE" '👉' "no row was marked"
assert_contains "$ROFI_LOG" 'Current: custom' "the file is reported as custom"

# --- the placeholder, and no file at all ------------------------------------
it "the comment-only placeholder marks nothing and reads as default"
rm -f -- "$RECORD"
printf -- '-- User animation overrides template.\n' >"$TARGET"
run_menu
assert_not_contains "$ROWS_FILE" '👉' "no row was marked"
assert_contains "$ROFI_LOG" 'Current: default' "the shipped defaults are reported"

it "no user_animations.lua at all still opens the menu"
rm -f -- "$TARGET"
run_menu
assert_contains "$ROWS_FILE" 'Alpha' "the presets are still offered"
assert_contains "$ROFI_LOG" 'Current: default' "the shipped defaults are reported"

# --- Escape ----------------------------------------------------------------
it "Escape changes nothing and records nothing"
printf 'hl.animation({ leaf = "windows", speed = 2 })\n' >"$TARGET"
rm -f -- "$RECORD"
run_menu
assert_eq "the target is untouched" \
  'hl.animation({ leaf = "windows", speed = 2 })' "$(cat -- "$TARGET")"
if [[ -e "$RECORD" ]]; then fail "a record was written on Escape"; else pass_msg; fi

# --- a name that is not a preset is still refused ---------------------------
it "a typed name that is not a preset is refused"
FAKE_ROFI_TEXT='No Such Preset' run_menu
assert_contains "$NOTIFY_LOG" 'not found' "the user was told"
assert_eq "the target is untouched" \
  'hl.animation({ leaf = "windows", speed = 2 })' "$(cat -- "$TARGET")"

summary "test-animations-menu"
