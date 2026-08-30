#!/usr/bin/env bash
# ==================================================
#  KoolDots (2026)
#  Project URL: https://github.com/LinuxBeginnings
#  License: GNU GPLv3
#  SPDX-License-Identifier: GPL-3.0-or-later
# ==================================================
# nwg-dock-hyprland launcher and toggle script

SCRIPTSDIR="${XDG_CONFIG_HOME:-$HOME/.config}/hypr/scripts"
DOCK_CONFIG_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/nwg-dock-hyprland"

# Ensure dock configuration and wallust directory exist
mkdir -p "$DOCK_CONFIG_DIR/wallust" 2>/dev/null || true

# Check if nwg-dock-hyprland is installed
if ! command -v nwg-dock-hyprland >/dev/null 2>&1; then
  notify-send -u normal "Dock" "nwg-dock-hyprland is not installed" 2>/dev/null || true
  exit 1
fi

is_dock_running() {
  pgrep -x "nwg-dock-hyprla" >/dev/null 2>&1
}

kill_dock() {
  pkill -x "nwg-dock-hyprla" 2>/dev/null || true
}

start_dock() {
  # Dock configuration:
  # -p bottom : bottom dock position
  # -x : exclusive zone (moves other windows aside)
  # -i 32 : icon size 32
  # -g : ignore/drop class (hide dropdown terminal from dock/task list)
  # -mb 10 : margin bottom 10px
  # -c : launcher button command (rofi menu)
  # (no -d : no auto-hide)
  local launcher_cmd="${SCRIPTSDIR}/RofiLauncher.sh"
  nwg-dock-hyprland -p bottom -x -i 32 -g "kitty-dropterm" -mb 7 -mt 7 -c "$launcher_cmd" >/dev/null 2>&1 &
}

case "${1:-toggle}" in
--restart | restart)
  kill_dock
  sleep 0.2
  start_dock
  ;;
--start | start | activate)
  if ! is_dock_running; then
    start_dock
  fi
  ;;
--stop | stop | deactivate)
  kill_dock
  ;;
--toggle | toggle | *)
  if is_dock_running; then
    kill_dock
  else
    start_dock
  fi
  ;;
esac

exit 0
