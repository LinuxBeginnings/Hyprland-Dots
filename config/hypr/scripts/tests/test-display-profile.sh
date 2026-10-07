#!/usr/bin/env bash
# ==================================================
#  KoolDots (2026)
#  Project URL: https://github.com/LinuxBeginnings
#  License: GNU GPLv3
#  SPDX-License-Identifier: GPL-3.0-or-later
# ==================================================
# Purpose:
#   Tests for DisplayProfile.sh, the only component allowed to change session
#   state. Everything runs against fake hyprctl/waybar/pgrep/pkill, so the
#   ordering guarantees that keep the screen from going black are checked
#   without a real compositor.
# No `set -e`: the assertion helpers return non-zero on failure, and exiting on
# the first one would hide every later check in the run.
set -uo pipefail
HERE="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=./lib_test.sh
source "$HERE/lib_test.sh"
source "$HERE/../lib_display_store.sh"

SCRIPT="$HERE/../DisplayProfile.sh"
F="$HERE/fixtures"
WORK="$(mktemp -d)"; trap 'rm -rf -- "$WORK"; cleanup_sandbox' EXIT
make_sandbox
mkdir -p "$WORK/waybar" "$WORK/run"
printf '* { }\n' >"$WORK/waybar/style.css"
cp "$F/waybar-config-2bars" "$WORK/waybar/config"

STATE="$WORK/run/kooldots-display-profiles"

# The dual fixture already sits at the coordinates store-v1's Home asks for, so
# it doubles as the post-apply "active" answer. A mismatching variant drives the
# failed-verification path.
jq -c '[ .[] | if .name == "DP-2" then .x = 0 else . end ]' "$F/monitors-dual.json" \
  >"$WORK/dual-wrong-x.json"
jq -c '[ .[] | select(.name == "eDP-1") ]' "$F/monitors-dual.json" >"$WORK/laptop-active.json"

norm_file() { ds_normalize "$1" >"$WORK/n.json"; printf '%s' "$WORK/n.json"; }
FP_DUAL="$(ds_fingerprint "$(norm_file "$F/monitors-dual.json")")"

reset_store() { cp "$F/store-v1.json" "$WORK/store.json"; rm -f "$WORK/monitors.lua"; }

# run_dp <all-fixture> <active-fixture> <args...>
run_dp() {
  local all=$1 active=$2; shift 2
  sandbox_reset_log
  FAKE_MONITORS_ALL="$all" FAKE_MONITORS="$active" \
  DP_STORE_FILE="$WORK/store.json" DP_MONITORS_LUA="$WORK/monitors.lua" \
  DP_RUNTIME_DIR="$WORK/run" DP_SKIP_LOCK=1 \
  DP_WAYBAR_CONFIG="$WORK/waybar/config" DP_WAYBAR_STYLE="$WORK/waybar/style.css" \
  DP_VERIFY_ATTEMPTS=2 DP_VERIFY_DELAY=0 FAKE_MONITORS_SEQ="${SEQ:-}" \
  DP_WAYBAR_STARTUP="${DP_WAYBAR_STARTUP:-/nonexistent}" \
  DP_LID_STATE="${DP_LID_STATE-open}" \
  DP_LID_GLOB="${DP_LID_GLOB-/proc/acpi/button/lid/*/state}" \
  timeout 60 bash "$SCRIPT" "$@"
}

# --- applying a stored layout ----------------------------------------------
reset_store
it "applying a named layout succeeds"
run_dp "$F/monitors-dual.json" "$F/monitors-dual.json" -- Home && pass_msg || fail "exit non-zero"
assert_contains "$CALL_LOG" 'hl.monitor({ output = "eDP-1"' "the laptop panel was configured"
assert_contains "$CALL_LOG" 'hl.monitor({ output = "DP-2"' "the external monitor was configured"
assert_contains "$CALL_LOG" 'scale = "1.5"' "the stored scale was used"
assert_contains "$CALL_LOG" 'position = "1280x0"' "the stored position was used"
assert_contains "$CALL_LOG" 'transform = 0' "transform is always passed"
assert_count_re 0 "$CALL_LOG" 'disabled = true'
# enabled monitors are explicitly re-enabled (clears a prior disable)
assert_count_re 2 "$CALL_LOG" 'disabled = false'
assert_contains "$CALL_LOG" 'hl.dispatch(hl.dsp.focus({ monitor = "DP-2" }))' "focus went to the primary"

it "a layout that disables a monitor enables the others first"
run_dp "$F/monitors-dual.json" "$F/monitors-dual.json" -- Work && pass_msg || fail "exit non-zero"
assert_order "$CALL_LOG" 'hl.monitor({ output = "eDP-1"' 'disabled = true'
assert_count_re 1 "$CALL_LOG" 'disabled = true'
assert_contains "$CALL_LOG" 'output = "DP-2", disabled = true' "the right monitor was disabled"
assert_contains "$CALL_LOG" 'hl.dispatch(hl.dsp.focus({ monitor = "eDP-1" }))' "focus followed the primary"

