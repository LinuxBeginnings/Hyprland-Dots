#!/usr/bin/env bash
# ==================================================
#  KoolDots (2026)
#  Project URL: https://github.com/LinuxBeginnings
#  License: GNU GPLv3
#  SPDX-License-Identifier: GPL-3.0-or-later
# ==================================================
# Purpose:
#   Tests that TerminalSignal.sh signals the terminal application and never a
#   CLI invocation of it.
#
#   `pidof` matches argv[0], not the executable, so `ghostty +list-themes`
#   answers `pidof ghostty` alongside the running terminal. Ghostty_themes.sh
#   and GhosttyThemeGuard.sh both run that subcommand and decide what to offer
#   from the result, so signalling it left the theme list empty and the guard
#   then commented out a theme that was installed.
#
#   The fakes here are real processes whose argv[0] is rewritten by `exec -a`,
#   which is all pidof needs. Two details decide whether a fake is even
#   visible, and getting either wrong makes an assertion pass for the wrong
#   reason:
#     - pidof skips a process whose executable is a shell unless given -x, so
#       the fakes must not be shell wrappers
#     - the marker has to survive in argv, and `sleep 60 +list-themes` exits on
#       the invalid duration, so `tail -f` carries the marker instead
#   That is what the liveness guard below is for: a fake that already exited,
#   or that pidof cannot see, would pass "not listed" vacuously.
#   SIGUSR2 terminates by default, so "was it signalled" is answered by
#   whether the process is still there.
# No `set -e`: the assertion helpers return non-zero on failure, and exiting on
# the first one would hide every later check in the run.
set -uo pipefail
HERE="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=./lib_test.sh
source "$HERE/lib_test.sh"

HELPER="$SCRIPT_DIR/TerminalSignal.sh"
# shellcheck source=/dev/null
source "$HELPER"

# Unique so a real terminal of the same name cannot answer for it.
NAME="zzkooldotsterm"
WORK="$(mktemp -d)"

cleanup() {
  local f p
  for f in "$WORK"/*.pid; do
    [ -f "$f" ] || continue
    p="$(cat "$f" 2>/dev/null || true)"
    if [ -n "$p" ]; then kill -TERM "$p" 2>/dev/null || true; fi
  done
  rm -rf -- "$WORK"
}
trap cleanup EXIT

# start_fake <pidfile> <command> [args...]
# Runs the command with argv[0] rewritten to $NAME. The command must not be a
# shell, or pidof will not report it and the fake is invisible rather than
# filtered.
start_fake() {
  local pidfile="$1"
  shift
  bash -c 'exec -a "$0" "${@:1}"' "$NAME" "$@" >/dev/null 2>&1 &
  printf '%s\n' "$!" >"$pidfile"
}

wait_for_pid() { # wait_for_pid <pid> [tries]
  local pid="$1" tries="${2:-60}"
  while [ "$tries" -gt 0 ]; do
    kill -0 "$pid" 2>/dev/null && return 0
    sleep 0.05
    tries=$((tries - 1))
  done
  return 1
}

# started <pidfile> <label> - fails rather than letting a fake pass a "not
# listed" assertion for the wrong reason. Two ways that happens: the process
# died, or pidof cannot see it in the first place.
started() {
  local pidfile="$1" label="$2" pid
  pid="$(cat "$pidfile")"
  if ! wait_for_pid "$pid"; then
    fail "the fake $label process never started"
    return 1
  fi
  if ! pidof "$NAME" 2>/dev/null | tr ' ' '\n' | grep -qx -- "$pid"; then
    fail "pidof cannot see the fake $label process, so 'not listed' would be vacuous"
    return 1
  fi
  return 0
}

# --- the application is listed, a + subcommand is not ----------------------
it "the application is listed"
start_fake "$WORK/app.pid" sleep 60
app_pid="$(cat "$WORK/app.pid")"
started "$WORK/app.pid" "application" || true

listed="$(terminal_app_pids "$NAME" 2>/dev/null || true)"
assert_contains "$listed" "$app_pid" "the application PID is listed"

it "a + subcommand is not listed"
start_fake "$WORK/plus.pid" tail -f /dev/null +list-themes
plus_pid="$(cat "$WORK/plus.pid")"
started "$WORK/plus.pid" "+list-themes" || true

listed="$(terminal_app_pids "$NAME" 2>/dev/null || true)"
assert_not_contains "$listed" "$plus_pid" "the +list-themes PID is skipped"

it "an @ remote-control invocation is not listed"
start_fake "$WORK/at.pid" tail -f /dev/null @load-config
at_pid="$(cat "$WORK/at.pid")"
started "$WORK/at.pid" "@load-config" || true

listed="$(terminal_app_pids "$NAME" 2>/dev/null || true)"
assert_not_contains "$listed" "$at_pid" "the @load-config PID is skipped"

# --- signalling reaches the application and misses the subcommands --------
it "signalling reaches the application"
signal_terminal_app "$NAME" SIGUSR2 || true
sleep 0.4
if kill -0 "$app_pid" 2>/dev/null; then
  fail "the application is still running, so it was never signalled"
else
  pass_msg
fi

it "signalling leaves the + subcommand alone"
if kill -0 "$plus_pid" 2>/dev/null; then
  pass_msg
else
  fail "the +list-themes invocation was signalled"
fi

it "signalling leaves the @ invocation alone"
if kill -0 "$at_pid" 2>/dev/null; then
  pass_msg
else
  fail "the @load-config invocation was signalled"
fi

# --- nothing running is not an error worth signalling on -------------------
it "terminal_app_pids returns non-zero when nothing matches"
if terminal_app_pids "$NAME-absent" >/dev/null 2>&1; then
  fail "expected non-zero for an application that is not running"
else
  pass_msg
fi

it "signal_terminal_app returns non-zero when nothing matches"
if signal_terminal_app "$NAME-absent" SIGUSR2 >/dev/null 2>&1; then
  fail "expected non-zero for an application that is not running"
else
  pass_msg
fi

summary "test-terminal-signal"
