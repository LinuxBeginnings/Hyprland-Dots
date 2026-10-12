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
current_animation_file="$UserConfigs/.current_animation"
msg='❗NOTE:❗ This will copy animations into user_animations.lua'
MARKER="👉"

# list of animation files, sorted alphabetically with numbers first
animations_list=$(find -L "$animations_dir" -maxdepth 1 -type f -name "*.${animation_ext}" | sed 's/.*\///' | sed "s/\.${animation_ext}$//" | sort -V)

if [[ -z "$animations_list" ]]; then
    notify-send -u normal -i "$iDIR/ja.png" "No animation presets found" "Expected *.${animation_ext} in $animations_dir"
    exit 0
fi

# Which preset is loaded now.
# The menu copies a preset over user_animations.lua verbatim, so an exact match
# against a preset is the strongest evidence - it also covers a preset copied by
# hand. The recorded name is the fallback for a file that matches nothing: a
# preset an upgrade has since rewritten, or one the Lua migration generated.
current_animation=""
if [[ -f "$target_animation_file" ]]; then
    while IFS= read -r preset; do
        [[ -n "$preset" ]] || continue
        if cmp -s -- "$animations_dir/$preset.$animation_ext" "$target_animation_file"; then
            current_animation="$preset"
            break
        fi
    done <<<"$animations_list"
fi
if [[ -z "$current_animation" && -f "$current_animation_file" ]]; then
    recorded="$(head -n1 -- "$current_animation_file" 2>/dev/null | tr -d '\r')"
    if [[ -n "$recorded" && -f "$animations_dir/$recorded.$animation_ext" ]]; then
        current_animation="$recorded"
    fi
fi

# What the message line says: the preset, or why none is marked.
current_label="$current_animation"
if [[ -z "$current_label" ]]; then
    if [[ -f "$target_animation_file" ]] && grep -qvE '^[[:space:]]*(--.*)?$' "$target_animation_file"; then
        current_label="custom"
    else
        current_label="default"
    fi
fi

# Mark the loaded preset and pre-select its row. The marker is stripped again
# before the choice is used as a path.
default_row=0
menu_list="$animations_list"
if [[ -n "$current_animation" ]]; then
    menu_list=""
    row=0
    while IFS= read -r preset; do
        if [[ "$preset" == "$current_animation" ]]; then
            menu_list+="$MARKER $preset"$'\n'
            default_row=$row
        else
            menu_list+="$preset"$'\n'
        fi
        row=$((row + 1))
    done <<<"$animations_list"
    menu_list="${menu_list%$'\n'}"
fi

# Rofi Menu
"${XDG_CONFIG_HOME:-$HOME/.config}/hypr/scripts/RofiFocusedWallpaperLink.sh" >/dev/null 2>&1 || true
chosen_file=$(printf '%s\n' "$menu_list" | rofi -i -dmenu -config "$rofi_theme" -mesg "$msg • Current: $current_label" -selected-row "$default_row")

# Check if a file was selected
if [[ -z "$chosen_file" ]]; then
    exit 0
fi

# Strip the marker before the name is used as a path
chosen_file="${chosen_file#"$MARKER "}"

full_path="$animations_dir/$chosen_file.$animation_ext"
if [[ ! -f "$full_path" ]]; then
    notify-send -u normal -i "$iDIR/error.png" "Error" "Animation preset not found: $chosen_file"
    exit 1
fi

mkdir -p "$UserConfigs"
cp "$full_path" "$target_animation_file"
printf '%s\n' "$chosen_file" >"$current_animation_file"
notify-send -u low -i "$iDIR/ja.png" "$chosen_file" "Hyprland Animation Loaded"

if command -v hyprctl &>/dev/null; then
    hyprctl reload >/dev/null 2>&1 || true
fi

sleep 1
"$SCRIPTSDIR/RefreshNoWaybar.sh" &