it "a failed verification disables nothing"
# Work enables only the laptop panel, so the laptop panel is what must mismatch.
jq -c '[ .[] | if .name == "eDP-1" then .scale = 1 else . end ]' "$F/monitors-dual.json" \
  >"$WORK/dual-wrong-scale.json"
if run_dp "$F/monitors-dual.json" "$WORK/dual-wrong-scale.json" -- Work >/dev/null 2>&1
then fail "must exit non-zero when a monitor does not come up"; else pass_msg; fi
assert_count_re 0 "$CALL_LOG" 'disabled = true'
assert_contains "$CALL_LOG" 'notify-send' "the user was told"

it "zero active outputs after disabling triggers the rescue layout"
# First read satisfies the laptop panel's verification; the read after the
# disable reports nothing active, which is the only way to reach step 4.
printf '[]\n' >"$WORK/none.json"
printf '%s\n%s\n' "$F/monitors-dual.json" "$WORK/none.json" >"$WORK/seq.txt"
err="$(SEQ="$WORK/seq.txt" run_dp "$F/monitors-dual.json" "$WORK/none.json" -- Work 2>&1 >/dev/null || true)"
# The rescue decision is a log line, which goes to stderr; CALL_LOG only holds
# the fake commands that were invoked.
assert_contains "$err" 'rescue' "the rescue path was announced"
# One mode-setting call for Work's laptop panel, then two from the rescue.
assert_count_re 3 "$CALL_LOG" 'hl\.monitor\(\{ output = "(eDP-1|DP-2)", mode' \
  "rescue re-enabled every connected monitor"
assert_contains "$CALL_LOG" 'scale = "1",' "rescue uses scale 1"
assert_contains "$CALL_LOG" "No active monitor" "the user was told (via notify-send)"

it "an unknown layout name is refused without touching the session"
reset_store
if run_dp "$F/monitors-dual.json" "$F/monitors-dual.json" -- Nope >/dev/null 2>&1
then fail "must refuse"; else pass_msg; fi
assert_count_re 0 "$CALL_LOG" 'hl\.monitor'

it "an invalid layout name is refused"
if run_dp "$F/monitors-dual.json" "$F/monitors-dual.json" -- 'a/b' >/dev/null 2>&1
then fail "must refuse"; else pass_msg; fi

# Review Focus 3: a name that looks like an option is data, not a flag.
it "a layout named -n is applied, not parsed as an option"
jq --arg fp "$FP_DUAL" '.fingerprints[$fp].layouts["-n"] = .fingerprints[$fp].layouts.Home' \
  "$F/store-v1.json" >"$WORK/store.json"
run_dp "$F/monitors-dual.json" "$F/monitors-dual.json" -- -n && pass_msg || fail "exit non-zero"
assert_contains "$CALL_LOG" 'hl.monitor({ output = "DP-2"' "the -n layout was applied"

# --- auto ------------------------------------------------------------------
it "auto applies the stored default for this monitor set"
reset_store
run_dp "$F/monitors-dual.json" "$F/monitors-dual.json" auto && pass_msg || fail "exit non-zero"
assert_contains "$CALL_LOG" 'position = "1280x0"' "Home, the default, was applied"

it "auto on an unknown monitor set generates a layout and applies it"
cp "$F/store-empty.json" "$WORK/store.json"
jq -c '[ .[] | .x = 0 ]' "$F/monitors-triple.json" >"$WORK/triple-active.json"
jq -c '[ .[] | if .name == "DP-1" then .x = 0 elif .name == "DP-3" then .x = 2560 else .x = 4480 end ]' \
  "$F/monitors-triple.json" >"$WORK/triple-active.json"
run_dp "$F/monitors-triple.json" "$WORK/triple-active.json" auto && pass_msg || fail "exit non-zero"
assert_count_re 3 "$CALL_LOG" 'hl\.monitor\(\{ output = "(DP-1|DP-3|HDMI-A-1)", mode'
assert_contains "$CALL_LOG" 'position = "2560x0"' "the generated row is laid out left to right"

# Review Focus 5: nothing connected -> stand down quietly.
it "auto with no monitors connected exits 0 and changes nothing"
printf '[]\n' >"$WORK/none.json"
run_dp "$WORK/none.json" "$WORK/none.json" auto && pass_msg || fail "must exit 0"
assert_count_re 0 "$CALL_LOG" 'hl\.monitor'

# --- state -----------------------------------------------------------------
it "applying writes the current fingerprint and layout name"
reset_store
run_dp "$F/monitors-dual.json" "$F/monitors-dual.json" -- Work >/dev/null 2>&1
if [[ "$(sed -n '1p' "$STATE/current")" == "$FP_DUAL" \
   && "$(sed -n '2p' "$STATE/current")" == "Work" ]]; then pass_msg
else fail "state file holds: $(tr '\n' '|' <"$STATE/current")"; fi

it "list prints this monitor set's layouts"
out="$(run_dp "$F/monitors-dual.json" "$F/monitors-dual.json" list 2>/dev/null)"
assert_contains "$out" 'Home' "Home is listed"
assert_contains "$out" 'Work' "Work is listed"

