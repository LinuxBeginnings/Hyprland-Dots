#!/usr/bin/env bash
# ==================================================
#  KoolDots (2026)
#  Project URL: https://github.com/LinuxBeginnings
#  License: GNU GPLv3
#  SPDX-License-Identifier: GPL-3.0-or-later
# ==================================================
# Purpose:
#   Tests for WaybarStartup.sh's start/restart decision.
#
#   The bug guarded against here is that a waybar process which is already dying
#   - most visibly one that is dumping core after a signal - still answers
#   `pgrep`. The relaunch took it for a running bar and skipped its own launch,
#   so the session had no bar until the next attempt (issue #158).
#
#   The functions under test are lifted out of the script by name and run against
#   fake pgrep/ps/pkill/waybar, the way the display-profile suites exercise one
#   function at a time. No real bar is ever started.
# No `set -e`: the assertion helpers return non-zero on failure, and exiting on
# the first one would hide every later check in the run.
set -uo pipefail
HERE="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=./lib_test.sh
source "$HERE/lib_test.sh"

S="$HERE/.."
SCRIPT="$S/WaybarStartup.sh"
LID="$S/LidSwitch.sh"
WORK="$(mktemp -d)"; trap 'rm -rf -- "$WORK"' EXIT
BIN="$WORK/bin"
CALL_LOG="$WORK/calls.log"
mkdir -p "$BIN"
: >"$CALL_LOG"

# --- fake commands ----------------------------------------------------------
# pgrep: prints whatever FAKE_WAYBAR_PIDS holds, and never matches the Gentoo
# shim, so the two lookups one caller makes cannot double-count one process.
cat >"$BIN/pgrep" <<'EOS'
#!/usr/bin/env bash
printf 'pgrep %s\n' "$*" >> "$FAKE_LOG"
case "$*" in *waybar-wrapped*) exit 1 ;; esac
[[ -n ${FAKE_WAYBAR_PIDS:-} ]] || exit 1
printf '%s\n' "$FAKE_WAYBAR_PIDS"
exit 0
EOS

# ps: reports FAKE_PS_STATE for any pid, or fails outright when FAKE_PS_READABLE
# is 0 - which is how "the state could not be read" is simulated.
cat >"$BIN/ps" <<'EOS'
#!/usr/bin/env bash
printf 'ps %s\n' "$*" >> "$FAKE_LOG"
[[ ${FAKE_PS_READABLE:-1} == 1 ]] || exit 1
printf '%s\n' "${FAKE_PS_STATE:-}"
EOS

cat >"$BIN/pkill" <<'EOS'
#!/usr/bin/env bash
printf 'pkill %s\n' "$*" >> "$FAKE_LOG"
exit 0
EOS

cat >"$BIN/waybar" <<'EOS'
#!/usr/bin/env bash
printf 'waybar %s\n' "$*" >> "$FAKE_LOG"
exit 0
EOS

