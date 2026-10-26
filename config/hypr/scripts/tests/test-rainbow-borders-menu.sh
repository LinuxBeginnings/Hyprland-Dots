#!/usr/bin/env bash
# ==================================================
#  KoolDots (2026)
#  Project URL: https://github.com/LinuxBeginnings
#  License: GNU GPLv3
#  SPDX-License-Identifier: GPL-3.0-or-later
# ==================================================
# Purpose:
#   Tests for the indicator the Quick Settings Rainbow Borders menu puts on the
#   mode that is in effect, and for the marker being stripped again before the
#   choice is turned into a mode.
#
#   The menu lives inside Kool_Quick_Settings.sh, so this drives the real script
#   through the main menu and into the submenu against a sandbox XDG_CONFIG_HOME:
#   no session, no compositor, no Hyprland. The mode is read from the same state
#   the startup script reads, so what is asserted is what a user would see.
# No `set -e`: the assertion helpers return non-zero on failure, and exiting on
# the first one would hide every later check in the run.
set -uo pipefail
HERE="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=./lib_test.sh
source "$HERE/lib_test.sh"

SCRIPT="$HERE/../Kool_Quick_Settings.sh"
WORK="$(mktemp -d)"; trap 'rm -rf -- "$WORK"' EXIT

CFG="$WORK/cfg"
BIN="$WORK/bin"
USERSCRIPTS="$CFG/hypr/UserScripts"
MODE_FILE="$USERSCRIPTS/rainbow-borders.mode"
CLASSIC="$USERSCRIPTS/RainbowBorders.sh"
LOWCPU="$USERSCRIPTS/RainbowBorders-low-cpu.sh"
ROWS_FILE="$WORK/rows.txt"
ROFI_LOG="$WORK/rofi.log"
NOTIFY_LOG="$WORK/notify.log"
QUEUE="$WORK/queue.txt"
export ROWS_FILE ROFI_LOG NOTIFY_LOG QUEUE

mkdir -p "$USERSCRIPTS" "$CFG/hypr/rofi" "$CFG/hypr/scripts" "$CFG/hypr/UserConfigs" "$BIN"
: >"$CFG/hypr/rofi/config-edit.rasi"
# The menu backgrounds this after a choice; a stub keeps the output clean.
printf '#!/usr/bin/env bash\nexit 0\n' >"$CFG/hypr/scripts/Refresh.sh"
chmod +x "$CFG/hypr/scripts/Refresh.sh"

# The classic script carries the effect as a variable at the top. Both files are
# stubs: the menu only reads, moves and rewrites them.
make_classic() {
  cat >"$CLASSIC" <<'EOS'
#!/usr/bin/env bash
EFFECT_TYPE="gradient_flow"
exit 0
EOS
  chmod +x "$CLASSIC"
}
make_lowcpu() {
  printf '#!/usr/bin/env bash\nsleep 30\n' >"$LOWCPU"
  chmod +x "$LOWCPU"
}

# Fake rofi: records the rows and arguments of every call, and answers with the
# next line of QUEUE. A missing queue or the literal __ESCAPE__ exits as Escape
# does. The main menu is answered first, then the Rainbow Borders submenu.
cat >"$BIN/rofi" <<'EOS'
#!/usr/bin/env bash
printf 'rofi %s\n' "$*" >>"$ROFI_LOG"
rows="$(cat)"
printf '%s\n' "$rows" >>"$ROWS_FILE"
if [[ -s "$QUEUE" ]]; then
  next="$(head -n1 "$QUEUE")"
  tail -n +2 "$QUEUE" >"$QUEUE.rest" && mv "$QUEUE.rest" "$QUEUE"
  if [[ "$next" != "__ESCAPE__" ]]; then printf '%s\n' "$next"; exit 0; fi
