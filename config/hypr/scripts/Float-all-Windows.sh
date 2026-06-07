#!/usr/bin/env bash
# ==================================================
#  KoolDots (2026)
#  Project URL: https://github.com/LinuxBeginnings
#  License: GNU GPLv3
#  SPDX-License-Identifier: GPL-3.0-or-later
# ==================================================

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

# Get current workspace ID
ws=$(hyprctl activeworkspace -j | jq -r .id)

# Process all windows on the current workspace
if [[ "$hypr_config_mode" == "lua" ]]; then
    # In Lua mode, use the native Lua API via hl.dispatch to ensure compatibility
    hyprctl clients -j | jq -r --arg ws "$ws" '.[] | select(.workspace.id == ($ws|tonumber)) | .address' | while read -r addr; do
        hyprctl dispatch "hl.dispatch(hl.dsp.window.float({ window = \"address:${addr}\", action = \"toggle\" }))" >/dev/null 2>&1
    done
else
    # Legacy Hyprlang mode
    hyprctl clients -j | jq -r --arg ws "$ws" '.[] | select(.workspace.id == ($ws|tonumber)) | .address' | xargs -r -I {} hyprctl dispatch togglefloating address:{}
fi
