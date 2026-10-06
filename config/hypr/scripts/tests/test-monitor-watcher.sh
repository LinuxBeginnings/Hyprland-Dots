#!/usr/bin/env bash
# ==================================================
#  KoolDots (2026)
#  Project URL: https://github.com/LinuxBeginnings
#  License: GNU GPLv3
#  SPDX-License-Identifier: GPL-3.0-or-later
# ==================================================
# Purpose:
#   Behaviour tests for MonitorWatcher.sh: event filtering, debounce,
#   startup reconciliation, reconnect and singleton behaviour. The event
#   stream is a fixture file, so no Hyprland socket is required.
set -uo pipefail

source "$(dirname -- "${BASH_SOURCE[0]}")/lib_test.sh"

SCRIPT="${MW_SCRIPT:-$SCRIPT_DIR/MonitorWatcher.sh}"
SANDBOX=$(mktemp -d)
trap 'rm -rf "$SANDBOX"' EXIT
BIN="$SANDBOX/bin"
mkdir -p "$BIN"
PROFILE_LOG="$SANDBOX/profile-calls.log"

# Fake controller: records each invocation instead of touching the session.
cat > "$BIN/DisplayProfile.sh" <<'EOS'
#!/usr/bin/env bash
printf '%s\n' "$*" >> "$PROFILE_LOG"
exit 0
EOS
chmod +x "$BIN/DisplayProfile.sh"
export PROFILE_LOG

# run_watcher <event-fixture-or-empty> [extra env assignments...]
run_watcher() {
  local fixture=$1; shift
  : > "$PROFILE_LOG"
  local -a env_args=(
    "MW_PROFILE_SCRIPT=$BIN/DisplayProfile.sh"
    "MW_DEBOUNCE=0.3"
    "MW_RECONNECT_DELAY=0.1"
    "MW_MAX_RECONNECTS=0"
    "MW_RUNTIME_DIR=$SANDBOX"
    "MW_LOG_FILE=$SANDBOX/watcher.log"
    "MW_RETRY_DELAY=0.3"
  )
  [[ -n $fixture ]] && env_args+=("MW_EVENT_FILE=$FIXTURES/$fixture")
  env "${env_args[@]}" "$@" timeout 30 bash "$SCRIPT" >"$SANDBOX/out.txt" 2>&1
  echo $?
}

profile_calls() { wc -l < "$PROFILE_LOG" | tr -d ' '; }

it "startup: reconciles once with 'auto' even when no event ever arrives"
st=$(run_watcher events-no-display.txt)
assert_status 0 "$st" "watcher exit"
[[ $(profile_calls) == 1 ]] || fail "expected exactly 1 startup call, got $(profile_calls): $(cat "$PROFILE_LOG")"
assert_contains "$PROFILE_LOG" "auto" && pass_msg

it "ignores events that are not monitor changes"
# same run as above: the unrelated fixture must not add any call
[[ $(profile_calls) == 1 ]] || fail "unrelated events triggered $(( $(profile_calls) - 1 )) extra call(s)"
pass_msg

it "a burst of DP-2 events produces exactly one debounced apply"
st=$(run_watcher events-burst.txt)
assert_status 0 "$st" "watcher exit"
# 1 startup + 1 debounced
[[ $(profile_calls) == 2 ]] || fail "expected 2 calls (startup + 1 debounced), got $(profile_calls): $(cat "$PROFILE_LOG")"
pass_msg

it "monitorremoved for DP-2 triggers an apply"
st=$(run_watcher events-removed.txt)
assert_status 0 "$st" "watcher exit"
[[ $(profile_calls) == 2 ]] || fail "expected 2 calls, got $(profile_calls)"
pass_msg

it "recognises the v2 monitorremoved event shape"
st=$(run_watcher events-removed-v2.txt)
assert_status 0 "$st" "watcher exit"
[[ $(profile_calls) == 2 ]] || fail "expected 2 calls for v2 event, got $(profile_calls)"
pass_msg

it "every apply uses 'auto', never a hardcoded profile"
assert_contains "$PROFILE_LOG" "auto"
assert_not_contains "$PROFILE_LOG" "home"
assert_not_contains "$PROFILE_LOG" "work" && pass_msg

