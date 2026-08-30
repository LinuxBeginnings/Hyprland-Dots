#!/usr/bin/env bash
# ==================================================
#  KoolDots (2026)
#  Project URL: https://github.com/LinuxBeginnings
#  License: GNU GPLv3
#  SPDX-License-Identifier: GPL-3.0-or-later
# ==================================================

# Modified version of Refresh.sh but waybar wont refresh
# Used by automatic wallpaper change
# Modified inorder to refresh rofi background, Wallust, SwayNC only

SCRIPTSDIR=${XDG_CONFIG_HOME:-$HOME/.config}/hypr/scripts
UserScripts=${XDG_CONFIG_HOME:-$HOME/.config}/hypr/UserScripts
QS_TEXTINPUT_LOG_RULE="qt.qpa.wayland.textinput.warning=false"

# Define file_exists function
file_exists() {
    if [ -e "$1" ]; then
        return 0  # File exists
    else
        return 1  # File does not exist
    fi
}

# Kill already running processes
_ps=(rofi)
for _prs in "${_ps[@]}"; do
    if pidof "${_prs}" >/dev/null; then
        pkill "${_prs}"
    fi
done

# quit ags & relaunch ags
ags -q && ags &

# quit quickshell & relaunch quickshell
pkill qs && qs --log-rules "$QS_TEXTINPUT_LOG_RULE" &


# reload swaync
swaync-client --reload-config

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