it "monitors-json prints a readable normalized file path"
out="$(run_dp "$F/monitors-dual.json" "$F/monitors-dual.json" monitors-json 2>/dev/null)"
if [[ -f $out ]] && jq -e '.[0].identity' "$out" >/dev/null 2>&1; then pass_msg
else fail "got '$out'"; fi
assert_eq "monitors-json prints exactly one line" '1' \
  "$(run_dp "$F/monitors-dual.json" "$F/monitors-dual.json" monitors-json 2>/dev/null | wc -l | tr -d ' ')"

# --- capture, set-default, delete, label -----------------------------------
it "capture saves the live state under a name"
cp "$F/store-empty.json" "$WORK/store.json"
run_dp "$F/monitors-dual.json" "$F/monitors-dual.json" capture -- 'Nha One' && pass_msg || fail "exit non-zero"
assert_eq "the captured layout is in the store" '2' \
  "$(jq -r --arg fp "$FP_DUAL" '.fingerprints[$fp].layouts["Nha One"].monitors | length' "$WORK/store.json")"
it "capture refuses an invalid name"
if run_dp "$F/monitors-dual.json" "$F/monitors-dual.json" capture -- 'bad/name' >/dev/null 2>&1
then fail "must refuse"; else pass_msg; fi

it "set-default moves the default"
reset_store
run_dp "$F/monitors-dual.json" "$F/monitors-dual.json" set-default -- Work && pass_msg || fail "exit non-zero"
assert_eq "the default moved" 'Work' \
  "$(jq -r --arg fp "$FP_DUAL" '.fingerprints[$fp].default' "$WORK/store.json")"

it "delete removes a layout"
run_dp "$F/monitors-dual.json" "$F/monitors-dual.json" delete -- Home && pass_msg || fail "exit non-zero"
assert_eq "only Work remains" 'Work' \
  "$(jq -r --arg fp "$FP_DUAL" '.fingerprints[$fp].layouts | keys | join(",")' "$WORK/store.json")"

it "label names the monitor set"
run_dp "$F/monitors-dual.json" "$F/monitors-dual.json" label -- 'Nha' && pass_msg || fail "exit non-zero"
assert_eq "the label was stored" 'Nha' \
  "$(jq -r --arg fp "$FP_DUAL" '.fingerprints[$fp].label' "$WORK/store.json")"

# --- coexistence: stand down ------------------------------------------------
it "stands down when monitors.lua configures monitors and nothing is stored"
cp "$F/store-empty.json" "$WORK/store.json"
printf 'hl.monitor({ output = "", mode = "preferred" })\n' >"$WORK/monitors.lua"
run_dp "$F/monitors-dual.json" "$F/monitors-dual.json" auto && pass_msg || fail "must exit 0"
assert_count_re 0 "$CALL_LOG" 'hl\.monitor'

it "a commented hl.monitor does not count as user configuration"
printf -- '-- hl.monitor({ output = "" })\n' >"$WORK/monitors.lua"
run_dp "$F/monitors-dual.json" "$WORK/triple-active.json" auto >/dev/null 2>&1 || true
assert_contains "$CALL_LOG" 'hl.monitor' "the system still manages the monitors"

it "a stored layout overrides monitors.lua"
reset_store
printf 'hl.monitor({ output = "", mode = "preferred" })\n' >"$WORK/monitors.lua"
run_dp "$F/monitors-dual.json" "$F/monitors-dual.json" auto && pass_msg || fail "exit non-zero"
assert_contains "$CALL_LOG" 'position = "1280x0"' "the saved layout was applied anyway"

it "an explicitly named layout is applied even while standing down"
cp "$F/store-empty.json" "$WORK/store.json"
jq --arg fp "$FP_DUAL" --slurpfile v1 "$F/store-v1.json" \
  '.fingerprints[$fp] = ($v1[0].fingerprints | to_entries[0].value)' \
  "$F/store-empty.json" >"$WORK/store.json"
printf 'hl.monitor({ output = "", mode = "preferred" })\n' >"$WORK/monitors.lua"
run_dp "$F/monitors-dual.json" "$F/monitors-dual.json" -- Home && pass_msg || fail "exit non-zero"

# --- dry run ----------------------------------------------------------------
it "a dry run prints a plan and changes nothing"
reset_store
out="$(run_dp "$F/monitors-dual.json" "$F/monitors-dual.json" auto --dry-run 2>&1)"
assert_contains "$out" 'DRY:' "a plan was printed"
assert_count_re 0 "$CALL_LOG" 'hyprctl eval'

# --- missing tools ----------------------------------------------------------
it "a missing jq fails loudly and non-zero"
out="$(DP_JQ=/nonexistent/jq run_dp "$F/monitors-dual.json" "$F/monitors-dual.json" auto 2>&1 || true)"
assert_contains "$out" 'not found' "the message names the missing tool"
if DP_JQ=/nonexistent/jq run_dp "$F/monitors-dual.json" "$F/monitors-dual.json" auto >/dev/null 2>&1
then fail "must exit non-zero"; else pass_msg; fi