it "reconnects after the event stream closes"
st=$(run_watcher events-removed.txt "MW_MAX_RECONNECTS=1")
assert_status 0 "$st" "watcher exit"
# startup + 1 per pass over the stream, twice through = 3
[[ $(profile_calls) == 3 ]] || fail "expected 3 calls with one reconnect, got $(profile_calls)"
assert_contains "$SANDBOX/out.txt" "reconnect" && pass_msg

it "singleton: a second watcher exits cleanly without applying a profile"
# hold the lock, then start a watcher that must refuse to run
lockfile="$SANDBOX/kooldots-monitor-watcher.lock"
: > "$lockfile"
( flock -x 9; sleep 3 ) 9>"$lockfile" &
holder=$!
sleep 0.3
st=$(run_watcher events-burst.txt "MW_LOCK_WAIT=0")
kill "$holder" 2>/dev/null
wait "$holder" 2>/dev/null
assert_status 0 "$st" "second watcher must exit 0"
[[ $(profile_calls) == 0 ]] || fail "second watcher applied $(profile_calls) profile(s); expected 0"
assert_contains "$SANDBOX/out.txt" "already running" && pass_msg

it "missing socket information: clear diagnostic, non-zero exit, no apply"
# Isolate XDG_RUNTIME_DIR: with no signature the watcher now falls back to
# discovering a live socket, and the real session has one.
mkdir -p "$SANDBOX/empty-xdg"
st=$(run_watcher "" "HYPRLAND_INSTANCE_SIGNATURE=" "XDG_RUNTIME_DIR=$SANDBOX/empty-xdg")
[[ $st != 0 ]] || fail "expected non-zero exit without a socket, got $st"
[[ $(profile_calls) == 0 ]] || fail "expected no profile call, got $(profile_calls)"
assert_contains "$SANDBOX/out.txt" "socket" && pass_msg

it "missing socat: clear diagnostic naming the command"
st=$(run_watcher "" "HYPRLAND_INSTANCE_SIGNATURE=fake-sig" "MW_SOCAT=definitely-not-socat" \
      "XDG_RUNTIME_DIR=$SANDBOX/empty-xdg")
[[ $st != 0 ]] || fail "expected non-zero exit without socat, got $st"
assert_contains "$SANDBOX/out.txt" "definitely-not-socat" && pass_msg

it "a long-lived grandchild does not keep the watcher lock held"
# The controller may leave waybar running. If that process inherits the
# watcher's lock descriptor, no later watcher can ever start.
cat > "$BIN/DisplayProfile.sh" <<'EOS'
#!/usr/bin/env bash
printf '%s\n' "$*" >> "$PROFILE_LOG"
# emulate waybar: a child that outlives this script
( exec sleep 10 ) &
exit 0
EOS
chmod +x "$BIN/DisplayProfile.sh"
rm -f "$SANDBOX/kooldots-monitor-watcher.lock"
st=$(run_watcher events-unrelated.txt)
assert_status 0 "$st" "first watcher"
st=$(run_watcher events-unrelated.txt)
pkill -P $$ -x sleep >/dev/null 2>&1 || true
assert_status 0 "$st" "second watcher"
assert_not_contains "$SANDBOX/out.txt" "already running" && pass_msg

# --- findings from the whole-branch review ---------------------------------
it "the event stream does not keep the watcher lock held"
# The stream is read through process substitution. If that subshell inherits
# the lock descriptor, a socat left blocked on the socket holds the lock after
# the watcher is killed, and no watcher can ever start again.
cat > "$BIN/DisplayProfile.sh" <<'EOS'
#!/usr/bin/env bash
printf '%s\n' "$*" >> "$PROFILE_LOG"
exit 0
EOS
chmod +x "$BIN/DisplayProfile.sh"
lock="$SANDBOX/kooldots-monitor-watcher.lock"
rm -f "$lock"
: > "$PROFILE_LOG"
env "MW_PROFILE_SCRIPT=$BIN/DisplayProfile.sh" "MW_DEBOUNCE=0.3" \
    "MW_RECONNECT_DELAY=0.1" "MW_MAX_RECONNECTS=0" "MW_RUNTIME_DIR=$SANDBOX" \
    "MW_LOG_FILE=$SANDBOX/watcher.log" "MW_EVENT_FILE=$FIXTURES/events-unrelated.txt" \
    "MW_EVENT_LINGER=4" \
    bash "$SCRIPT" >"$SANDBOX/out.txt" 2>&1
