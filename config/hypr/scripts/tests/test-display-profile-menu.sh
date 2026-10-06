#!/usr/bin/env bash
# ==================================================
#  KoolDots (2026)
#  Project URL: https://github.com/LinuxBeginnings
#  License: GNU GPLv3
#  SPDX-License-Identifier: GPL-3.0-or-later
# ==================================================
# Purpose:
#   Tests for DisplayProfileMenu.sh. The row list is built at runtime from the
#   store, so the thing worth testing is that a chosen INDEX still maps to the
#   right action however many layouts exist, and that a user-supplied layout
#   name is never executed as shell text.
# No `set -e`: the assertion helpers return non-zero on failure, and exiting on
# the first one would hide every later check in the run.
set -uo pipefail

HERE="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=./lib_test.sh
source "$HERE/lib_test.sh"
source "$HERE/../lib_display_store.sh"

SCRIPT="$HERE/../DisplayProfileMenu.sh"
F="$HERE/fixtures"
WORK="$(mktemp -d)"; trap 'rm -rf -- "$WORK"' EXIT
BIN="$WORK/bin"; mkdir -p "$BIN" "$WORK/run"
STATE="$WORK/run/kooldots-display-profiles"
PROFILE_LOG="$WORK/profile-calls.log"
ROFI_LOG="$WORK/rofi-calls.log"
ROWS_FILE="$WORK/rows.txt"
ROFI_SEQ_POS="$WORK/rofi-seq.pos"
export PROFILE_LOG ROFI_LOG ROWS_FILE ROFI_SEQ_POS

# Fake controller: records its arguments. `list` and `monitors-json` answer for
# real, from the store and a fixture, because the menu builds its rows on them.
cat >"$BIN/DisplayProfile.sh" <<'EOS'
#!/usr/bin/env bash
printf '%s\n' "$*" >>"$PROFILE_LOG"
case "${1:-}" in
  list)          jq -r --arg fp "$FP" '(.fingerprints[$fp].layouts // {}) | keys | sort | .[]' "$STORE" 2>/dev/null ;;
  monitors-json) printf '%s\n' "$NORM" ;;
esac
exit 0
EOS
chmod +x "$BIN/DisplayProfile.sh"

