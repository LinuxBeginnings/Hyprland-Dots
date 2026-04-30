#!/usr/bin/env bash
# ==================================================
#  KoolDots (2026)
#  Project URL: https://github.com/LinuxBeginnings
#  License: GNU GPLv3
#  SPDX-License-Identifier: GPL-3.0-or-later
# ==================================================
# searchable enabled keybinds using rofi (supports bindd descriptions)

# kill yad to not interfere with this binds
pkill yad || true

# check if rofi is already running
if pidof rofi > /dev/null; then
  pkill rofi
fi

# define the config files
config_home="${XDG_CONFIG_HOME:-$HOME/.config}"
hypr_dir="$config_home/hypr"
keybinds_conf="$hypr_dir/configs/Keybinds.conf"
user_keybinds_conf="$hypr_dir/UserConfigs/UserKeybinds.conf"
laptop_conf="$hypr_dir/UserConfigs/Laptops.conf"
lua_keybinds_conf="$hypr_dir/lua/keybinds.lua"
lua_user_keybinds="$hypr_dir/UserConfigs/user_keybinds.lua"
lua_system_keybinds="$hypr_dir/UserConfigs/system_keybinds.lua"
lua_overrides="$hypr_dir/UserConfigs/user_overrides.lua"
rofi_theme="$HOME/.config/rofi/config-keybinds.rasi"
msg='☣️ NOTE ☣️: Clicking with Mouse or Pressing ENTER will have NO function'

# detect active Hyprland config mode (Lua entrypoint vs legacy .conf includes)
lua_entry="$hypr_dir/hyprland.lua"
legacy_lua_entry="$config_home/hyprland.lua"
if [[ -f "$lua_entry" || -f "$legacy_lua_entry" ]]; then
  hypr_config_mode="lua"
else
  hypr_config_mode="conf"
fi

# collect raw bind lines from available files
if [[ "$hypr_config_mode" == "lua" ]]; then
  files=("$lua_keybinds_conf")
  [[ -f "$lua_system_keybinds" ]] && files+=("$lua_system_keybinds")
  [[ -f "$lua_user_keybinds" ]] && files+=("$lua_user_keybinds")
  [[ -f "$lua_overrides" ]] && files+=("$lua_overrides")
else
  files=("$keybinds_conf" "$user_keybinds_conf")
  [[ -f "$laptop_conf" ]] && files+=("$laptop_conf")
fi

# Parse binds using the python script for speed
# The last argument must be the user config for override logic to work correctly
display_keybinds=$("$HOME/.config/hypr/scripts/keybinds_parser.py" "${files[@]}")

# Check for suggestions file created by python script
if [[ -f "/tmp/hypr_keybind_suggestions_file" ]]; then
  suggestions_file=$(cat "/tmp/hypr_keybind_suggestions_file")
  rm "/tmp/hypr_keybind_suggestions_file"
  if [[ -n "$suggestions_file" && -f "$suggestions_file" ]]; then
     count=$(wc -l < "$suggestions_file")
     msg="$msg | Overrides missing unbind: $count (suggestions: $suggestions_file)"
  fi
fi

# use rofi to display the keybinds
printf '%s\n' "$display_keybinds" | rofi -dmenu -i -config "$rofi_theme" -mesg "$msg"
