#!/usr/bin/env bash
# ==================================================
#  KoolDots (2026)
#  Project URL: https://github.com/LinuxBeginnings
#  License: GNU GPLv3
#  SPDX-License-Identifier: GPL-3.0-or-later
# ==================================================

set -euo pipefail

# 1. Close wlogout if this script was triggered from the logout menu
pkill -x wlogout 2>/dev/null || true

# 2. Lock screen: delegate to hypridle if active; fallback to direct hyprlock if inactive
if pgrep -x hypridle >/dev/null 2>&1; then
    # hypridle handles lock_cmd (pidof hyprlock || hyprlock) upon receiving the D-Bus signal
    loginctl lock-session
else
    # hypridle is dead (e.g. Waybar idle inhibitor active); start hyprlock directly
    if ! pgrep -x hyprlock >/dev/null 2>&1; then
        hyprlock -q &
        disown
    fi
    # Keep systemd-logind session state synchronized
    loginctl lock-session 2>/dev/null || true
fi

# 3. Asynchronously update weather cache for Waybar / hyprlock readers without blocking lock
weather_script="${XDG_CONFIG_HOME:-$HOME/.config}/hypr/UserScripts/WeatherWrap.sh"
if [[ -f "$weather_script" ]]; then
    bash "$weather_script" >/dev/null 2>&1 &
fi