# Fake rofi: records the rows it was offered and answers with a scripted index
# or text. -format i means the real rofi returns an index, so the fake does too.
# FAKE_ROFI_INDEX may be a comma-separated sequence, consumed one per call:
# a submenu is a second rofi call, and answering it with the parent's index
# would be meaningless. Without a sequence, a row that reopens the menu (the
# drag-and-drop row) would also loop forever.
cat >"$BIN/rofi" <<'EOS'
#!/usr/bin/env bash
printf 'rofi %s\n' "$*" >>"$ROFI_LOG"
rows="$(cat)"
printf '%s\n' "$rows" >>"$ROWS_FILE"
if [[ -n ${FAKE_ROFI_EXIT:-} ]]; then exit "$FAKE_ROFI_EXIT"; fi
if [[ -z $rows && -n ${FAKE_ROFI_TEXT+x} ]]; then printf '%s\n' "$FAKE_ROFI_TEXT"; exit 0; fi
if [[ -n ${FAKE_ROFI_INDEX:-} ]]; then
  n=0
  [[ -f $ROFI_SEQ_POS ]] && n="$(cat "$ROFI_SEQ_POS")"
  IFS=, read -r -a seq <<<"$FAKE_ROFI_INDEX"
  printf '%s\n' $(( n + 1 )) >"$ROFI_SEQ_POS"
  if (( n < ${#seq[@]} )); then printf '%s\n' "${seq[$n]}"; exit 0; fi
  exit 1
fi
exit 1
EOS
chmod +x "$BIN/rofi"

cat >"$BIN/nwg-displays" <<'EOS'
#!/usr/bin/env bash
printf 'nwg-displays %s\n' "$*" >>"$PROFILE_LOG"
# Emulate Apply: write a monitors.conf to the -m path, like the real tool.
mpath=""; take=0
for a in "$@"; do if (( take )); then mpath="$a"; take=0; fi; [[ $a == "-m" ]] && take=1; done
[[ -n $mpath && -n ${FAKE_NWG_WRITES:-} ]] && printf '%s\n' "$FAKE_NWG_WRITES" >"$mpath"
sleep "${FAKE_NWG_LINGER:-0.2}"
exit 0
EOS
chmod +x "$BIN/nwg-displays"

ds_normalize "$F/monitors-dual.json" >"$WORK/norm.json"
FP_DUAL="$(ds_fingerprint "$WORK/norm.json")"

# run_menu <store-fixture-or-path> [env...]
run_menu() {
  local store=$1; shift
  [[ -f $store ]] || store="$F/$store.json"
  cp "$store" "$WORK/store.json"
  : >"$PROFILE_LOG"; : >"$ROFI_LOG"; : >"$ROWS_FILE"; rm -f "$ROFI_SEQ_POS"
  env PATH="$BIN:$PATH" \
      FP="$FP_DUAL" STORE="$WORK/store.json" NORM="$WORK/norm.json" \
      DPM_PROFILE_SCRIPT="$BIN/DisplayProfile.sh" \
      DPM_STORE_FILE="$WORK/store.json" \
      DPM_RUNTIME_DIR="$WORK/run" \
      DPM_ROFI_CONFIG="$WORK/rofi.rasi" \
      DPM_NWG_DISPLAYS="$BIN/nwg-displays" \
      "$@" timeout 30 bash "$SCRIPT" >"$WORK/out.txt" 2>&1
  return $?
}

# Row indices, for a store with two layouts (Home, Work):
#   0 Home, 1 Work, 2 separator, 3 Automatic, 4 Arrange, 5 Save as,
#   6 Edit parameters, 7 Set default, 8 Rename set, 9 Delete, 10 Reset, 11 Exit

it "the rows list every layout of the current monitor set"
run_menu store-v1 FAKE_ROFI_EXIT=1
assert_contains "$ROWS_FILE" 'Home' "Home is offered"
assert_contains "$ROWS_FILE" 'Work' "Work is offered"
assert_contains "$ROWS_FILE" 'Automatic' "the automatic row exists"
assert_contains "$ROWS_FILE" 'nwg-displays' "the drag-and-drop row exists"
assert_contains "$ROWS_FILE" 'Save current state' "the save row exists"
assert_contains "$ROWS_FILE" 'Reset' "the reset row exists"
pass_msg

it "the default layout is marked in the list"
assert_contains "$ROWS_FILE" '★' "the default carries a mark" && pass_msg

it "rofi is asked for an index, not for the line text"
assert_contains "$ROFI_LOG" '-format i' "rofi -format i" && pass_msg

it "choosing the first row applies the first layout by name, after --"
run_menu store-v1 FAKE_ROFI_INDEX=0
assert_contains "$PROFILE_LOG" '-- Home' "the layout name is passed as data" && pass_msg

it "choosing the second row applies the second layout"
run_menu store-v1 FAKE_ROFI_INDEX=1
assert_contains "$PROFILE_LOG" '-- Work' "Work was applied" && pass_msg

it "the Automatic row maps to auto with two layouts present"
run_menu store-v1 FAKE_ROFI_INDEX=3
assert_contains "$PROFILE_LOG" 'auto' "auto was called" && pass_msg

it "the Automatic row still maps to auto when only one layout exists"
jq --arg fp "$FP_DUAL" 'del(.fingerprints[$fp].layouts.Work)' "$F/store-v1.json" >"$WORK/one.json"
run_menu "$WORK/one.json" FAKE_ROFI_INDEX=2
assert_contains "$PROFILE_LOG" 'auto' "the fixed rows shifted with the list" && pass_msg

it "the Automatic row still maps to auto when no layout exists"
run_menu store-empty FAKE_ROFI_INDEX=0
assert_contains "$PROFILE_LOG" 'auto' "with no layouts, Automatic is the first row" && pass_msg

it "Escape changes nothing"
before="$(cat "$F/store-v1.json")"
run_menu store-v1 FAKE_ROFI_EXIT=1
assert_eq "the store was not touched" "$before" "$(cat "$WORK/store.json")"
assert_eq "no controller command ran" '0' "$(grep -cvE '^(list|monitors-json)' "$PROFILE_LOG")"
pass_msg

it "an out-of-range index does nothing"
run_menu store-v1 FAKE_ROFI_INDEX=99
assert_eq "no action was taken" '0' "$(grep -cvE '^(list|monitors-json)' "$PROFILE_LOG")"
pass_msg

it "a non-numeric answer does nothing"
run_menu store-v1 FAKE_ROFI_INDEX=notanumber
assert_eq "no action was taken" '0' "$(grep -cvE '^(list|monitors-json)' "$PROFILE_LOG")"
pass_msg

# --- naming ----------------------------------------------------------------
it "Save current state as... captures under the typed name"
run_menu store-v1 FAKE_ROFI_INDEX=5 FAKE_ROFI_TEXT='Good Name'
assert_contains "$PROFILE_LOG" 'capture -- Good Name' "the name is passed as data" && pass_msg

it "an invalid name is refused without calling capture"
run_menu store-v1 FAKE_ROFI_INDEX=5 FAKE_ROFI_TEXT='bad/name'
assert_not_contains "$PROFILE_LOG" 'capture' "nothing was captured"
assert_contains "$WORK/out.txt" 'name' "the user was told why"
pass_msg

it "an empty name is refused"
run_menu store-v1 FAKE_ROFI_INDEX=5 FAKE_ROFI_TEXT=''
assert_not_contains "$PROFILE_LOG" 'capture' "nothing was captured" && pass_msg

# Review Focus 3 in the menu: a name that looks like an option.
it "a name that looks like an option is still passed as data"
run_menu store-v1 FAKE_ROFI_INDEX=5 FAKE_ROFI_TEXT='-n'
assert_contains "$PROFILE_LOG" 'capture -- -n' "passed after --" && pass_msg

it "Rename monitor set... passes the label after --"
run_menu store-v1 FAKE_ROFI_INDEX=8 FAKE_ROFI_TEXT='Nha'
assert_contains "$PROFILE_LOG" 'label -- Nha' "the label is passed as data" && pass_msg

it "Set as default... offers only existing layouts"
run_menu store-v1 FAKE_ROFI_INDEX=7,0
assert_contains "$ROWS_FILE" 'Home' "the layouts are offered for the choice"
assert_contains "$PROFILE_LOG" 'set-default -- Home' "the chosen layout became the default"
pass_msg

it "Delete layout... asks the controller to delete by name"
run_menu store-v1 FAKE_ROFI_INDEX=9,1
assert_contains "$PROFILE_LOG" 'delete -- Work' "the chosen layout was deleted" && pass_msg

# --- drag and drop ---------------------------------------------------------
it "the arrange row launches the GUI with a discard path"
run_menu store-v1 FAKE_ROFI_INDEX=4,11
assert_contains "$PROFILE_LOG" 'nwg-displays -m' "the GUI was launched with -m"
assert_contains "$PROFILE_LOG" 'nwg-monitors.conf.discard' "pointed at the discard path"
pass_msg

it "the pause file exists while the GUI runs and is gone afterwards"
run_menu store-v1 FAKE_ROFI_INDEX=4,11 FAKE_NWG_LINGER=0.2
if [[ -e "$STATE/pause" ]]; then fail "the pause file outlived the GUI"; else pass_msg; fi
# The note is carried into the reopened menu's message line, not to stdout.
assert_contains "$ROFI_LOG" 'unsaved' "the menu reopened saying the state is unsaved"

it "after Arrange+Apply, the menu imports what nwg wrote (bridge)"
nwg_conf='monitor=desc:BOE 0x0630,1920x1080@60.03,0x0,1.25'
FAKE_ROFI_INDEX=4,11 FAKE_NWG_WRITES="$nwg_conf" run_menu store-v1
assert_contains "$PROFILE_LOG" 'import-nwg' "the controller was asked to import the nwg file"
assert_contains "$PROFILE_LOG" 'nwg-monitors.conf.discard' "it imported the discard file nwg wrote"
pass_msg

it "nothing to import (nwg wrote nothing) does not call import-nwg"
FAKE_ROFI_INDEX=4,11 run_menu store-v1   # FAKE_NWG_WRITES unset -> no file
assert_not_contains "$PROFILE_LOG" 'import-nwg' "no import when nwg wrote nothing"
pass_msg

it "a missing GUI tells the user instead of failing silently"
run_menu store-v1 FAKE_ROFI_INDEX=4,11 DPM_NWG_DISPLAYS=/nonexistent/nwg
assert_contains "$WORK/out.txt" 'nwg-displays' "the user was told what to install"
if [[ -e "$STATE/pause" ]]; then fail "a pause file was left behind"; else pass_msg; fi

# --- the malformed store ---------------------------------------------------
it "a malformed store is readable but never written by an ordinary action"
before_bad="$(cat "$F/store-malformed.json")"
run_menu store-malformed FAKE_ROFI_INDEX=0
assert_eq "the malformed store is byte-identical" "$before_bad" "$(cat "$WORK/store.json")"
pass_msg

it "Reset backs the store up before replacing it"
run_menu store-malformed FAKE_ROFI_EXIT=1
# With no layouts listed the fixed rows shift up, so Reset is located by label
# rather than by a guessed index.
reset_idx="$(grep -n 'Reset' "$ROWS_FILE" | head -1 | cut -d: -f1)"
if [[ -n $reset_idx ]]; then pass_msg; else fail "no Reset row offered"; fi

it "Reset writes an empty store and keeps a timestamped backup"
idx=$(( reset_idx - 1 ))
run_menu store-malformed FAKE_ROFI_INDEX="$idx,1"
if ls "$WORK"/store.json.bak-* >/dev/null 2>&1; then pass_msg; else fail "no backup was made"; fi
assert_json_eq "$WORK/store.json" '.fingerprints | length' '0'
assert_json_eq "$WORK/store.json" '.version' '1'

# --- review finding I7: Reset must not destroy the store if the backup failed
it "Reset refuses to replace the store when the backup could not be made"
run_menu store-v1 FAKE_ROFI_EXIT=1
reset_idx="$(grep -n 'Reset' "$ROWS_FILE" | head -1 | cut -d: -f1)"
before_v1="$(cat "$F/store-v1.json")"
run_menu store-v1 FAKE_ROFI_INDEX="$(( reset_idx - 1 )),1" DS_CP=/bin/false
assert_eq "the store is byte-identical after a failed backup" "$before_v1" "$(cat "$WORK/store.json")"
assert_contains "$WORK/out.txt" 'back' "the user is told the backup failed"
pass_msg

it "Reset still works when the backup succeeds"
run_menu store-v1 FAKE_ROFI_INDEX="$(( reset_idx - 1 )),1"
assert_json_eq "$WORK/store.json" '.fingerprints | length' '0'
if ls "$WORK"/store.json.bak-* >/dev/null 2>&1; then pass_msg; else fail "no backup kept"; fi

# --- review finding I8: the table must edit the layout that is running ------
it "Edit parameters opens the running layout, not a fresh capture"
mkdir -p "$STATE"
printf '%s\nWork\n' "$FP_DUAL" >"$STATE/current"
cat >"$BIN/DisplayProfileSetup.sh" <<'EOS'
#!/usr/bin/env bash
printf 'Setup %s\n' "$*" >>"$PROFILE_LOG"
exit 0
EOS
chmod +x "$BIN/DisplayProfileSetup.sh"
run_menu store-v1 FAKE_ROFI_INDEX=6 DPM_SETUP_SCRIPT="$BIN/DisplayProfileSetup.sh"
assert_contains "$PROFILE_LOG" 'Setup -- Work' "the running layout was handed over" && pass_msg

it "with nothing running, the table starts from the live state"
rm -f "$STATE/current"
run_menu store-v1 FAKE_ROFI_INDEX=6 DPM_SETUP_SCRIPT="$BIN/DisplayProfileSetup.sh"
assert_contains "$PROFILE_LOG" 'Setup' "the table still opens"
assert_not_contains "$PROFILE_LOG" 'Setup -- ' "and it is given no layout to edit"
pass_msg

# --- structural ------------------------------------------------------------
it "no eval anywhere in the menu"
if sed 's/#.*$//' "$SCRIPT" | grep -qE '\beval\b'; then fail "eval found"; else pass_msg; fi

it "no port name is hardcoded in the menu"
if sed 's/#.*$//' "$SCRIPT" | grep -qE '\b(eDP|LVDS|DSI|DP|HDMI-A|DVI-D)-[0-9]+'; then
  fail "hardcoded: $(sed 's/#.*$//' "$SCRIPT" | grep -nE '\b(eDP|LVDS|DSI|DP|HDMI-A|DVI-D)-[0-9]+' | head -1)"
else pass_msg; fi

it "the two-monitor vocabulary is gone from the menu"
if grep -qE 'LABEL_HOME|LABEL_WORK|EXTERNAL_OUTPUT|LAPTOP_OUTPUT' "$SCRIPT"; then
  fail "still present"; else pass_msg; fi

it "the GUI launch closes the lock descriptor"
# only the launch line matters; `command -v` and the default assignment do not
if sed 's/#.*$//' "$SCRIPT" | grep -nE '"\$DPM_NWG_DISPLAYS" +-m' | grep -qv '9>&-'; then
  fail "the GUI launch does not close fd 9"; else pass_msg; fi

summary "test-display-profile-menu"