chmod +x "$BIN"/*

# --- harness ----------------------------------------------------------------
# The test shell itself: alive for the whole run, so `kill -0` succeeds on it and
# the fake pgrep can hand it back as a waybar pid.
SELF_PID="$$"
# A pid that is definitely gone: spawn it, let it exit, reap it.
sleep 0.01 &
DEAD_PID=$!
wait "$DEAD_PID" 2>/dev/null || true

FAKE_WAYBAR_PIDS=""
FAKE_PS_STATE=""
FAKE_PS_READABLE=1
# The stop's wait is 0.1s a tick, so keep it short here.
WAYBAR_EXIT_WAIT_TICKS=3

extract_fn() { sed -n "/^$2()/,/^}/p" -- "$1"; }

LIVE_FNS="$(extract_fn "$SCRIPT" waybar_live_pids)
$(extract_fn "$SCRIPT" is_waybar_running)"
START_FNS="$LIVE_FNS
$(extract_fn "$SCRIPT" wait_for_waybar)
$(extract_fn "$SCRIPT" start_waybar_direct)"
STOP_FNS="$(extract_fn "$SCRIPT" waybar_processes_present)
$LIVE_FNS
$(extract_fn "$SCRIPT" wait_for_waybar_exit)
$(extract_fn "$SCRIPT" stop_waybar_instances)"

# run_fns <functions> <statement>: run the lifted functions with the fakes on
# PATH. The FAKE_* values are passed explicitly, so nothing leaks between tests.
run_fns() {
  local functions=$1 statement=$2
  env PATH="$BIN:$PATH" \
      FAKE_LOG="$CALL_LOG" \
      FAKE_WAYBAR_PIDS="$FAKE_WAYBAR_PIDS" \
      FAKE_PS_STATE="$FAKE_PS_STATE" \
      FAKE_PS_READABLE="$FAKE_PS_READABLE" \
      WAYBAR_SETTLE_DELAY="0" \
      WAYBAR_EXIT_WAIT_TICKS="$WAYBAR_EXIT_WAIT_TICKS" \
      WAYBAR_CONFIG_ARG="$WORK/waybar/config" \
      WAYBAR_STYLE_ARG="$WORK/waybar/style.css" \
      bash -c "$functions"$'\n'"$statement"
}

# bar_state <state> -> is_waybar_running's exit status with one waybar pid
# reported in that state.
bar_state() {
  FAKE_WAYBAR_PIDS="$SELF_PID" FAKE_PS_STATE="$1" FAKE_PS_READABLE=1
  run_fns "$LIVE_FNS" 'is_waybar_running' >/dev/null 2>&1
}

# --- what counts as a bar ---------------------------------------------------
it "a waybar that is dumping core (state D) is not a running bar"
if bar_state "D"; then fail "a core-dumping process was taken for a running bar"
else pass_msg; fi

it "a zombie waybar (state Z) is not a running bar"
if bar_state "Z+"; then fail "a zombie was taken for a running bar"
else pass_msg; fi

it "a waybar in normal sleep (state S) is a running bar"
if bar_state "SN"; then pass_msg
else fail "a live bar was not recognised"; fi

it "no waybar at all is not a running bar"
FAKE_WAYBAR_PIDS="" FAKE_PS_STATE="S" FAKE_PS_READABLE=1
if run_fns "$LIVE_FNS" 'is_waybar_running' >/dev/null 2>&1; then
  fail "a bar was reported with no process behind it"
else pass_msg; fi

it "a process that disappeared before its state was read is not a running bar"
FAKE_WAYBAR_PIDS="$DEAD_PID" FAKE_PS_STATE="S" FAKE_PS_READABLE=1
if run_fns "$LIVE_FNS" 'is_waybar_running' >/dev/null 2>&1; then
  fail "a reaped pid was reported as a running bar"
else pass_msg; fi

it "an unreadable state keeps the process, so no second bar is started"
# The conservative answer matters: reading "no state" as "dead" would launch a
# duplicate bar on any system where ps cannot answer.
FAKE_WAYBAR_PIDS="$SELF_PID" FAKE_PS_STATE="D" FAKE_PS_READABLE=0
if run_fns "$LIVE_FNS" 'is_waybar_running' >/dev/null 2>&1; then pass_msg
else fail "a process whose state could not be read was dropped as dead"; fi

# --- the launch guard -------------------------------------------------------
it "the start path refuses to launch a second bar while one is up"
: >"$CALL_LOG"
FAKE_WAYBAR_PIDS="$SELF_PID" FAKE_PS_STATE="SN" FAKE_PS_READABLE=1
run_fns "$START_FNS" 'start_waybar_direct; wait' >/dev/null 2>&1 || true
assert_count_re 0 "$CALL_LOG" '^waybar ' "no second bar was launched" && pass_msg

it "the restart path launches even when a process still answers pgrep"
: >"$CALL_LOG"
FAKE_WAYBAR_PIDS="$SELF_PID" FAKE_PS_STATE="SN" FAKE_PS_READABLE=1
run_fns "$START_FNS" 'start_waybar_direct force; wait' >/dev/null 2>&1 || true
assert_contains "$CALL_LOG" \
  "waybar -c $WORK/waybar/config -s $WORK/waybar/style.css" \
  "the forced launch happened anyway" && pass_msg

it "the restart path still launches when only a corpse is left"
: >"$CALL_LOG"
FAKE_WAYBAR_PIDS="$SELF_PID" FAKE_PS_STATE="D" FAKE_PS_READABLE=1
run_fns "$START_FNS" 'start_waybar_direct; wait' >/dev/null 2>&1 || true
assert_count_re 1 "$CALL_LOG" '^waybar ' "a corpse suppressed the launch" && pass_msg

# --- the stop ---------------------------------------------------------------
it "the stop escalates and reports a bar that outlived the wait"
: >"$CALL_LOG"
FAKE_WAYBAR_PIDS="$SELF_PID" FAKE_PS_STATE="SN" FAKE_PS_READABLE=1
if run_fns "$STOP_FNS" 'stop_waybar_instances' >/dev/null 2>&1; then
  fail "a bar still in the process table was reported as stopped"
else pass_msg; fi
assert_contains "$CALL_LOG" 'pkill -9 -x waybar' "it escalated to SIGKILL"

it "the stop reports success once no usable bar is left"
FAKE_WAYBAR_PIDS="$SELF_PID" FAKE_PS_STATE="D" FAKE_PS_READABLE=1
if run_fns "$STOP_FNS" 'stop_waybar_instances' >/dev/null 2>&1; then pass_msg
else fail "a core-dumping leftover was treated as a bar that would not die"; fi

it "the stop reports success when nothing is running"
FAKE_WAYBAR_PIDS="" FAKE_PS_STATE="S" FAKE_PS_READABLE=1
if run_fns "$STOP_FNS" 'stop_waybar_instances' >/dev/null 2>&1; then pass_msg
else fail "an empty process table was reported as a survivor"; fi

# --- the shape of the scripts ----------------------------------------------
it "the state filter drops zombies and core-dumping processes"
if extract_fn "$SCRIPT" waybar_live_pids | grep -q 'Z\*|D\*'; then pass_msg
else fail "nothing drops Z/D, so a dying bar still counts as a bar"; fi

it "is_waybar_running is built on that filter"
if extract_fn "$SCRIPT" is_waybar_running | grep -q 'waybar_live_pids'; then pass_msg
else fail "is_waybar_running no longer asks whether the process is usable"; fi

it "the stop waits for the bar to leave"
if extract_fn "$SCRIPT" stop_waybar_instances | grep -q 'wait_for_waybar_exit'; then pass_msg
else fail "the stop returns without waiting for the bar to go"; fi

it "the stop escalates on the raw matches, not on the live ones"
# A process that is dumping core is not a bar, but -9 is what reaps it as soon
# as it becomes interruptible, so the escalation must not be skipped for it.
if extract_fn "$SCRIPT" stop_waybar_instances | grep -q 'waybar_processes_present'; then pass_msg
else fail "the escalation is skipped for a process that is not a live bar"; fi

it "the restart path forces the launch when a bar outlives the stop"
if grep -qF 'stop_waybar_instances || force="force"' "$SCRIPT"; then pass_msg
else fail "a surviving process can still veto the relaunch"; fi

it "start_waybar_direct honours the force argument"
if extract_fn "$SCRIPT" start_waybar_direct | grep -q '"force"'; then pass_msg
else fail "the launch ignores the force argument"; fi

it "dedupe sees every waybar process that has not exited"
# The duplicate clean-up is the last line of defence. It has to count a process
# it would not call a usable bar, or one caught mid-reload in state D survives
# as a second bar - which is exactly how a duplicate outlived this clean-up.
if extract_fn "$SCRIPT" dedupe_waybar_instances | grep -q 'waybar_processes_alive' \
   && ! extract_fn "$SCRIPT" dedupe_waybar_instances | grep -q 'waybar_live_pids'; then pass_msg
else fail "dedupe only looks at the bars it would call usable"; fi

it "the wider list still drops a process that has exited"
# Z is the one state that is definitely not a bar any more. D is not: the same
# state covers a bar reading its CSS and a bar dumping core, so only the
# duplicate clean-up may act on it.
if extract_fn "$SCRIPT" waybar_processes_alive | grep -q 'Z\*)' \
   && ! extract_fn "$SCRIPT" waybar_processes_alive | grep -q 'D\*'; then pass_msg
else fail "waybar_processes_alive does not tell Z apart from D"; fi

it "dedupe keeps the newest process, so a corpse can never be the survivor"
if extract_fn "$SCRIPT" dedupe_waybar_instances | grep -q 'sort -n | tail -n1'; then pass_msg
else fail "the survivor is no longer the newest"; fi

it "LidSwitch.sh asks the same question before signalling a bar"
# Signalling a dying process instead of starting a bar is the same bug one step
# further out, and it is the copy of the check that is easiest to forget.
if extract_fn "$LID" is_waybar_running | grep -q 'Z\*|D\*'; then pass_msg
else fail "LidSwitch.sh still signals a process that is not a bar"; fi

it "LidSwitch.sh settles that question before starting a bar"
# The refresh's own wallpaper step has just told waybar to reload, so a single
# read can catch a live bar in state D - which is not a bar by the check above.
# Deciding to start one on that read is the duplicate, so the decision waits.
if grep -q 'if is_waybar_running_settled; then' "$LID" \
   && extract_fn "$LID" is_waybar_running_settled | grep -q 'is_waybar_running && return 0'; then pass_msg
else fail "LidSwitch.sh still decides on a single read"; fi

it "WallustSwww.sh checks the Waybar startup lock before signalling reload"
WALLUST="$S/WallustSwww.sh"
if extract_fn "$WALLUST" reload_running_waybar_colors | grep -q 'waybar-startup.*\.lock'; then pass_msg
else fail "WallustSwww.sh signals waybar without checking startup lock"; fi

it "WaybarStartup.sh exports HYPRLAND_INSTANCE_SIGNATURE if unset"
if extract_fn "$SCRIPT" wait_for_wayland | grep -q 'HYPRLAND_INSTANCE_SIGNATURE='; then pass_msg
else fail "WaybarStartup.sh does not discover/export HYPRLAND_INSTANCE_SIGNATURE"; fi

it "all scripts are still valid bash"
bad=""
for f in WaybarStartup.sh LidSwitch.sh WallustSwww.sh; do
  bash -n "$S/$f" 2>/dev/null || bad="$bad $f"
done
if [[ -z $bad ]]; then pass_msg; else fail "syntax errors in:$bad"; fi

summary "test-waybar-startup"
