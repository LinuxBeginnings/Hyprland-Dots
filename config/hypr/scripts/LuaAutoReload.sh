#!/usr/bin/env bash
# ==================================================
#  KoolDots (2026)
#  Project URL: https://github.com/LinuxBeginnings
#  License: GNU GPLv3
#  SPDX-License-Identifier: GPL-3.0-or-later
# ==================================================
# Auto-reload Hyprland when Lua config files change.

set -euo pipefail

watch_root="${XDG_CONFIG_HOME:-$HOME/.config}/hypr"
[ -d "$watch_root" ] || exit 0
session="${HYPRLAND_INSTANCE_SIGNATURE:-default}"
pid_file="/tmp/hypr-lua-autoreload-${session}.pid"

if [ -f "$pid_file" ]; then
  existing_pid="$(cat "$pid_file" 2>/dev/null || true)"
  if [ -n "$existing_pid" ] && kill -0 "$existing_pid" 2>/dev/null; then
    exit 0
  fi
fi

echo "$$" >"$pid_file"
cleanup() {
  rm -f "$pid_file"
}
trap cleanup EXIT INT TERM

reload_hypr() {
  hyprctl reload >/dev/null 2>&1 || true
}

if command -v inotifywait >/dev/null 2>&1; then
  debounce_and_reload() {
    sleep 0.2
    while inotifywait -q -t 0.2 -e close_write,create,move,delete -r --include '(^|/)[^/]+\.lua$' "$watch_root" >/dev/null 2>&1; do
      :
    done
    reload_hypr
  }

  inotifywait -m -q -r -e close_write,create,move,delete --include '(^|/)[^/]+\.lua$' "$watch_root" | while read -r _; do
    debounce_and_reload
  done
  exit 0
fi

# Fallback polling path when inotify-tools isn't installed.
snapshot() {
  find "$watch_root" -type f -name '*.lua' -printf '%p:%T@\n' 2>/dev/null | LC_ALL=C sort
}

previous_state="$(snapshot)"
while true; do
  sleep 1
  current_state="$(snapshot)"
  if [ "$current_state" != "$previous_state" ]; then
    previous_state="$current_state"
    reload_hypr
  fi
done
