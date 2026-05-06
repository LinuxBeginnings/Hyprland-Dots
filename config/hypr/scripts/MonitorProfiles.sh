#!/usr/bin/env bash
# ==================================================
#  KoolDots (2026)
#  Project URL: https://github.com/LinuxBeginnings
#  License: GNU GPLv3
#  SPDX-License-Identifier: GPL-3.0-or-later
# ==================================================
# For applying Pre-configured Monitor Profiles

# Check if rofi is already running
if pidof rofi > /dev/null; then
  pkill rofi
fi

# Detect active Hyprland config mode (Lua entrypoint vs legacy .conf includes)
config_home="${XDG_CONFIG_HOME:-$HOME/.config}"
hypr_dir="$config_home/hypr"
lua_entry="$hypr_dir/hyprland.lua"
legacy_lua_entry="$config_home/hyprland.lua"
if [[ -f "$lua_entry" || -f "$legacy_lua_entry" ]]; then
    hypr_config_mode="lua"
else
    hypr_config_mode="conf"
fi

# Variables
iDIR="$HOME/.config/swaync/images"
SCRIPTSDIR="$HOME/.config/hypr/scripts"
monitor_dir="$HOME/.config/hypr/Monitor_Profiles"
target_conf="$HOME/.config/hypr/monitors.conf"
target_lua="$HOME/.config/hypr/lua/monitors.lua"
rofi_theme="$HOME/.config/rofi/config-Monitors.rasi"

if [[ "$hypr_config_mode" == "lua" ]]; then
    profile_ext="lua"
    target="$target_lua"
    msg='❗NOTE:❗ This will overwrite $HOME/.config/hypr/lua/monitors.lua'
else
    profile_ext="conf"
    target="$target_conf"
    msg='❗NOTE:❗ This will overwrite $HOME/.config/hypr/monitors.conf'
fi

# Define the list of files to ignore
ignore_files=(
  "README"
)

# list of Monitor Profiles, sorted alphabetically with numbers first
mon_profiles_list=$(find -L "$monitor_dir" -maxdepth 1 -type f -name "*.${profile_ext}" | sed 's/.*\///' | sed "s/\.${profile_ext}$//" | sort -V)

# Remove ignored files from the list
for ignored_file in "${ignore_files[@]}"; do
    mon_profiles_list=$(echo "$mon_profiles_list" | grep -v -E "^$ignored_file$")
done

# Rofi Menu
chosen_file=$(echo "$mon_profiles_list" | rofi -i -dmenu -config $rofi_theme -mesg "$msg")

if [[ -n "$chosen_file" ]]; then
    full_path="$monitor_dir/$chosen_file.$profile_ext"
    cp "$full_path" "$target"
    
    notify-send -u low -i "$iDIR/ja.png" "$chosen_file" "Monitor Profile Loaded"
fi

sleep 1
${SCRIPTSDIR}/RefreshNoWaybar.sh &