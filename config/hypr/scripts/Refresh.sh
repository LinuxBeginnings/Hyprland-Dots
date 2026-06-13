#!/usr/bin/env bash
# ==================================================
#  KoolDots (2026)
#  Project URL: https://github.com/LinuxBeginnings
#  License: GNU GPLv3
#  SPDX-License-Identifier: GPL-3.0-or-later
# ==================================================
# Scripts for refreshing ags, waybar, rofi, swaync, wallust

SCRIPTSDIR=$HOME/.config/hypr/scripts
UserScripts=$HOME/.config/hypr/UserScripts

# Define file_exists function
file_exists() {
  if [ -e "$1" ]; then
    return 0 # File exists
  else
    return 1 # File does not exist
  fi
}

# Kill already running processes (exclude waybar to avoid double reloads)
_ps=(rofi swaync ags)
for _prs in "${_ps[@]}"; do
  if pidof "${_prs}" >/dev/null; then
    pkill "${_prs}"
  fi
done

# Clean up any Waybar-spawned cava instances (unique temp conf names)
pkill -f 'waybar-cava\..*\.conf' 2>/dev/null || true


# quit ags & relaunch ags
ags -q && ags &

# quit quickshell & relaunch quickshell
pkill qs && qs &

# some process to kill (exclude waybar to avoid restart loops)
for pid in $(pidof rofi swaync ags swaybg); do
  kill -SIGUSR1 "$pid"
  sleep 0.1
done

# Restart waybar once (works with systemd user unit or manual launch setups)
restart_waybar() {
  local manage_with_systemd=0

  if command -v systemctl >/dev/null 2>&1; then
    if systemctl --user --quiet is-active waybar.service 2>/dev/null || systemctl --user --quiet is-enabled waybar.service 2>/dev/null; then
      manage_with_systemd=1
    fi
  fi

  if [ "$manage_with_systemd" -eq 1 ]; then
    systemctl --user stop waybar.service >/dev/null 2>&1 || true
  fi

  pkill -x waybar >/dev/null 2>&1 || true
  pkill -x '.waybar-wrapped' >/dev/null 2>&1 || true
  sleep 0.2
  if pgrep -x waybar >/dev/null 2>&1 || pgrep -x '.waybar-wrapped' >/dev/null 2>&1; then
    pkill -9 -x waybar >/dev/null 2>&1 || true
    pkill -9 -x '.waybar-wrapped' >/dev/null 2>&1 || true
  fi
  sleep 0.2

  if [ "$manage_with_systemd" -eq 1 ]; then
    if ! systemctl --user start waybar.service >/dev/null 2>&1; then
      waybar >/dev/null 2>&1 &
    fi
  else
    waybar >/dev/null 2>&1 &
  fi
}

restart_waybar

# relaunch swaync
sleep 0.3
swaync >/dev/null 2>&1 &
# reload swaync
swaync-client --reload-config

# Relaunching rainbow borders if the script exists
sleep 1
if file_exists "${UserScripts}/RainbowBorders.sh"; then
  ${UserScripts}/RainbowBorders.sh &
fi

exit 0
