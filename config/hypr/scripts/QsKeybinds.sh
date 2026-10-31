#!/usr/bin/env bash
# ==================================================
#  KoolDots (2026)
#  Project URL: https://github.com/LinuxBeginnings
#  License: GNU GPLv3
#  SPDX-License-Identifier: GPL-3.0-or-later
# ==================================================
# Toggle the Quickshell keybind panel (~/.config/quickshell/keybinds).
#
# Subcommands:
#   toggle | open | close   show or hide the panel, starting it if needed
#   refresh                 ask the shell to re-read the bind list
#
# Nothing is gathered here. The panel reads the live bind list that
# hypr/lua/keybind_index.lua publishes - the same list KeyBinds.sh hands to
# rofi - so this script only drives the panel.
#
# Quickshell is not on every supported distro. Where it is missing the script
# says so and exits, which leaves the keybind inert instead of broken.

set -u

config_home="${XDG_CONFIG_HOME:-$HOME/.config}"
# The panel installs with the rest of the quickshell tree, not under hypr/.
# QsNetworkPanel.sh derives its path from the script location, which resolves to
# <hypr>/quickshell/<applet> - a directory that does not exist on an installed
# system. This path is stated outright instead of derived.
widget_dir="$config_home/quickshell/keybinds"
qs_target="keybinds"

have() { command -v "$1" >/dev/null 2>&1; }

notify() {
  have notify-send && notify-send -a "Keybinds" "$1" "$2" >/dev/null 2>&1
  return 0
}

qs_ipc() { quickshell ipc -p "$widget_dir" call "$qs_target" "$@" >/dev/null 2>&1; }

launch_panel() {
  if ! have quickshell; then
    notify "Keybind panel" "Quickshell is not installed."
    printf 'quickshell is not installed\n' >&2
    return 1
  fi

  if [ ! -f "$widget_dir/shell.qml" ]; then
    notify "Keybind panel" "Not installed: $widget_dir"
    printf 'no shell at %s\n' "$widget_dir" >&2
    return 1
  fi

  quickshell -p "$widget_dir" --daemonize >/dev/null 2>&1

  local attempt
  for attempt in $(seq 1 50); do
    sleep 0.1
    qs_ipc isOpen && return 0
  done

  notify "Keybind panel" "Quickshell did not start. See 'quickshell -p $widget_dir'."
  printf 'quickshell did not start\n' >&2
  return 1
}

case "${1:-toggle}" in
  toggle)
    qs_ipc toggle && exit 0
    launch_panel || exit 1
    qs_ipc open
    ;;
  open)
    qs_ipc open || { launch_panel && qs_ipc open; }
    ;;
  close)
    qs_ipc close
    ;;
  refresh)
    qs_ipc refresh
    ;;
  *)
    printf 'usage: %s [toggle|open|close|refresh]\n' "$0" >&2
    exit 2
    ;;
esac
