#!/usr/bin/env bash
# ==================================================
#  KoolDots (2026)
#  Project URL: https://github.com/LinuxBeginnings
#  License: GNU GPLv3
#  SPDX-License-Identifier: GPL-3.0-or-later
# ==================================================
# Purpose:
#   Tests for DisplayProfileSetup.sh, the grid parameter table. It is the only
#   way to express the things nwg-displays cannot (which monitor is primary,
#   which are off, where the bars go), and the only way to author a layout for
#   a state you are not currently in.
# No `set -e`: the assertion helpers return non-zero on failure, and exiting on
# the first one would hide every later check in the run.
set -uo pipefail

HERE="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=./lib_test.sh
source "$HERE/lib_test.sh"
source "$HERE/../lib_display_store.sh"

SCRIPT="$HERE/../DisplayProfileSetup.sh"
F="$HERE/fixtures"
WORK="$(mktemp -d)"; trap 'rm -rf -- "$WORK"' EXIT
BIN="$WORK/bin"; mkdir -p "$BIN" "$WORK/run"
PROFILE_LOG="$WORK/profile-calls.log"
ROFI_LOG="$WORK/rofi-calls.log"
ROWS_FILE="$WORK/rows.txt"
ROFI_SEQ_POS="$WORK/seq.pos"
export PROFILE_LOG ROFI_LOG ROWS_FILE ROFI_SEQ_POS

cat >"$BIN/DisplayProfile.sh" <<'EOS'
#!/usr/bin/env bash
printf '%s\n' "$*" >>"$PROFILE_LOG"
case "${1:-}" in monitors-json) printf '%s\n' "$FAKE_NORM" ;; esac
exit 0
EOS
chmod +x "$BIN/DisplayProfile.sh"

