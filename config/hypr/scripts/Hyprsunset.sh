#!/usr/bin/env bash
# ==================================================
#  KoolDots (2026)
#  Project URL: https://github.com/LinuxBeginnings
#  License: GNU GPLv3
#  SPDX-License-Identifier: GPL-3.0-or-later
# ==================================================
set -euo pipefail

# Hyprsunset toggle + Waybar status helper
# Phase 1: manual toggle only (no scheduling)
# Icons:
# - Off: bright sun
# - On: sunset icon if available, otherwise a blue sun
#
# Customize via env vars:
#   HYPRSUNSET_TEMP   default 4500 (K)
#   HYPRSUNSET_ICON_MODE  sunset|blue  (default: sunset)

STATE_FILE="$HOME/.cache/.hyprsunset_state"
TARGET_TEMP="${HYPRSUNSET_TEMP:-4500}"
ICON_MODE="${HYPRSUNSET_ICON_MODE:-sunset}"

ensure_state() {
  mkdir -p "$(dirname "$STATE_FILE")"
  [[ -f "$STATE_FILE" ]] || echo "off" > "$STATE_FILE"
}

stop_hyprsunset() {
  if pgrep -x hyprsunset >/dev/null 2>&1; then
    pkill -x hyprsunset 2>/dev/null || true
    for _ in {1..5}; do
      pgrep -x hyprsunset >/dev/null 2>&1 || return 0
      sleep 0.1
    done
    if pgrep -x hyprsunset >/dev/null 2>&1; then
      pkill -9 -x hyprsunset 2>/dev/null || true
      sleep 0.1
    fi
  fi
}

# Render icons using pango markup to allow colorization
icon_off() {
  # universally available sun symbol
  printf "☀"
}

icon_on() {
  case "$ICON_MODE" in
    sunset)
      # sunset emoji (falls back to tofu if no emoji font)
      printf "🌇"
      ;;
    blue)
      # no color in text; rely on CSS .on to style if desired
      printf "☀"
      ;;
    *)
      printf "☀"
      ;;
  esac
}

cmd_on() {
  ensure_state
  if command -v hyprsunset >/dev/null 2>&1; then
    # If already running, use IPC to set temperature without restart/flicker
    if pgrep -x hyprsunset >/dev/null 2>&1 && hyprctl hyprsunset temperature "$TARGET_TEMP" >/dev/null 2>&1; then
      :
    else
      # Otherwise ensure any stale process is cleaned up and start fresh
      stop_hyprsunset
      nohup hyprsunset -t "$TARGET_TEMP" >/dev/null 2>&1 &
    fi
  fi
  echo on > "$STATE_FILE"
  notify-send -u low "Hyprsunset: Enabled" "${TARGET_TEMP}K" || true
}

cmd_off() {
  ensure_state
  if command -v hyprsunset >/dev/null 2>&1; then
    if pgrep -x hyprsunset >/dev/null 2>&1; then
      # Reset CTM to identity via IPC so Hyprland restores normal screen colors
      if hyprctl hyprsunset identity >/dev/null 2>&1; then
        sleep 0.1
      else
        # Fallback if IPC failed: terminate and briefly run hyprsunset -i to apply identity
        stop_hyprsunset
        nohup hyprsunset -i >/dev/null 2>&1 &
        sleep 0.3
      fi
      stop_hyprsunset
    fi
  fi
  echo off > "$STATE_FILE"
  notify-send -u low "Hyprsunset: Disabled" || true
}

cmd_toggle() {
  ensure_state
  state="$(cat "$STATE_FILE" 2>/dev/null || echo off)"

  if [[ "$state" == "on" ]]; then
    cmd_off
  else
    # If state file says off but process is running, turn it off
    if pgrep -x hyprsunset >/dev/null 2>&1; then
      cmd_off
    else
      cmd_on
    fi
  fi
}

cmd_status() {
  ensure_state
  state="$(cat "$STATE_FILE" 2>/dev/null || echo off)"

  # Active only when state file is on AND process is running
  if [[ "$state" == "on" ]] && pgrep -x hyprsunset >/dev/null 2>&1; then
    onoff="on"
  else
    onoff="off"
  fi

  if [[ "$onoff" == "on" ]]; then
    txt="<span size='18pt'>$(icon_on)</span>"
    cls="on"
    tip="Night light on @ ${TARGET_TEMP}K"
  else
    txt="<span size='16pt'>$(icon_off)</span>"
    cls="off"
    tip="Night light off"
  fi
  printf '{"text":"%s","class":"%s","tooltip":"%s"}\n' "$txt" "$cls" "$tip"
}

cmd_init() {
  ensure_state
  state="$(cat "$STATE_FILE" 2>/dev/null || echo off)"

  if [[ "$state" == "on" ]]; then
    if command -v hyprsunset >/dev/null 2>&1; then
      if pgrep -x hyprsunset >/dev/null 2>&1 && hyprctl hyprsunset temperature "$TARGET_TEMP" >/dev/null 2>&1; then
        :
      else
        stop_hyprsunset
        nohup hyprsunset -t "$TARGET_TEMP" >/dev/null 2>&1 &
      fi
    fi
  else
    # State is off; ensure no lingering hyprsunset process from a previous session
    if pgrep -x hyprsunset >/dev/null 2>&1; then
      hyprctl hyprsunset identity >/dev/null 2>&1 || true
      sleep 0.1
      stop_hyprsunset
    fi
  fi
}

case "${1:-}" in
  toggle) cmd_toggle ;;
  status) cmd_status ;;
  init) cmd_init ;;
  on) cmd_on ;;
  off) cmd_off ;;
  *) echo "usage: $0 [toggle|status|init|on|off]" >&2; exit 2 ;;
esac