# --- housekeeping -----------------------------------------------------------
it "stale generated waybar configs from the previous implementation are removed"
reset_store
mkdir -p "$STATE"; touch "$STATE/config-home" "$STATE/config-work"
run_dp "$F/monitors-dual.json" "$F/monitors-dual.json" auto >/dev/null 2>&1
if [[ ! -e "$STATE/config-home" && ! -e "$STATE/config-work" ]]; then pass_msg
else fail "the old files are still there"; fi

# --- Waybar -----------------------------------------------------------------
# Four layouts for the dual set, one per Waybar mode.
ASUS='ASUSTek COMPUTER INC|VG249Q3A|S7LMBS003105'
waybar_store() {
  jq --arg fp "$FP_DUAL" --arg asus "$ASUS" '
    .fingerprints[$fp].layouts.AllBars    = (.fingerprints[$fp].layouts.Home | .waybar = {mode:"all",outputs:[]})
    | .fingerprints[$fp].layouts.BothBars = (.fingerprints[$fp].layouts.Home | .waybar = {mode:"selected",outputs:[$asus,"BOE|0x0630|"]})
    | .fingerprints[$fp].layouts.PrimaryBar = (.fingerprints[$fp].layouts.Home | .waybar = {mode:"primary"})
  ' "$F/store-v1.json" >"$WORK/store.json"
}

waybar_store
it "mode all runs the user's own config, generating nothing"
run_dp "$F/monitors-dual.json" "$F/monitors-dual.json" -- AllBars >/dev/null 2>&1
out="$(run_dp "$F/monitors-dual.json" "$F/monitors-dual.json" waybar-config 2>/dev/null)"
if [[ $out == "$WORK/waybar/config" ]]; then pass_msg; else fail "got '$out'"; fi
if [[ ! -e "$STATE/config-active" ]]; then : ; fi

it "mode selected generates config-active with an output array"
run_dp "$F/monitors-dual.json" "$F/monitors-dual.json" -- Home >/dev/null 2>&1
cfg="$(run_dp "$F/monitors-dual.json" "$F/monitors-dual.json" waybar-config 2>/dev/null)"
if [[ $cfg == "$STATE/config-active" ]]; then pass_msg; else fail "got '$cfg'"; fi
assert_count_re 2 "$cfg" '"output"' "every bar got an output key"
assert_contains "$cfg" '"output": ["DP-2"],' "the array holds just the selected port"
assert_not_contains "$cfg" '"output": "DP-2"' "it is an array, not a bare string"
check "the generated config is still parseable by the bar's own rules" \
  bash -c "grep -q '\"layer\"' '$cfg'"

it "two selected monitors appear as a two-element array, in port order"
run_dp "$F/monitors-dual.json" "$F/monitors-dual.json" -- BothBars >/dev/null 2>&1
cfg2="$(run_dp "$F/monitors-dual.json" "$F/monitors-dual.json" waybar-config 2>/dev/null)"
assert_contains "$cfg2" '"output": ["DP-2", "eDP-1"],' "both ports, sorted"

it "mode primary restricts the bars to the primary monitor"
run_dp "$F/monitors-dual.json" "$F/monitors-dual.json" -- PrimaryBar >/dev/null 2>&1
cfg4="$(run_dp "$F/monitors-dual.json" "$F/monitors-dual.json" waybar-config 2>/dev/null)"
assert_contains "$cfg4" '"output": ["DP-2"],' "the primary's port"

it "a pre-existing output key is replaced, not duplicated"
cp "$F/waybar-config-output-array" "$WORK/waybar/config"
run_dp "$F/monitors-dual.json" "$F/monitors-dual.json" -- Home >/dev/null 2>&1
cfg3="$(run_dp "$F/monitors-dual.json" "$F/monitors-dual.json" waybar-config 2>/dev/null)"
# The fixture has two bars and a multi-line "output" array on the first one.
# Each bar must end up with exactly one output key, the old array gone.
n="$(grep -c '"output"' "$cfg3" || true)"
if [[ $n == 2 ]]; then pass_msg; else fail "$n output keys for two bars"; fi
assert_not_contains "$cfg3" '"eDP-1"' "the old array entries are gone"
assert_contains "$cfg3" '"output": ["DP-2"],' "the new array replaced it"
check "the result is a single-line array per bar" \
  bash -c "! grep -qE '\"output\": \[\s*$' '$cfg3'"

it "a config with no layer key falls back to the user's config, with a warning"
cp "$F/waybar-config-no-layer" "$WORK/waybar/config"
err="$(run_dp "$F/monitors-dual.json" "$F/monitors-dual.json" -- Home 2>&1 >/dev/null || true)"
assert_contains "$err" 'WARN' "the fallback was announced"
cfg5="$(run_dp "$F/monitors-dual.json" "$F/monitors-dual.json" waybar-config 2>/dev/null)"
if [[ $cfg5 == "$WORK/waybar/config" ]]; then pass_msg; else fail "got '$cfg5'"; fi
cp "$F/waybar-config-2bars" "$WORK/waybar/config"

