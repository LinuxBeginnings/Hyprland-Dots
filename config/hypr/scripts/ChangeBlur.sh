#!/usr/bin/env bash
# ==================================================
#  KoolDots (2026)
#  Project URL: https://github.com/LinuxBeginnings
#  License: GNU GPLv3
#  SPDX-License-Identifier: GPL-3.0-or-later
# ==================================================
# Script for changing blurs on the fly

notif="${XDG_CONFIG_HOME:-$HOME/.config}/swaync/images"

config_home="${XDG_CONFIG_HOME:-$HOME/.config}"
hypr_dir="$config_home/hypr"
lua_entry="$hypr_dir/hyprland.lua"
legacy_lua_entry="$config_home/hyprland.lua"

if [[ -f "$lua_entry" || -f "$legacy_lua_entry" ]]; then
    hypr_config_mode="lua"
else
    hypr_config_mode="conf"
fi

STATE=$(hyprctl -j getoption decoration:blur:passes 2>/dev/null | jq -r ".int // empty")
if [[ -z "$STATE" || "$STATE" == "null" ]]; then
    STATE=$(hyprctl getoption decoration:blur:passes 2>/dev/null | awk 'NR==1{print $2}')
fi

if [ "${STATE}" == "2" ]; then
    if [[ "$hypr_config_mode" == "lua" ]]; then
        hyprctl eval "hl.config({ decoration = { blur = { size = 2, passes = 1 } } })"
    else
        hyprctl keyword decoration:blur:size 2
        hyprctl keyword decoration:blur:passes 1
    fi
    notify-send -e -u low -i "$notif/note.png" " Less Blur"
else
    if [[ "$hypr_config_mode" == "lua" ]]; then
        hyprctl eval "hl.config({ decoration = { blur = { size = 5, passes = 2 } } })"
    else
        hyprctl keyword decoration:blur:size 5
        hyprctl keyword decoration:blur:passes 2
    fi
    notify-send -e -u low -i "$notif/ja.png" " Normal Blur"
fi