# Answers are a comma-separated sequence consumed one per rofi call, because
# the table is a loop of menus and each submenu is another call.
cat >"$BIN/rofi" <<'EOS'
#!/usr/bin/env bash
printf 'rofi %s\n' "$*" >>"$ROFI_LOG"
rows="$(cat)"
printf -- '--- rofi call\n%s\n' "$rows" >>"$ROWS_FILE"
if [[ -z $rows && -n ${FAKE_ROFI_TEXT+x} ]]; then
  n=0; [[ -f $ROFI_SEQ_POS.txt ]] && n="$(cat "$ROFI_SEQ_POS.txt")"
  IFS='|' read -r -a texts <<<"$FAKE_ROFI_TEXT"
  printf '%s\n' $(( n + 1 )) >"$ROFI_SEQ_POS.txt"
  if (( n < ${#texts[@]} )); then printf '%s\n' "${texts[$n]}"; exit 0; fi
  exit 1
fi
if [[ -n ${FAKE_ROFI_INDEX:-} ]]; then
  n=0; [[ -f $ROFI_SEQ_POS ]] && n="$(cat "$ROFI_SEQ_POS")"
  IFS=, read -r -a seq <<<"$FAKE_ROFI_INDEX"
  printf '%s\n' $(( n + 1 )) >"$ROFI_SEQ_POS"
  if (( n < ${#seq[@]} )); then printf '%s\n' "${seq[$n]}"; exit 0; fi
  exit 1
fi
exit 1
EOS
chmod +x "$BIN/rofi"

ds_normalize "$F/monitors-triple.json" >"$WORK/triple.json"
ds_normalize "$F/monitors-dual.json"   >"$WORK/dual.json"
FP_TRIPLE="$(ds_fingerprint "$WORK/triple.json")"
FP_DUAL="$(ds_fingerprint "$WORK/dual.json")"

# run_setup <norm-file> <store-file> [env...] [ARGS <script args...>]
# The ARGS sentinel matters: anything after `env`'s assignments is taken as the
# command to run, so script arguments cannot simply be appended.
run_setup() {
  local norm=$1 store=$2; shift 2
  cp "$store" "$WORK/store.json"
  : >"$PROFILE_LOG"; : >"$ROFI_LOG"; : >"$ROWS_FILE"
  rm -f "$ROFI_SEQ_POS" "$ROFI_SEQ_POS.txt"
  local -a envs=() args=()
  local seen=0 a
  for a in "$@"; do
    if [[ $seen -eq 0 && $a == ARGS ]]; then seen=1; continue; fi
    if [[ $seen -eq 1 ]]; then args+=("$a"); else envs+=("$a"); fi
  done
  env PATH="$BIN:$PATH" FAKE_NORM="$norm" \
      DPS_PROFILE_SCRIPT="$BIN/DisplayProfile.sh" \
      DPS_STORE_FILE="$WORK/store.json" \
      DPS_RUNTIME_DIR="$WORK/run" \
      DPS_ROFI_CONFIG="$WORK/none.rasi" \
      ${envs[@]+"${envs[@]}"} \
      timeout 30 bash "$SCRIPT" ${args[@]+"${args[@]}"} >"$WORK/out.txt" 2>&1
  return $?
}

rows_of_call() {  # nth rofi call (1-based) -> its rows
  awk -v want="$1" '/^--- rofi call$/ { n++; next } n == want { print }' "$ROWS_FILE"
}

# The first table for a three-monitor set, starting from a capture:
#   0,1,2 monitors (sorted by port: DP-1, DP-3, HDMI-A-1)
#   3 Primary, 4 Waybar, 5 Position (read-only), 6 Save & apply, 7 Cancel
it "the table lists one row per monitor plus the summary rows"
run_setup "$WORK/triple.json" "$F/store-empty.json" FAKE_ROFI_INDEX=7
first="$(rows_of_call 1)"
assert_contains "$ROWS_FILE" '(DP-1)'      "the first monitor is listed"
assert_contains "$ROWS_FILE" '(DP-3)'      "the second monitor is listed"
assert_contains "$ROWS_FILE" '(HDMI-A-1)'  "the third monitor is listed"
assert_contains "$ROWS_FILE" 'Primary'     "the primary row exists"
assert_contains "$ROWS_FILE" 'Waybar'      "the waybar row exists"
assert_contains "$ROWS_FILE" 'Position'    "the computed position row exists"
assert_contains "$ROWS_FILE" 'Save & apply' "the save row exists"
assert_contains "$ROWS_FILE" 'Cancel'      "the cancel row exists"
pass_msg

it "the monitor rows show mode, scale and grid placement"
assert_contains "$ROWS_FILE" '2560x1440@59.95' "the real mode is shown"
assert_contains "$ROWS_FILE" 'row 1'           "the grid row is shown"
pass_msg

it "the computed position row reflects the draft, not stored coordinates"
assert_contains "$ROWS_FILE" 'DP-1 0x0' "the first monitor sits at the origin" && pass_msg

it "Cancel writes nothing"
before="$(cat "$F/store-empty.json")"
run_setup "$WORK/triple.json" "$F/store-empty.json" FAKE_ROFI_INDEX=7
assert_eq "the store is untouched" "$before" "$(cat "$WORK/store.json")"
assert_not_contains "$PROFILE_LOG" 'capture' "nothing was saved"
pass_msg

it "Escape writes nothing either"
run_setup "$WORK/triple.json" "$F/store-empty.json"
assert_eq "the store is untouched" "$before" "$(cat "$WORK/store.json")"
pass_msg

# --- editing a monitor -----------------------------------------------------
# Monitor submenu rows: 0 On/Off, 1 Mode, 2 Scale, 3 Transform, 4 Row,
#                       5 Order, 6 Vertical alignment, 7 Back
it "turning a monitor off and saving stores it disabled and recomputes the rest"
run_setup "$WORK/triple.json" "$F/store-empty.json" \
  FAKE_ROFI_INDEX=0,0,6 FAKE_ROFI_TEXT='Solo'
n_off="$(jq -r --arg fp "$FP_TRIPLE" '[.fingerprints[$fp].layouts.Solo.monitors[] | select(.enabled == false)] | length' "$WORK/store.json" 2>/dev/null || echo none)"
if [[ $n_off == 1 ]]; then pass_msg; else fail "expected 1 disabled monitor, got '$n_off'"; fi
x_first="$(jq -r --arg fp "$FP_TRIPLE" '[.fingerprints[$fp].layouts.Solo.monitors[] | select(.enabled == true)] | .[0].x' "$WORK/store.json")"
assert_eq "the remaining monitors start at the origin" '0' "$x_first"

it "saving also applies the layout"
assert_contains "$PROFILE_LOG" '-- Solo' "the controller was asked to apply it" && pass_msg

it "changing a scale recomputes the neighbour's position"
# monitor 0 -> Scale -> 1.5 (index 3 in the scale list), then Save
run_setup "$WORK/triple.json" "$F/store-empty.json" \
  FAKE_ROFI_INDEX=0,2,3,6 FAKE_ROFI_TEXT='Scaled'
sc="$(jq -r --arg fp "$FP_TRIPLE" '.fingerprints[$fp].layouts.Scaled.monitors[0].scale' "$WORK/store.json")"
x2="$(jq -r --arg fp "$FP_TRIPLE" '.fingerprints[$fp].layouts.Scaled.monitors[1].x' "$WORK/store.json")"
if [[ $sc == "1.5" && $x2 == "1707" ]]; then pass_msg
else fail "scale=$sc, neighbour x=$x2 (expected 1.5 and 1707)"; fi

it "moving a monitor to row 2 stacks it below"
# monitor 2 -> Row -> 2 (index 1 in the row list), then Save
run_setup "$WORK/triple.json" "$F/store-empty.json" \
  FAKE_ROFI_INDEX=2,4,1,6 FAKE_ROFI_TEXT='Stacked'
y3="$(jq -r --arg fp "$FP_TRIPLE" '.fingerprints[$fp].layouts.Stacked.monitors[2].y' "$WORK/store.json")"
assert_eq "the second row starts below the tallest monitor of the first" '1440' "$y3"

it "the mode list offers only that monitor's own modes"
run_setup "$WORK/triple.json" "$F/store-empty.json" FAKE_ROFI_INDEX=0,1
modes="$(rows_of_call 3)"
assert_contains_str "its own mode is offered" "$modes" '2560x1440@59.95'
assert_not_contains_str "another monitor's mode is not offered" "$modes" '1920x1080@144.00'
pass_msg

it "the primary row offers the connected monitors"
run_setup "$WORK/triple.json" "$F/store-empty.json" FAKE_ROFI_INDEX=3,2,6 FAKE_ROFI_TEXT='Prim'
prim="$(jq -r --arg fp "$FP_TRIPLE" '.fingerprints[$fp].layouts.Prim.primary' "$WORK/store.json")"
assert_eq "the chosen monitor became primary" 'AOC|24G2|GHI789' "$prim"

it "the waybar row can restrict the bars to chosen monitors"
# Waybar -> "primary" (index 1), then Save
run_setup "$WORK/triple.json" "$F/store-empty.json" FAKE_ROFI_INDEX=4,1,6 FAKE_ROFI_TEXT='Bars'
mode="$(jq -r --arg fp "$FP_TRIPLE" '.fingerprints[$fp].layouts.Bars.waybar.mode' "$WORK/store.json")"
assert_eq "the waybar mode was stored" 'primary' "$mode"

# --- refusals --------------------------------------------------------------
it "an invalid name is refused and nothing is written"
run_setup "$WORK/triple.json" "$F/store-empty.json" FAKE_ROFI_INDEX=6 FAKE_ROFI_TEXT='bad/name'
assert_eq "the store is untouched" "$before" "$(cat "$WORK/store.json")"
assert_not_contains "$PROFILE_LOG" '--' "nothing was applied"
pass_msg

it "a layout that disables every monitor cannot be saved"
run_setup "$WORK/triple.json" "$F/store-empty.json" \
  FAKE_ROFI_INDEX=0,0,1,0,2,0,6 FAKE_ROFI_TEXT='Dark'
assert_eq "the store is untouched" "$before" "$(cat "$WORK/store.json")"
assert_contains "$WORK/out.txt" 'disabled' "the user was told why"
pass_msg

# --- editing an existing layout --------------------------------------------
# The dual monitor set has two monitor rows, so the fixed rows sit two places
# earlier than they do for the three-monitor set above: 2 Primary, 3 Waybar,
# 4 Position, 5 Save & apply, 6 Cancel.
it "an existing layout is loaded for editing rather than captured afresh"
run_setup "$WORK/dual.json" "$F/store-v1.json" FAKE_ROFI_INDEX=6 ARGS -- Home
assert_contains "$ROWS_FILE" 'x1.5' "the stored scale is shown, not the live one" && pass_msg

it "saving an edited layout keeps its name without asking again"
run_setup "$WORK/dual.json" "$F/store-v1.json" FAKE_ROFI_INDEX=5 ARGS -- Home
assert_contains "$PROFILE_LOG" '-- Home' "it applied the same layout" && pass_msg

# --- structural ------------------------------------------------------------
it "no eval anywhere in the table"
if sed 's/#.*$//' "$SCRIPT" | grep -qE '\beval\b'; then fail "eval found"; else pass_msg; fi

it "no port name is hardcoded in the table"
if sed 's/#.*$//' "$SCRIPT" | grep -qE '\b(eDP|LVDS|DSI|DP|HDMI-A|DVI-D)-[0-9]+'; then
  fail "hardcoded: $(sed 's/#.*$//' "$SCRIPT" | grep -nE '\b(eDP|LVDS|DSI|DP|HDMI-A|DVI-D)-[0-9]+' | head -1)"
else pass_msg; fi

it "rofi is asked for an index, not for the line text"
assert_contains "$ROFI_LOG" '-format i' "rofi -format i" && pass_msg

# --- refusals name the real reason -----------------------------------------
it "the table reports the validator's own reason, not just 'disabled'"
# A live scale of zero is refused by the validator. The old code always said
# "every monitor is disabled", which is simply wrong here and left the user with
# no way to find out which value the table was unhappy about.
jq -c '[ .[] | if .name == "DP-2" then .scale = 0 else . end ]' \
  "$F/monitors-dual.json" >"$WORK/zero-src.json"
ds_normalize "$WORK/zero-src.json" >"$WORK/zero.json"
before_zero="$(cat "$F/store-empty.json")"
run_setup "$WORK/zero.json" "$F/store-empty.json" FAKE_ROFI_INDEX=5 FAKE_ROFI_TEXT='Zero'
assert_contains "$WORK/out.txt" 'scale' "the reason names the offending value"
assert_eq "the store is untouched" "$before_zero" "$(cat "$WORK/store.json")"

summary "test-display-profile-setup"