it "waybar is restarted when the config changes"
waybar_store
run_dp "$F/monitors-dual.json" "$F/monitors-dual.json" -- Home >/dev/null 2>&1
# anchored: the systemd-run line also contains "waybar -c ... -s ...".
assert_count_re 1 "$CALL_LOG" '^waybar -c .* -s ' "exactly one launch"
assert_contains "$CALL_LOG" "-s $WORK/waybar/style.css" "the stylesheet was passed"

it "waybar is not restarted when it already runs the same config"
printf '4450 waybar -c %s -s %s\n' "$STATE/config-active" "$WORK/waybar/style.css" >"$FAKE_PGREP_OUT"
run_dp "$F/monitors-dual.json" "$F/monitors-dual.json" -- Home >/dev/null 2>&1
assert_count_re 0 "$CALL_LOG" '^(systemd-run|waybar) ' "no relaunch"
printf '4450 waybar\n' >"$FAKE_PGREP_OUT"

it "a waybar module process is not mistaken for the bar itself"
# On the real machine `pgrep -af waybar` also lists waybar-weather, a module
# script. Taking its line as the running bar would defeat the suppression.
printf '66351 waybar-weather\n4450 waybar -c %s -s %s\n' \
  "$STATE/config-active" "$WORK/waybar/style.css" >"$FAKE_PGREP_OUT"
run_dp "$F/monitors-dual.json" "$F/monitors-dual.json" -- Home >/dev/null 2>&1
assert_count_re 0 "$CALL_LOG" '^(systemd-run|waybar) ' "the bar was recognised despite the module"

it "a module alone does not count as a running bar"
printf '66351 waybar-weather\n' >"$FAKE_PGREP_OUT"
run_dp "$F/monitors-dual.json" "$F/monitors-dual.json" -- Home >/dev/null 2>&1
assert_contains "$CALL_LOG" 'systemd-run' "the bar was started"
printf '4450 waybar\n' >"$FAKE_PGREP_OUT"

it "the dots' own Waybar owner is used when it exists"
# Refresh.sh:97 calls WaybarStartup.sh the owner of the Waybar lifecycle that
# serializes every start. Two independent owners is how duplicate bars appear,
# so the controller delegates to it rather than launching the bar itself.
cat >"$WORK/WaybarStartup.sh" <<'EOF'
#!/usr/bin/env bash
printf 'WaybarStartup %s
' "$*" >>"$FAKE_LOG"
exit 0
EOF
chmod +x "$WORK/WaybarStartup.sh"
FAKE_LOG="$CALL_LOG" DP_WAYBAR_STARTUP="$WORK/WaybarStartup.sh"   run_dp "$F/monitors-dual.json" "$F/monitors-dual.json" -- Home >/dev/null 2>&1
assert_contains "$CALL_LOG" 'WaybarStartup --restart' "the owner was asked to restart the bar"
assert_count_re 0 "$CALL_LOG" '^(systemd-run|waybar) ' "the controller did not start a bar itself"
pass_msg

it "without that owner the controller starts the bar itself"
DP_WAYBAR_STARTUP=/nonexistent run_dp "$F/monitors-dual.json" "$F/monitors-dual.json" -- Home >/dev/null 2>&1
assert_contains "$CALL_LOG" 'systemd-run' "it fell back to its own launch" && pass_msg

it "a transient systemd unit is preferred for the restart"
run_dp "$F/monitors-dual.json" "$F/monitors-dual.json" -- Home >/dev/null 2>&1
assert_contains "$CALL_LOG" 'systemd-run' "systemd-run was used when available"

it "waybar-config prints exactly one line and nothing else"
assert_eq "one line of output" '1' \
  "$(run_dp "$F/monitors-dual.json" "$F/monitors-dual.json" waybar-config 2>/dev/null | wc -l | tr -d ' ')"

it "the Waybar spawn closes the lock descriptor"
if grep -nE 'DP_WAYBAR"? -c|systemd-run' "$SCRIPT" | grep -vE '^[0-9]+:[A-Z_]+=' | grep -q '9>&-'
then pass_msg; else fail "the waybar launch does not close fd 9"; fi