if flock -n "$lock" true; then
  pass_msg
else
  fail "the lock is still held by the lingering event stream"
fi
pkill -P $$ -x sleep >/dev/null 2>&1 || true

it "a stale instance signature does not stop the watcher finding the live socket"
# HYPRLAND_INSTANCE_SIGNATURE is baked in at process start. After Hyprland is
# restarted, the old value points at a socket that no longer exists, so the
# path has to be re-resolved instead of retried forever.
runtime="$SANDBOX/xdg"
mkdir -p "$runtime/hypr/live-sig"
python3 -c 'import socket,sys; s=socket.socket(socket.AF_UNIX); s.bind(sys.argv[1])' \
  "$runtime/hypr/live-sig/.socket2.sock"
st=$(env "MW_PROFILE_SCRIPT=$BIN/DisplayProfile.sh" "MW_RUNTIME_DIR=$SANDBOX" \
      "MW_LOG_FILE=$SANDBOX/watcher.log" "XDG_RUNTIME_DIR=$runtime" \
      "HYPRLAND_INSTANCE_SIGNATURE=stale-sig-that-is-gone" \
      "MW_MAX_RECONNECTS=0" "MW_RECONNECT_DELAY=0.1" \
      timeout 10 bash "$SCRIPT" --print-socket >"$SANDBOX/out.txt" 2>&1; echo $?)
assert_status 0 "$st" "--print-socket"
assert_contains "$SANDBOX/out.txt" "live-sig/.socket2.sock" && pass_msg

it "an event whose profile change could not be applied is retried, not dropped"
# The controller refuses when another change holds its lock. Dropping the
# event there would leave the displays wrong until the user pressed a key.
cat > "$BIN/DisplayProfile.sh" <<'EOS'
#!/usr/bin/env bash
printf '%s\n' "$*" >> "$PROFILE_LOG"
# fail the first apply after startup, succeed afterwards
if [[ $(wc -l < "$PROFILE_LOG") -eq 2 ]]; then exit 1; fi
exit 0
EOS
chmod +x "$BIN/DisplayProfile.sh"
rm -f "$SANDBOX/kooldots-monitor-watcher.lock"
st=$(run_watcher events-removed.txt)
assert_status 0 "$st" "watcher exit"
# startup + failed apply + retried apply
[[ $(profile_calls) == 3 ]] || fail "expected 3 calls (startup, failed apply, retry), got $(profile_calls)"
assert_contains "$SANDBOX/out.txt" "retry" && pass_msg

# The retry test above leaves a fake controller that fails its first call.
# Restore the plain recording fake, or every check below measures that instead.
cat > "$BIN/DisplayProfile.sh" <<'EOS'
#!/usr/bin/env bash
printf '%s\n' "$*" >> "$PROFILE_LOG"
exit 0
EOS
chmod +x "$BIN/DisplayProfile.sh"

# --- any monitor, not just one named port ----------------------------------
it "reacts to a monitor it has never heard of"
st=$(run_watcher events-other-monitor.txt)
assert_status 0 "$st" "watcher exit"
[[ $(profile_calls) == 2 ]] || fail "expected 2, got $(profile_calls) [$(tr '\n' '|' < "$PROFILE_LOG")] log: $(tail -8 "$SANDBOX/watcher.log" | tr '\n' '|')"

it "no port name is hardcoded in the watcher"
if sed 's/#.*$//' "$SCRIPT" | grep -qE '\b(eDP|LVDS|DSI|DP|HDMI-A|DVI-D)-[0-9]+'; then
  fail "hardcoded: $(sed 's/#.*$//' "$SCRIPT" | grep -nE '\b(eDP|LVDS|DSI|DP|HDMI-A|DVI-D)-[0-9]+' | head -1)"
else pass_msg; fi

