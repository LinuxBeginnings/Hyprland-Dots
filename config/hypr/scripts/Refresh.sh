#!/usr/bin/env bash
# ==================================================
#  KoolDots (2026)
#  Project URL: https://github.com/LinuxBeginnings
#  License: GNU GPLv3
#  SPDX-License-Identifier: GPL-3.0-or-later
# ==================================================
# Scripts for refreshing ags, waybar, rofi, swaync, wallust

SCRIPTSDIR=${XDG_CONFIG_HOME:-$HOME/.config}/hypr/scripts
UserScripts=${XDG_CONFIG_HOME:-$HOME/.config}/hypr/UserScripts
QS_TEXTINPUT_LOG_RULE="qt.qpa.wayland.textinput.warning=false"

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
if command -v ags >/dev/null 2>&1; then
  ags -q >/dev/null 2>&1 || true
  ags >/dev/null 2>&1 &
fi

# quit quickshell & relaunch quickshell
pkill qs && qs --log-rules "$QS_TEXTINPUT_LOG_RULE" &

# some process to kill (exclude waybar to avoid restart loops)
for pid in $(pidof rofi swaync ags swaybg); do
  kill -SIGUSR1 "$pid"
  sleep 0.1
done

# Restart waybar once (works with systemd user unit or manual launch setups)
restart_waybar() {
  local manage_with_systemd=0

  if command -v systemctl >/dev/null 2>&1; then
    if systemctl --user --quiet is-active graphical-session.target 2>/dev/null || systemctl --user --quiet is-active wayland-session@*.target 2>/dev/null; then
      if systemctl --user --quiet is-active waybar.service 2>/dev/null || systemctl --user --quiet is-enabled waybar.service 2>/dev/null; then
        manage_with_systemd=1
      fi
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
if ! pidof swaync >/dev/null 2>&1; then
  swaync >/dev/null 2>&1 &
fi
# reload swaync (asynchronous to prevent DBus timeout delays)
(swaync-client --reload-config >/dev/null 2>&1 &)

# Relaunching rainbow borders based on selected mode
sleep 1
rainbow_mode_file="${UserScripts}/rainbow-borders.mode"
rainbow_mode=""
if [[ -f "$rainbow_mode_file" ]]; then
  rainbow_mode="$(tr -d '[:space:]' <"$rainbow_mode_file")"
fi
if [[ "$rainbow_mode" == "low_cpu" ]]; then
  pkill -f 'RainbowBorders-low-cpu\.sh' >/dev/null 2>&1 || true
  rm -f /tmp/hypr-rainbowborders.lock >/dev/null 2>&1 || true
  if file_exists "${UserScripts}/RainbowBorders-low-cpu.sh"; then
    "${UserScripts}/RainbowBorders-low-cpu.sh" >/dev/null 2>&1 &
  fi
elif file_exists "${UserScripts}/RainbowBorders.sh"; then
  "${UserScripts}/RainbowBorders.sh" &
fi

exit 0