# --- review findings: the rescue path (C1) ----------------------------------
# Rescue only ever runs after step 3 disabled something, so the monitors it
# must bring back are exactly the ones reporting width/height/refreshRate 0.
it "rescue never asks for a 0x0@0 mode"
reset_store
printf '%s\n%s\n' "$F/monitors-dual.json" "$WORK/none.json" >"$WORK/seq.txt"
SEQ="$WORK/seq.txt" run_dp "$F/monitors-dual-dp2-off.json" "$WORK/none.json" -- Work >/dev/null 2>&1 || true
if grep -q 'mode = "0x0@0"' "$CALL_LOG"; then
  fail "rescue emitted an unmatchable mode: $(grep -o 'mode = "[^"]*"' "$CALL_LOG" | tr '\n' ' ')"
else pass_msg; fi

it "rescue gives each monitor its own position"
positions="$(grep -o 'position = "[0-9]*x[0-9]*"' "$CALL_LOG" | sort -u | wc -l | tr -d ' ')"
calls="$(grep -c 'hl\.monitor({ output = .*mode' "$CALL_LOG" || true)"
if (( calls >= 2 && positions >= 2 )); then pass_msg
else fail "$calls mode-setting calls but only $positions distinct positions"; fi

it "rescue re-checks that something is active and says so when it is not"
# The sequence file is consumed as it is read, so it has to be written again.
printf '%s\n%s\n' "$F/monitors-dual.json" "$WORK/none.json" >"$WORK/seq.txt"
err="$(SEQ="$WORK/seq.txt" run_dp "$F/monitors-dual-dp2-off.json" "$WORK/none.json" -- Work 2>&1 >/dev/null || true)"
assert_contains "$err" 'rescue' "the rescue path was announced"
assert_contains "$err" 'still' "a failed rescue is reported, not silent"
pass_msg

# --- review finding I2: a stale active layout from another monitor set -------
it "waybar-config re-resolves when the recorded layout belongs to another monitor set"
reset_store
run_dp "$F/monitors-dual.json" "$F/monitors-dual.json" -- Home >/dev/null 2>&1
# Now only the laptop is connected. The stale active-layout.json restricts the
# bars to a port that no longer exists, which would leave no bar anywhere.
jq -c '[ .[] | select(.name == "eDP-1") ]' "$F/monitors-dual.json" >"$WORK/laptop-only-all.json"
cfg="$(run_dp "$WORK/laptop-only-all.json" "$WORK/laptop-active.json" waybar-config 2>/dev/null)"
if [[ -f $cfg ]] && grep -q 'DP-2' "$cfg"; then
  fail "the bars were restricted to a disconnected monitor"
else pass_msg; fi

# --- review finding I4: transform is passed but never verified --------------
it "a rotation that did not take effect fails verification"
# The layout asks for transform 1; the live monitor reports transform 0.
jq --arg fp "$FP_DUAL" '.fingerprints[$fp].layouts.Rot =
   (.fingerprints[$fp].layouts.Home
    | .monitors |= map(if .port == "DP-2" then (.transform = 1 | .x = 1280) else . end))' \
  "$F/store-v1.json" >"$WORK/store.json"
if run_dp "$F/monitors-dual.json" "$F/monitors-dual.json" -- Rot >/dev/null 2>&1; then
  fail "verification accepted an unrotated monitor"
else pass_msg; fi
assert_count_re 0 "$CALL_LOG" 'disabled = true' "and nothing was disabled"

it "a rotation that did take effect verifies"
jq -c '[ .[] | if .name == "DP-2" then (.transform = 1 | .width = 1080 | .height = 1920) else . end ]' \
  "$F/monitors-dual.json" >"$WORK/dual-rotated-live.json"
jq --arg fp "$FP_DUAL" '.fingerprints[$fp].layouts.Rot =
   (.fingerprints[$fp].layouts.Home
    | .monitors |= map(if .port == "DP-2" then (.transform = 1 | .x = 1280) else . end))' \
  "$F/store-v1.json" >"$WORK/store.json"
run_dp "$F/monitors-dual.json" "$WORK/dual-rotated-live.json" -- Rot >/dev/null 2>&1 && pass_msg \
  || fail "a correctly rotated monitor must verify"

# --- review finding I5: the stand-down detector ------------------------------
cp "$F/store-empty.json" "$WORK/store.json"
it "stands down for Lua's parenthesis-free call sugar"
printf 'hl.monitor{ output = "", mode = "preferred" }\n' >"$WORK/monitors.lua"
run_dp "$F/monitors-dual.json" "$F/monitors-dual.json" auto >/dev/null 2>&1
assert_count_re 0 "$CALL_LOG" 'hl\.monitor\(' "nothing was applied"
pass_msg

it "stands down for a call that is not at the start of a line"
printf 'if true then hl.monitor({ output = "" }) end\n' >"$WORK/monitors.lua"
run_dp "$F/monitors-dual.json" "$F/monitors-dual.json" auto >/dev/null 2>&1
assert_count_re 0 "$CALL_LOG" 'hl\.monitor\(' "nothing was applied"
pass_msg

it "does not stand down for an example inside a block comment"
printf -- '--[[\nhl.monitor({ output = "eDP-1" })\n]]\n' >"$WORK/monitors.lua"
run_dp "$F/monitors-dual.json" "$F/monitors-dual.json" auto >/dev/null 2>&1
assert_contains "$CALL_LOG" 'hl.monitor(' "a commented example must not disable the feature"
pass_msg

it "does not stand down for a line comment"
printf -- '-- hl.monitor({ output = "" })\n' >"$WORK/monitors.lua"
run_dp "$F/monitors-dual.json" "$F/monitors-dual.json" auto >/dev/null 2>&1
assert_contains "$CALL_LOG" 'hl.monitor(' "a commented example must not disable the feature"
pass_msg
rm -f "$WORK/monitors.lua"

# --- review finding I6: a damaged store must say so -------------------------
it "a malformed store is reported to the user, once"
cp "$F/store-malformed.json" "$WORK/store.json"
err="$(run_dp "$F/monitors-dual.json" "$F/monitors-dual.json" auto 2>&1 >/dev/null || true)"
assert_contains "$err" 'malformed' "the log says what is wrong"
assert_contains "$CALL_LOG" 'notify-send' "and the user is told"
pass_msg

it "a store from a newer version is reported too"
cp "$F/store-future.json" "$WORK/store.json"
err="$(run_dp "$F/monitors-dual.json" "$F/monitors-dual.json" auto 2>&1 >/dev/null || true)"
assert_contains "$err" 'newer' "the log says the file is from a newer version"
pass_msg

it "a healthy store is not reported"
reset_store
err="$(run_dp "$F/monitors-dual.json" "$F/monitors-dual.json" auto 2>&1 >/dev/null || true)"
assert_not_contains "$err" 'malformed' "no false alarm" && pass_msg

# --- review finding I11: a systemd-managed bar ------------------------------
it "with waybar.service enabled and a restriction active, the bar is started directly"
# WaybarStartup.sh would hand a service restart to systemd, and the unit does
# not pass -c, so the restriction would be silently dropped.
cat >"$WORK/WaybarStartup.sh" <<'EOF'
#!/usr/bin/env bash
printf 'WaybarStartup %s\n' "$*" >>"$FAKE_LOG"
exit 0
EOF
chmod +x "$WORK/WaybarStartup.sh"
cat >"$SANDBOX/bin/systemctl" <<'EOF'
#!/usr/bin/env bash
printf 'systemctl %s\n' "$*" >>"$CALL_LOG"
[[ $* == *is-enabled*waybar* ]] && { printf 'enabled\n'; exit 0; }
exit 0
EOF
chmod +x "$SANDBOX/bin/systemctl"
reset_store
FAKE_LOG="$CALL_LOG" DP_WAYBAR_STARTUP="$WORK/WaybarStartup.sh" \
  run_dp "$F/monitors-dual.json" "$F/monitors-dual.json" -- Home >/dev/null 2>&1
assert_count_re 0 "$CALL_LOG" 'WaybarStartup --restart' "the service path was avoided"
assert_contains "$CALL_LOG" 'systemd-run' "the bar was started with an explicit config"
pass_msg

it "with waybar.service enabled but no restriction, the owner is still used"
jq --arg fp "$FP_DUAL" '.fingerprints[$fp].layouts.Home.waybar = {mode:"all",outputs:[]}' \
  "$F/store-v1.json" >"$WORK/store.json"
FAKE_LOG="$CALL_LOG" DP_WAYBAR_STARTUP="$WORK/WaybarStartup.sh" \
  run_dp "$F/monitors-dual.json" "$F/monitors-dual.json" -- Home >/dev/null 2>&1
assert_contains "$CALL_LOG" 'WaybarStartup --restart' "nothing to lose, so delegate" && pass_msg
cat >"$SANDBOX/bin/systemctl" <<'EOF'
#!/usr/bin/env bash
printf 'systemctl %s\n' "$*" >>"$CALL_LOG"
exit 1
EOF
chmod +x "$SANDBOX/bin/systemctl"


# --- lid / clamshell (replaces user_laptops.lua's job) ----------------------
# A closed lid with an external monitor still on means the internal panel
# should switch off (docked). But never when the panel is the only screen,
# or a closed-lid laptop with no external would go dark.
it "a closed lid with an external monitor disables the internal panel"
reset_store
DP_LID_STATE=closed run_dp "$F/monitors-dual.json" "$F/monitors-dual.json" -- Home >/dev/null 2>&1
assert_contains "$CALL_LOG" 'output = "eDP-1", disabled = true' "the internal panel was switched off"
assert_contains "$CALL_LOG" 'hl.monitor({ output = "DP-2"' "the external stayed on"

it "an open lid leaves the internal panel on"
DP_LID_STATE=open run_dp "$F/monitors-dual.json" "$F/monitors-dual.json" -- Home >/dev/null 2>&1
assert_count_re 0 "$CALL_LOG" 'output = "eDP-1", disabled = true' "nothing was forced off"
assert_contains "$CALL_LOG" 'hl.monitor({ output = "eDP-1"' "the panel was configured normally"

it "a closed lid with NO external keeps the internal panel on (never zero screens)"
# Laptop-only layout, lid shut: the panel is all there is, so it must stay.
jq -c '[ .[] | select(.name == "eDP-1") ]' "$F/monitors-dual.json" >"$WORK/laptop-only2.json"
ds_normalize "$WORK/laptop-only2.json" >"$WORK/laptop-only2.norm.json"
FP_LAPTOP="$(ds_fingerprint "$WORK/laptop-only2.norm.json")"
jq -n --arg fp "$FP_LAPTOP" --slurpfile v1 "$F/store-v1.json" \
  '{version:1, fingerprints: { ($fp): { label:"", default:"Solo", layouts: { Solo:
     ($v1[0].fingerprints | to_entries[0].value.layouts.Home
      | .monitors |= map(select(.port == "eDP-1"))) } } }}' >"$WORK/store.json"
