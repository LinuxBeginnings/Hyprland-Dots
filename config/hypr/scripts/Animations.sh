#!/usr/bin/env bash
# ==================================================
#  KoolDots (2026)
#  Project URL: https://github.com/LinuxBeginnings
#  License: GNU GPLv3
#  SPDX-License-Identifier: GPL-3.0-or-later
# ==================================================
# For applying Animations from different users

# Check if rofi is already running
if pidof rofi > /dev/null; then
  pkill rofi
fi

# Variables
iDIR="${XDG_CONFIG_HOME:-$HOME/.config}/swaync/images"
SCRIPTSDIR="${XDG_CONFIG_HOME:-$HOME/.config}/hypr/scripts"
animations_dir="${XDG_CONFIG_HOME:-$HOME/.config}/hypr/animations"
UserConfigs="${XDG_CONFIG_HOME:-$HOME/.config}/hypr/UserConfigs"
rofi_theme="${XDG_CONFIG_HOME:-$HOME/.config}/hypr/rofi/config-Animations.rasi"

animation_ext="lua"
target_animation_file="$UserConfigs/user_animations.lua"
msg='❗NOTE:❗ This will copy animations into user_animations.lua'

# list of animation files, sorted alphabetically with numbers first
animations_list=$(find -L "$animations_dir" -maxdepth 1 -type f -name "*.${animation_ext}" | sed 's/.*\///' | sed "s/\.${animation_ext}$//" | sort -V)

if [[ -z "$animations_list" ]]; then
    notify-send -u normal -i "$iDIR/ja.png" "No animation presets found" "Expected *.${animation_ext} in $animations_dir"
    exit 0
fi

# Rofi Menu
"${XDG_CONFIG_HOME:-$HOME/.config}/hypr/scripts/RofiFocusedWallpaperLink.sh" >/dev/null 2>&1 || true
chosen_file=$(echo "$animations_list" | rofi -i -dmenu -config "$rofi_theme" -mesg "$msg")

# Check if a file was selected
if [[ -n "$chosen_file" ]]; then
    full_path="$animations_dir/$chosen_file.$animation_ext"
    cp "$full_path" "$target_animation_file"
    notify-send -u low -i "$iDIR/ja.png" "$chosen_file" "Hyprland Animation Loaded"
fi

sleep 1
"$SCRIPTSDIR/RefreshNoWaybar.sh"