it "the two-monitor vocabulary is gone"
if grep -qE 'EXTERNAL_OUTPUT|LAPTOP_OUTPUT' "$SCRIPT"; then fail "still present"; else pass_msg; fi

# --- the pause protocol ----------------------------------------------------
it "monitor events are ignored while a live PID holds the pause file"
mkdir -p "$SANDBOX/kooldots-display-profiles"
sleep 30 & live=$!
printf '%s\n' "$live" >"$SANDBOX/kooldots-display-profiles/pause"
st=$(run_watcher events-burst.txt)
kill "$live" 2>/dev/null || true
assert_status 0 "$st" "watcher exit"
[[ $(profile_calls) == 0 ]] || fail "expected no calls at all while paused, got $(profile_calls): $(cat "$PROFILE_LOG")"
assert_contains "$SANDBOX/watcher.log" "paused" && pass_msg

it "a stale pause file whose PID is gone is ignored and removed"
printf '999999\n' >"$SANDBOX/kooldots-display-profiles/pause"
st=$(run_watcher events-burst.txt)
assert_status 0 "$st" "watcher exit"
[[ $(profile_calls) -ge 1 ]] || fail "a dead PID must not block the apply"
if [[ -e "$SANDBOX/kooldots-display-profiles/pause" ]]; then fail "the stale file was not removed"; else pass_msg; fi

it "a pause file holding nonsense is ignored"
printf 'not-a-pid\n' >"$SANDBOX/kooldots-display-profiles/pause"
st=$(run_watcher events-burst.txt)
[[ $(profile_calls) -ge 1 ]] || fail "garbage must not block the apply"
rm -f "$SANDBOX/kooldots-display-profiles/pause"
pass_msg

# --- configreloaded --------------------------------------------------------
it "configreloaded re-applies the layout that is running, not the set default"
printf 'FP\nWork\n' >"$SANDBOX/kooldots-display-profiles/current"
st=$(run_watcher events-configreloaded.txt)
assert_status 0 "$st" "watcher exit"
assert_contains "$PROFILE_LOG" "-- Work" && pass_msg

it "configreloaded with no recorded layout falls back to auto"
rm -f "$SANDBOX/kooldots-display-profiles/current"
st=$(run_watcher events-configreloaded.txt)
[[ $(grep -c '^auto$' "$PROFILE_LOG") -ge 1 ]] || fail "expected an auto call: $(cat "$PROFILE_LOG")"
pass_msg

it "configreloaded with a generated layout recorded falls back to auto"
printf 'FP\n(auto)\n' >"$SANDBOX/kooldots-display-profiles/current"
st=$(run_watcher events-configreloaded.txt)
assert_not_contains "$PROFILE_LOG" "-- (auto)" "a generated layout has no name to re-apply"
[[ $(grep -c '^auto$' "$PROFILE_LOG") -ge 1 ]] || fail "expected an auto call"
rm -f "$SANDBOX/kooldots-display-profiles/current"
pass_msg

it "a monitor change still uses auto, not the recorded layout"
printf 'FP\nWork\n' >"$SANDBOX/kooldots-display-profiles/current"
st=$(run_watcher events-burst.txt)
assert_not_contains "$PROFILE_LOG" "-- Work" "a new monitor set must be resolved afresh"
rm -f "$SANDBOX/kooldots-display-profiles/current"
pass_msg

it "configreloaded is also ignored while paused"
sleep 30 & live2=$!
printf '%s\n' "$live2" >"$SANDBOX/kooldots-display-profiles/pause"
st=$(run_watcher events-configreloaded.txt)
kill "$live2" 2>/dev/null || true
rm -f "$SANDBOX/kooldots-display-profiles/pause"
[[ $(profile_calls) == 0 ]] || fail "expected no calls while paused, got $(profile_calls)"
pass_msg

it "the controller is still called with the lock descriptor closed"
if sed 's/#.*$//' "$SCRIPT" | grep -nE '^[^=]*"\$MW_PROFILE_SCRIPT"' | grep -qv '9>&-'; then
  fail "a controller call does not close fd 9: $(grep -nE '^[^=]*"\$MW_PROFILE_SCRIPT"' "$SCRIPT" | grep -v '9>&-')"
else pass_msg; fi

summary "test-monitor-watcher"