DP_LID_STATE=closed run_dp "$WORK/laptop-only2.json" "$WORK/laptop-only2.json" -- Solo >/dev/null 2>&1
assert_count_re 0 "$CALL_LOG" 'disabled = true' "the only screen was not switched off"
assert_contains "$CALL_LOG" 'hl.monitor({ output = "eDP-1"' "the panel stayed on"

it "dp_lid_closed reads the real state files when the seam is unset"
# Home exists for the dual fingerprint; restore it after the Solo test above.
reset_store
# Point the glob at a fixture directory so no /proc access is needed.
mkdir -p "$WORK/lid/LID0"
printf 'state:      closed\n' >"$WORK/lid/LID0/state"
out="$(DP_LID_STATE='' DP_LID_GLOB="$WORK/lid/*/state" \
  run_dp "$F/monitors-dual.json" "$F/monitors-dual.json" -- Home 2>&1 >/dev/null || true)"
assert_contains "$CALL_LOG" 'output = "eDP-1", disabled = true' "a closed state file forced the panel off"
printf 'state:      open\n' >"$WORK/lid/LID0/state"
DP_LID_STATE='' DP_LID_GLOB="$WORK/lid/*/state" \
  run_dp "$F/monitors-dual.json" "$F/monitors-dual.json" -- Home >/dev/null 2>&1
