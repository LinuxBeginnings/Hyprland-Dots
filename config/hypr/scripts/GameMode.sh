#!/usr/bin/env bash
# ==================================================
#  KoolDots (2026)
#  Project URL: https://github.com/LinuxBeginnings
#  License: GNU GPLv3
#  SPDX-License-Identifier: GPL-3.0-or-later
# ==================================================
# Game Mode. Turning off all animations

notif="${XDG_CONFIG_HOME:-$HOME/.config}/swaync/images/ja.png"
SCRIPTSDIR="${XDG_CONFIG_HOME:-$HOME/.config}/hypr/scripts"
# shellcheck source=/dev/null
. "$SCRIPTSDIR/WallpaperCmd.sh"

# Check if animations are currently enabled
HYPRGAMEMODE=$(hyprctl getoption animations:enabled -j | jq -r '.bool' 2>/dev/null)
if [[ "$HYPRGAMEMODE" == "null" || -z "$HYPRGAMEMODE" ]]; then
    HYPRGAMEMODE=$(hyprctl getoption animations:enabled | awk 'NR==1{print $2}')
fi

if [ "$HYPRGAMEMODE" = "true" ] || [ "$HYPRGAMEMODE" = "1" ] ; then
    # ENABLE Game Mode (Disable animations/decorations via native Lua)
    hyprctl eval "hl.config({ 
        animations = { enabled = false },
        decoration = { shadow = { enabled = false }, blur = { enabled = false }, rounding = 0 },
        general = { gaps_in = 0, gaps_out = 0, border_size = 1 }
    })"
    hyprctl eval "hl.window_rule({ name = 'gamemode-opacity', match = { class = '.*' }, opacity = 1.0 })"
    
    "$WWW_CMD" kill 
    notify-send -e -u low -i "$notif" " Gamemode:" " enabled"
    sleep 0.1
    exit
else
    # DISABLE Game Mode (Restore animations/decorations)
    hyprctl reload

    # Restore wallpaper using the official daemon script
    if [[ -x "${SCRIPTSDIR}/WallpaperDaemon.sh" ]]; then
        "${SCRIPTSDIR}/WallpaperDaemon.sh" &
    fi
    
    sleep 0.1
    if [[ -x "${SCRIPTSDIR}/WallustSwww.sh" ]]; then
        "${SCRIPTSDIR}/WallustSwww.sh"
    fi
    sleep 0.5
    
    # Refresh UI components
    if [[ -x "${SCRIPTSDIR}/Refresh.sh" ]]; then
        "${SCRIPTSDIR}/Refresh.sh"
    fi

    notify-send -e -u normal -i "$notif" " Gamemode:" " disabled"
    exit
fi
