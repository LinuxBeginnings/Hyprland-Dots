#!/usr/bin/env bash
# ==================================================
#  KoolDots (2026)
#  Project URL: https://github.com/LinuxBeginnings
#  License: GNU GPLv3
#  SPDX-License-Identifier: GPL-3.0-or-later
# ==================================================
# Open the keybind menu: the Quickshell panel (~/.config/quickshell/keybinds)
# where it can run, the rofi menu (scripts/KeyBinds.sh) where it cannot.
#
# Subcommands:
#   toggle | open | close   show or hide the menu, starting the panel if needed
#   refresh                 ask the shell to re-read the bind list
#   which                   print the menu that would open (quickshell|rofi)
#
# Nothing is gathered here. The panel reads the live bind list that
# hypr/lua/keybind_index.lua publishes - the same list KeyBinds.sh hands to
# rofi - so this script only drives the panel.
#
# Quickshell is not available on every supported distro; the Ubuntu 24.04 based
# installs are the ones that lack it. A keybind that only drove the panel would
# be dead there, so one entry point reaches both: the panel when it can start,
# rofi when it cannot.

set -u

config_home="${XDG_CONFIG_HOME:-$HOME/.config}"
# The panel installs with the rest of the quickshell tree, not under hypr/.
# QsNetworkPanel.sh derives its directory from its own location, which works but
# ties the script to the shape of the tree. This path is stated outright instead,
# so moving the script cannot silently point the shell at a directory that is
# not there.
widget_dir="$config_home/quickshell/keybinds"
qs_target="keybinds"
rofi_script="$config_home/hypr/scripts/KeyBinds.sh"

have() { command -v "$1" >/dev/null 2>&1; }

notify() {
  have notify-send && notify-send -a "Keybinds" "$1" "$2" >/dev/null 2>&1
  return 0
}

qs_ipc() { quickshell ipc -p "$widget_dir" call "$qs_target" "$@" >/dev/null 2>&1; }

# The panel needs the binary and its QML: quickshell installed with the applet
# missing is the same dead end as no quickshell at all.
panel_available() {
  have quickshell && [ -f "$widget_dir/shell.qml" ]
}

# The rofi menu this keybind used before the panel existed. It blocks until the
# menu closes, which is the contract the keybind has always had, so exec rather
# than fork and wait.
rofi_menu() {
  if [ ! -x "$rofi_script" ]; then
    notify "Keybind menu" "No keybind menu is available on this system."
    printf 'no keybind menu available\n' >&2
    return 1
  fi
  exec "$rofi_script"
}

launch_panel() {
  quickshell -p "$widget_dir" --daemonize >/dev/null 2>&1

  local attempt
  for attempt in $(seq 1 50); do
    sleep 0.1
    qs_ipc isOpen && return 0
  done

  printf 'quickshell did not start\n' >&2
  return 1
}

case "${1:-toggle}" in
  toggle)
    if panel_available; then
      qs_ipc toggle && exit 0
      launch_panel && qs_ipc open && exit 0
    fi
    printf 'quickshell panel unavailable - using the rofi menu\n' >&2
    rofi_menu
    ;;
  open)
    if panel_available; then
      qs_ipc open && exit 0
      launch_panel && qs_ipc open && exit 0
    fi
    printf 'quickshell panel unavailable - using the rofi menu\n' >&2
    rofi_menu
    ;;
  close)
    qs_ipc close
    ;;
  refresh)
    qs_ipc refresh
    ;;
  which)
    if panel_available; then
      printf 'quickshell\n'
    else
      printf 'rofi\n'
    fi
    ;;
  *)
    printf 'usage: %s [toggle|open|close|refresh|which]\n' "$0" >&2
    exit 2
    ;;
esac
