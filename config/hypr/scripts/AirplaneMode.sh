#!/usr/bin/env bash
# ==================================================
#  KoolDots (2026)
#  Project URL: https://github.com/LinuxBeginnings
#  License: GNU GPLv3
#  SPDX-License-Identifier: GPL-3.0-or-later
# ==================================================
# Airplane Mode. Turning on or off all wifi using rfkill. 

notif="${XDG_CONFIG_HOME:-$HOME/.config}/swaync/images/ja.png"

# Check if any wireless device is blocked
wifi_blocked=$(rfkill list wifi | grep -o "Soft blocked: yes")

if [ -n "$wifi_blocked" ]; then
    rfkill unblock wifi
    notify-send -u low -i "$notif" " Airplane" " mode: OFF"
else
    rfkill block wifi
    notify-send -u low -i "$notif" " Airplane" " mode: ON"
fi
