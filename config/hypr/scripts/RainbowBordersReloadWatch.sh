#!/usr/bin/env bash
# ==================================================
#  KoolDots (2026)
#  Project URL: https://github.com/LinuxBeginnings
#  License: GNU GPLv3
#  SPDX-License-Identifier: GPL-3.0-or-later
# ==================================================
# Re-apply the Rainbow Borders mode after a config reload.
#
# Why this exists
# ---------------
# A reload re-runs the config, and the config never sets
# `general:col.active_border`: `lua/decorations.lua` is a template and is
# deliberately not loaded. So every reload put the border back to the default
# `ffffffff 0deg`, and a selected mode - or the one-shot from SUPER SHIFT B -
# disappeared until the next wallpaper change, because only WallustSwww.sh
# re-applied it, and only when a wallpaper resolved.
#
# `RainbowBordersStartup.sh` already applies the recorded mode, and is the one
# implementation every caller uses. This listener is the missing caller: it
# subscribes to the Hyprland event socket and runs it on `configreloaded`.
#
# Started from lua/startup.lua unconditionally, because a mode can be selected
# from Quick Settings at any point in the session and the listener has to be
# there when it is. It costs one idle `socat` blocked on the event socket.
#
# Design notes
# ------------
# * socat feeds a FIFO rather than a pipeline, so a SIGTERM is handled while it
#   is blocked on the socket. Same reason as LuaConfigWatch.sh.
# * The socket path is re-resolved on every reconnect: a Hyprland restart
#   allocates a new instance signature, so a cached path never comes back.
# * A reload burst is settled first, so one reload re-applies the mode once.
# * No `set -e`: a failed re-apply must not end the listener for the session.

set -uo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=HyprIPC.sh
. "$script_dir/HyprIPC.sh" 2>/dev/null || true

startup_script="${RBW_STARTUP_SCRIPT:-${XDG_CONFIG_HOME:-$HOME/.config}/hypr/scripts/RainbowBordersStartup.sh}"
runtime_dir="${XDG_RUNTIME_DIR:-/tmp}"
pidfile="$runtime_dir/kooldots-rainbow-reload-watch.pid"
fifo="$runtime_dir/kooldots-rainbow-reload-watch.fifo"
log="$runtime_dir/kooldots-rainbow-reload-watch.log"
reconnect_delay="${RBW_RECONNECT_DELAY:-2}"
settle_time="${RBW_SETTLE:-0.5}"
socat_bin="${RBW_SOCAT:-socat}"
# Tests feed a fixture instead of the live socket.
event_file="${RBW_EVENT_FILE:-}"
event_linger="${RBW_EVENT_LINGER:-}"

reader_pid=""
failures=0

log_line() {
  printf '%s [RainbowBordersReloadWatch] %s\n' "$(date '+%H:%M:%S')" "$*" >>"$log" 2>/dev/null || true
}

# event_socket: the socket2 path, re-resolved on every call.
event_socket() {
  if command -v hypr_socket_path >/dev/null 2>&1 && hypr_socket_path socket2; then
    return 0
  fi
  local runtime="${XDG_RUNTIME_DIR:-/run/user/$(id -u)}" sig_dir candidate newest=""
  for sig_dir in "$runtime"/hypr/*/; do
    candidate="${sig_dir}.socket2.sock"
    [ -S "$candidate" ] || continue
    if [ -z "$newest" ] || [ "$candidate" -nt "$newest" ]; then
      newest="$candidate"
    fi
  done
  [ -n "$newest" ] || return 1
  printf '%s\n' "$newest"
}

# stream_events: the live event stream, or a fixture for the tests.
stream_events() {
  if [ -n "$event_file" ]; then
    cat -- "$event_file"
    # Keeps the subshell alive after a drained fixture, the way a real socat
    # stays blocked on the socket.
    [ -n "$event_linger" ] && sleep "$event_linger"
    return 0
  fi
  local socket
  socket="$(event_socket)" || return 1
  [ -S "$socket" ] || return 1
  "$socat_bin" -U - "UNIX-CONNECT:$socket"
}

apply_mode() {
  if [ ! -x "$startup_script" ]; then
    log_line "WARN: no executable $startup_script; nothing re-applied"
    return 1
  fi
  if "$startup_script" >/dev/null 2>&1; then
    log_line "re-applied the Rainbow Borders mode after a config reload"
    return 0
  fi
  log_line "WARN: $startup_script failed"
  return 1
}

# settle: swallow the rest of a reload burst, so one reload re-applies once.
settle() {
  local extra
  while IFS= read -r -t "$settle_time" extra; do :; done
}

# watch_once: one connection. Always returns 1 so the caller reconnects.
watch_once() {
  rm -f "$fifo"
  mkfifo "$fifo" 2>/dev/null || return 1
  # `exec 3>&-` in the subshell, not a redirection on the call: bash saves and
  # restores a redirected descriptor, and the saved copy would keep this
  # process's descriptors alive for as long as the stream does.
  (exec 3>&-; stream_events) >"$fifo" 2>/dev/null &
  reader_pid=$!

  local line
  while :; do
    if IFS= read -r -t 5 line; then
      case "$line" in
      configreloaded'>>'* | configreloaded)
        settle
        apply_mode
        ;;
      esac
      continue
    fi
    # Bounded read, so there is a chance to notice the stream is gone.
    kill -0 "$reader_pid" 2>/dev/null || break
  done <"$fifo"

  kill "$reader_pid" 2>/dev/null
  wait "$reader_pid" 2>/dev/null
  reader_pid=""
  rm -f "$fifo"
  return 1
}

cleanup() {
  [ -n "$reader_pid" ] && kill "$reader_pid" 2>/dev/null
  rm -f "$pidfile" "$fifo"
}
trap cleanup EXIT
trap 'exit 143' INT TERM

# Single instance per user: a second listener would re-apply twice per reload.
if [ -f "$pidfile" ]; then
  old_pid="$(cat "$pidfile" 2>/dev/null || true)"
  if [ -n "$old_pid" ] && [ "$old_pid" != "$$" ] && kill -0 "$old_pid" 2>/dev/null; then
    exit 0
  fi
fi
printf '%d' "$$" >"$pidfile"

: >"$log"
log_line "watching for configreloaded (mode script: $startup_script)"

while :; do
  watch_once || true
  failures=$((failures + 1))
  if [ "$failures" -eq 1 ] || [ $((failures % 30)) -eq 0 ]; then
    log_line "event stream unavailable; retrying (attempt $failures)"
  fi
  sleep "$reconnect_delay"
done