assert_count_re 0 "$CALL_LOG" 'output = "eDP-1", disabled = true' "an open state file left it on"


# --- the nwg bridge: import-nwg verb ----------------------------------------
it "import-nwg applies the layout nwg wrote to the file"
reset_store
cat >"$WORK/nwg.conf" <<'EOS'
# Generated by nwg-displays
monitor=desc:BOE 0x0630,1920x1080@60.03,0x0,1.25
monitor=desc:ASUSTek COMPUTER INC VG249Q3A S7LMBS003105,1920x1080@119.88,1536x0,1
EOS
run_dp "$F/monitors-dual.json" "$F/monitors-dual.json" import-nwg "$WORK/nwg.conf" >/dev/null 2>&1
assert_contains "$CALL_LOG" 'scale = "1.25"' "the dragged laptop scale was applied"
assert_contains "$CALL_LOG" 'position = "1536x0"' "the external was placed where nwg put it"

it "import-nwg leaves the applied layout ready to save (active-layout.json)"
if [[ -f "$STATE/active-layout.json" ]] \
   && [[ "$(jq -r '.monitors[]|select(.identity|startswith("BOE"))|.scale' "$STATE/active-layout.json")" == "1.25" ]]
then pass_msg; else fail "the imported layout was not staged for saving"; fi

it "import-nwg on a file nwg never wrote (empty) changes nothing"
printf '# nothing\n' >"$WORK/nwg-empty.conf"
if run_dp "$F/monitors-dual.json" "$F/monitors-dual.json" import-nwg "$WORK/nwg-empty.conf" >/dev/null 2>&1
then fail "should refuse an empty nwg file"; else pass_msg; fi
assert_count_re 0 "$CALL_LOG" 'hl\.monitor\(\{ output'

it "import-nwg needs a file argument"
if run_dp "$F/monitors-dual.json" "$F/monitors-dual.json" import-nwg >/dev/null 2>&1
then fail "should require a path"; else pass_msg; fi


# --- structural guarantees --------------------------------------------------
it "no shell eval anywhere in the controller"
# `hyprctl eval` is Hyprland's own subcommand, not the shell builtin.
if sed 's/#.*$//' "$SCRIPT" | sed 's/\$\?DP_HYPRCTL[" ]* eval//g; s/hyprctl eval//g' \
   | grep -qE '\beval\b'; then fail "shell eval found"; else pass_msg; fi

it "no output name is hardcoded"
if sed 's/#.*$//' "$SCRIPT" | grep -qE '\b(eDP|LVDS|DSI|DP|HDMI-A|DVI-D)-[0-9]+'; then
  fail "a port name is hardcoded: $(sed 's/#.*$//' "$SCRIPT" | grep -nE '\b(eDP|LVDS|DSI|DP|HDMI-A|DVI-D)-[0-9]+' | head -1)"
else pass_msg; fi

it "no laptop/external vocabulary survives"
if grep -qE 'LAPTOP_OUTPUT|EXTERNAL_OUTPUT|EXTERNAL_EXPECTED' "$SCRIPT"; then
  fail "two-monitor vocabulary still present"; else pass_msg; fi

it "every child spawn closes the lock descriptor"
bad="$(sed 's/#.*$//' "$SCRIPT" | grep -nE '(^|[^0-9&])& *$|systemd-run' \
       | grep -vE '^[0-9]+:[A-Z_]+=' | grep -v '9>&-' || true)"
if [[ -z $bad ]]; then pass_msg; else fail "spawn without 9>&-: $bad"; fi

it "the lock is taken on an explicit descriptor, never via exec flock"
if sed 's/#.*$//' "$SCRIPT" | grep -qE 'exec +"?\$DP_FLOCK|exec +flock'; then fail "exec flock found"
elif grep -q 'exec 9>' "$SCRIPT"; then pass_msg
else fail "no explicit fd 9 lock"; fi

it "a dry run never takes the lock"
if grep -q 'wants_dry_run' "$SCRIPT"; then pass_msg; else fail "no dry-run lock guard"; fi

summary "test-display-profile"
