#!/usr/bin/env bash
# ==================================================
#  KoolDots (2026)
#  Project URL: https://github.com/LinuxBeginnings
#  License: GNU GPLv3
#  SPDX-License-Identifier: GPL-3.0-or-later
# ==================================================
# Hyprland IPC helpers shared by the Waybar status modules.
#
# Talking to the Hyprland sockets directly avoids forking `hyprctl` (and the
# `jq` next to it) for every status update. `hyprctl` is a thin client over
# these same sockets, so the payloads are identical.
#
# Source this file; do not execute it.

# Directory that holds the current Hyprland instance sockets.
hypr_runtime_dir() {
  printf '%s\n' "${XDG_RUNTIME_DIR:-/run/user/$(id -u)}/hypr"
}

# Instance signature of a live Hyprland. Re-resolved on every call, because the
# signature changes when Hyprland restarts, which invalidates a cached path.
hypr_instance_signature() {
  local runtime_dir sig_dir

  runtime_dir="$(hypr_runtime_dir)"

  if [ -n "${HYPRLAND_INSTANCE_SIGNATURE:-}" ] \
    && [ -S "$runtime_dir/$HYPRLAND_INSTANCE_SIGNATURE/.socket.sock" ]; then
    printf '%s\n' "$HYPRLAND_INSTANCE_SIGNATURE"
    return 0
  fi

  # Stale signature (Hyprland was restarted) or none in the environment: take
  # the first instance that actually has a live socket.
  for sig_dir in "$runtime_dir"/*/; do
    [ -S "${sig_dir}.socket.sock" ] || continue
    printf '%s\n' "$(basename "$sig_dir")"
    return 0
  done

  return 1
}

# hypr_socket_path <socket1|socket2>
#   socket1 = request/response, socket2 = event stream
hypr_socket_path() {
  local kind="${1:-socket1}" sig

  sig="$(hypr_instance_signature)" || return 1

  case "$kind" in
  socket2)
    printf '%s\n' "$(hypr_runtime_dir)/$sig/.socket2.sock"
    ;;
  *)
    printf '%s\n' "$(hypr_runtime_dir)/$sig/.socket.sock"
    ;;
  esac
}

# hypr_request <request>
#   e.g. hypr_request 'j/activeworkspace'
# Prints the raw reply, or nothing when no instance is reachable.
hypr_request() {
  local socket

  command -v socat >/dev/null 2>&1 || return 1
  socket="$(hypr_socket_path socket1)" || return 1

  printf '%s' "$1" | socat - "UNIX-CONNECT:$socket" 2>/dev/null
}
