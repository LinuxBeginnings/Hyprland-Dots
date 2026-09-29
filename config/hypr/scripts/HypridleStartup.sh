#!/usr/bin/env bash
# ==================================================
#  KoolDots (2026)
#  Project URL: https://github.com/LinuxBeginnings
#  License: GNU GPLv3
#  SPDX-License-Identifier: GPL-3.0-or-later
# ==================================================
# Start hypridle exactly once and remove stray duplicate daemons.
#
# Why this exists:
# Every hypridle instance registers its own logind sleep "delay" inhibitor, so a
# second daemon doubles the suspend path's inhibitor handling (and registers the
# idle listeners twice). Two appeared whenever the distro's hypridle.service was
# already active and startup.lua also launched a bare `hypridle`.
#
# The systemd user unit (when present) is the canonical owner: an instance whose
# cgroup is not the unit's is a stray copy and is terminated. Where no unit
# exists hypridle is launched directly and the oldest instance is kept.
#
# Usage:
#   HypridleStartup.sh               start if missing, then de-duplicate
#   HypridleStartup.sh --dedupe-only only de-duplicate (for patches/updates)

set -uo pipefail

RUNTIME_DIR="${XDG_RUNTIME_DIR:-/run/user/$(id -u)}"
LOGFILE="$RUNTIME_DIR/hypridle-startup.log"

mode="start"
case "${1:-}" in
  --dedupe-only | -d) mode="dedupe-only" ;;
esac

log() {
  printf '%s - %s\n' "$(date '+%Y-%m-%d %H:%M:%S')" "$*" >>"$LOGFILE" 2>/dev/null || true
}

instance_pids() {
  pgrep -x hypridle 2>/dev/null || true
}

wait_for_hypridle() {
  local i
  for i in $(seq 1 50); do
    [ -n "$(instance_pids)" ] && return 0
    sleep 0.1
  done
  return 1
}

start_hypridle() {
  if [ -n "$(instance_pids)" ]; then
    return 0
  fi

  if command -v systemctl >/dev/null 2>&1 &&
    systemctl --user cat hypridle.service >/dev/null 2>&1; then
    systemctl --user start hypridle.service >/dev/null 2>&1 || true
    wait_for_hypridle && return 0
  fi

  command -v hypridle >/dev/null 2>&1 || return 1
  hypridle >/dev/null 2>&1 &
  wait_for_hypridle
}

# Keep a single daemon: the unit-owned instance when present, otherwise the
# oldest one. Returns 0 whether or not anything had to be terminated.
dedupe_hypridle() {
  local pids count keep p cgroup
  pids="$(instance_pids)"
  [ -n "$pids" ] || return 0

  count="$(printf '%s\n' "$pids" | wc -l | tr -d ' ')"
  [ "$count" -gt 1 ] || return 0

  keep=""
  for p in $pids; do
    cgroup="$(cat "/proc/$p/cgroup" 2>/dev/null || true)"
    case "$cgroup" in
      *hypridle.service*)
        keep="$p"
        break
        ;;
    esac
  done
  [ -n "$keep" ] || keep="$(printf '%s\n' "$pids" | sort -n | head -n1)"

  log "duplicate hypridle instances [$(printf '%s' "$pids" | tr '\n' ' ')]; keeping $keep"

  for p in $pids; do
    [ "$p" = "$keep" ] && continue
    kill -TERM "$p" >/dev/null 2>&1 || true
  done
  sleep 1
  for p in $pids; do
    [ "$p" = "$keep" ] && continue
    if kill -0 "$p" >/dev/null 2>&1; then
      kill -KILL "$p" >/dev/null 2>&1 || true
    fi
  done

  return 0
}

if [ "$mode" = "start" ]; then
  start_hypridle
fi
dedupe_hypridle
exit 0