fi
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
# session's own rofi, so pidof always answers "not running", and pgrep never
# finds a low-cpu loop belonging to the machine running the tests.
cat >"$BIN/pidof" <<'EOS'
#!/usr/bin/env bash
exit 1
EOS
cat >"$BIN/pgrep" <<'EOS'
#!/usr/bin/env bash
exit 1
EOS
chmod +x "$BIN"/*

# run_menu <submenu-answer|__ESCAPE__> - one run: main menu, then the submenu.
# Logs are cleared first so each case is judged on its own call.
run_menu() {
  : >"$ROWS_FILE"; : >"$ROFI_LOG"; : >"$NOTIFY_LOG"
  printf 'Rainbow Borders Mode\n%s\n' "$1" >"$QUEUE"
  env PATH="$BIN:$PATH" XDG_CONFIG_HOME="$CFG" RB_LOCKFILE="$WORK/rb.lock" \
    timeout 30 bash "$SCRIPT" >"$WORK/out.txt" 2>&1
  return $?
}

# --- the mode in the state file is the marked row ---------------------------
it "the recorded mode is marked and its row is pre-selected"
make_classic
printf 'wallust_random\n' >"$MODE_FILE"
run_menu __ESCAPE__
assert_contains "$ROWS_FILE" '👉 Wallust Color' "the active mode carries the marker"
assert_contains "$ROFI_LOG" '-selected-row 1' "the marked row is pre-selected"
assert_contains "$ROFI_LOG" 'current = Wallust Color' "the message line names it"

it "a disabled mode marks the Disable entry"
printf 'disabled\n' >"$MODE_FILE"
run_menu __ESCAPE__
assert_contains "$ROWS_FILE" '👉 Disable Rainbow Borders' "Disable carries the marker"
assert_contains "$ROFI_LOG" '-selected-row 0' "the first row is pre-selected"
assert_contains "$ROFI_LOG" 'current = Disabled' "the message line says disabled"

it "the low-cpu mode marks the low-cpu entry"
make_lowcpu
printf 'low_cpu\n' >"$MODE_FILE"
run_menu __ESCAPE__
assert_contains "$ROWS_FILE" '👉 Low CPU Rainbow' "the low-cpu entry carries the marker"
assert_contains "$ROFI_LOG" '-selected-row 4' "the marked row is pre-selected"

# --- a mode that only exists in the script, no state file yet ---------------
it "with no state file the effect in the script is marked"
make_classic
rm -f "$MODE_FILE"
run_menu __ESCAPE__
assert_contains "$ROWS_FILE" '👉 Gradient Flow' "the script effect carries the marker"
assert_contains "$ROFI_LOG" 'current = Gradient Flow' "the message line names it"

it "with no state file and no script, Disable is marked"
rm -f "$CLASSIC" "$LOWCPU"
run_menu __ESCAPE__
assert_contains "$ROWS_FILE" '👉 Disable Rainbow Borders' "Disable carries the marker"
assert_contains "$ROFI_LOG" 'current = Disabled' "the message line says disabled"

# --- choosing a different mode writes the mode and the effect ---------------
it "a different mode is recorded and written into the script"
make_classic
printf 'wallust_random\n' >"$MODE_FILE"
run_menu 'Gradient Flow'
assert_eq "the mode file was updated" 'gradient_flow' "$(cat "$MODE_FILE")"
assert_contains "$CLASSIC" 'EFFECT_TYPE="gradient_flow"' "the script effect was updated"

# --- choosing the marked row must not write the marker ----------------------
it "the marker is stripped before the choice is used as a mode"
make_classic
printf 'rainbow\n' >"$MODE_FILE"
run_menu '👉 Original Rainbow'
assert_eq "the mode file kept the bare name" 'rainbow' "$(cat "$MODE_FILE")"
assert_contains "$CLASSIC" 'EFFECT_TYPE="rainbow"' "the script effect kept the bare name"

# --- Escape ----------------------------------------------------------------
it "Escape changes nothing"
make_classic
printf 'rainbow\n' >"$MODE_FILE"
run_menu __ESCAPE__
assert_eq "the mode file is untouched" 'rainbow' "$(cat "$MODE_FILE")"
assert_contains "$CLASSIC" 'EFFECT_TYPE="gradient_flow"' "the script effect is untouched"

summary "test-rainbow-borders-menu"
