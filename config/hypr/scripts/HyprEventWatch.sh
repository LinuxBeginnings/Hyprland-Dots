#!/usr/bin/env bash
# ==================================================
#  KoolDots (2026)
#  Project URL: https://github.com/LinuxBeginnings
#  License: GNU GPLv3
#  SPDX-License-Identifier: GPL-3.0-or-later
# ==================================================
# Long-running Waybar producer driven by the Hyprland event socket.
#
# These status modules used to run their renderer on a Waybar `interval`, which
# forked `hyprctl`, a `jq` and one or two bash processes on a timer for the life
# of the session - about 4.5 `hyprctl` + 4.5 `jq` forks per second between the
# layout and keyboard modules, to redraw two labels that only change when the
# user acts.
#
# This subscribes to `.socket2.sock` instead and prints a new line only when the
# state it displays actually changed. A layout or keyboard switch costs one
# socket request; an idle session costs nothing.
#
# Usage: HyprEventWatch.sh layout|keyboard
#   layout   -> Waybar JSON for the active workspace's tiling layout
#   keyboard -> plain text for the active keyboard layout

set -uo pipefail
# Deliberately no `set -e`: the reconnect loop must survive a socket that goes
# away when Hyprland restarts, and a failed render must not end the listener.

SCRIPTSDIR="${XDG_CONFIG_HOME:-$HOME/.config}/hypr/scripts"
# shellcheck source=HyprIPC.sh
. "$SCRIPTSDIR/HyprIPC.sh"

mode="${1:-layout}"
case "$mode" in
layout | keyboard) ;;
*)
  printf 'Usage: %s [layout|keyboard]\n' "$(basename "$0")" >&2
  exit 2
  ;;
esac

# Devices that must never win the "active keyboard" race: AVRCP media
# pseudo-keyboards and similar. Same intent as the ignore list in
# KeyboardLayout.sh, so the two cannot disagree about which keyboard is shown.
KEYBOARD_IGNORE_RE='--\(avrcp\)|Bluetooth Speaker|Other Device'

# Single-instance guard, per mode. Waybar kills and re-runs a module's exec on
# a signal, so a leftover instance would otherwise keep a second socket reader
# alive for the rest of the session.
RUNTIME_DIR="${XDG_RUNTIME_DIR:-/tmp}"
pidfile="$RUNTIME_DIR/hypr-event-watch-$mode.pid"
fifo="$RUNTIME_DIR/hypr-event-watch-$mode.fifo"
socat_pid=""

if [ -f "$pidfile" ]; then
  oldpid="$(cat "$pidfile" 2>/dev/null || true)"
  if [ -n "$oldpid" ] && kill -0 "$oldpid" 2>/dev/null; then
    kill "$oldpid" 2>/dev/null || true
    sleep 0.1 || true
  fi
fi
printf '%d' $$ >"$pidfile"

cleanup() {
  [ -n "$socat_pid" ] && kill "$socat_pid" 2>/dev/null
  # Reap anything else of ours, so a Waybar restart cannot leak a reader.
  pkill -P "$$" 2>/dev/null || true
  rm -f "$pidfile" "$fifo"
}
# Waybar terminates a module's exec with SIGTERM when it restarts the module or
# the bar. A bare `trap cleanup TERM` would swallow the signal and leave this
# process (and its socat) running for the rest of the session, so exit on it.
trap cleanup EXIT
trap 'exit 143' INT TERM

# --- renderers --------------------------------------------------------------

# The layout module owns the icon/tooltip/class rendering; it reads the socket
# itself now, so this stays the single source of truth for how the label looks.
render_layout() {
  "$SCRIPTSDIR/HyprLayoutModule.sh" status 2>/dev/null || true
}

# KeyboardLayout.sh resolves the layout with four `hyprctl devices -j | jq`
# calls, which is why it was too expensive to poll. One socket request gives the
# same answer, and only when the layout actually changed.
#
# All of the field picking happens inside jq. Splitting the reply on tabs in
# bash would be wrong: a tab counts as IFS whitespace, so an empty variant
# collapses into the next field and the index leaks into the label.
render_keyboard() {
  local devices short

  devices="$(hypr_request 'j/devices')" || return 0
  [ -n "$devices" ] || return 0

  short="$(jq -r --arg ignore "$KEYBOARD_IGNORE_RE" '
    [ .keyboards[]? | select((.name // "") | test($ignore) | not) ][0]
    | (.layout // "") as $layouts
    | (.variant // "") as $variants
    | (.active_layout_index // 0 | tonumber? // 0) as $index
    | ($layouts | split(",")) as $l
    | ($variants | split(",")) as $v
    | "\($l[$index] // "")\(if ($v[$index] // "") != "" then "(" + $v[$index] + ")" else "" end)"
  ' <<<"$devices" 2>/dev/null)" || return 0
  [ -n "$short" ] || return 0

  printf '%s\n' "$short"
}

render() {
  case "$mode" in
  layout) render_layout ;;
  keyboard) render_keyboard ;;
  esac
  return 0
}

# --- event filter -----------------------------------------------------------

case "$mode" in
layout)
  # A workspace carries its own layout, so a workspace or monitor switch can
  # change the label too. A layout change produces no event of its own, so
  # ChangeLayout.sh and the layout menu push one in with hypr_emit_event, which
  # arrives as `custom>>kool:layout`.
  event_re='^(custom|workspace|workspacev2|focusedmon|monitoradded|monitorremoved|configreloaded)>>'
  ;;
keyboard)
  event_re='^activelayout>>'
  ;;
esac

render

# Re-resolve the socket on every reconnect: a Hyprland restart allocates a new
# instance signature, so a cached path would never come back.
#
# socat feeds a FIFO instead of a pipeline. In `socat | while read`, the shell is
# blocked waiting on the pipeline, so a SIGTERM is only handled once socat
# exits - which it never does on its own. Reading the FIFO from the main shell
# keeps the signal handler responsive.
while :; do
  socket="$(hypr_socket_path socket2)" || {
    sleep 1
    continue
  }

  rm -f "$fifo"
  if ! mkfifo "$fifo" 2>/dev/null; then
    sleep 1
    continue
  fi

  socat -U - "UNIX-CONNECT:$socket" >"$fifo" 2>/dev/null &
  socat_pid=$!

  while IFS= read -r line; do
    [[ "$line" =~ $event_re ]] || continue
    render
  done <"$fifo"

  kill "$socat_pid" 2>/dev/null || true
  wait "$socat_pid" 2>/dev/null || true
  socat_pid=""
  rm -f "$fifo"

  # Socket closed (Hyprland restarting, or the instance went away): wait a beat
  # and resubscribe rather than spinning.
  sleep 1
done
