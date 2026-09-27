#!/usr/bin/env bash
# ==================================================
#  KoolDots (2026)
#  Project URL: https://github.com/LinuxBeginnings
#  License: GNU GPLv3
#  SPDX-License-Identifier: GPL-3.0-or-later
# ==================================================
# For Searching via web browsers

# Define the path to the config files
lua_user_defaults=${XDG_CONFIG_HOME:-$HOME/.config}/hypr/UserConfigs/user_defaults.lua
lua_sys_defaults=${XDG_CONFIG_HOME:-$HOME/.config}/hypr/lua/user_defaults.lua

if ! command -v jq >/dev/null 2>&1; then
    notify-send -u low "Rofi Search" "jq is required for URL encoding. Please install jq."
    exit 1
fi

Search_Engine=""

# 1. Check Lua user defaults
if [[ -f "$lua_user_defaults" ]]; then
    lua_engine=$(sed -nE 's/^[[:space:]]*KOOLDOTS_DEFAULTS\.(search_engine|Search_Engine)[[:space:]]*=[[:space:]]*["'\'']([^"'\'']+)["'\''][[:space:]]*(;?([[:space:]]*--.*)?)?$/\2/p' "$lua_user_defaults" | tail -n1)
    [[ -n "$lua_engine" ]] && Search_Engine="$lua_engine"
fi

# 2. Check Lua system defaults if still unset
if [[ -z "$Search_Engine" && -f "$lua_sys_defaults" ]]; then
    sys_engine=$(sed -nE 's/^[[:space:]]*KOOLDOTS_DEFAULTS\.(search_engine|Search_Engine)[[:space:]]*=[[:space:]]*["'\'']([^"'\'']+)["'\''][[:space:]]*(;?([[:space:]]*--.*)?)?$/\2/p' "$lua_sys_defaults" | tail -n1)
    [[ -n "$sys_engine" ]] && Search_Engine="$sys_engine"
fi

# Fallback default
if [[ -z "$Search_Engine" ]]; then
    Search_Engine="https://www.google.com/search?q={}"
fi

# Rofi theme and message
rofi_theme="${XDG_CONFIG_HOME:-$HOME/.config}/hypr/rofi/config-search.rasi"
msg='‼️ **note** ‼️ search via default web browser'

# Kill Rofi if already running before execution
if pgrep -x "rofi" >/dev/null; then
    pkill rofi
fi

# Open Rofi and pass the selected query to xdg-open for the configured search engine
"${XDG_CONFIG_HOME:-$HOME/.config}/hypr/scripts/RofiFocusedWallpaperLink.sh" >/dev/null 2>&1 || true
query=$(printf '' | rofi -dmenu -config "$rofi_theme" -mesg "$msg")

if [[ -z "$query" ]]; then
    exit 0
fi

encoded_query=$(printf '%s' "$query" | jq -sRr @uri)
if [[ "$Search_Engine" == *"{}"* ]]; then
    search_url="${Search_Engine//\{\}/$encoded_query}"
else
    search_url="${Search_Engine}${encoded_query}"
fi
xdg-open "$search_url" >/dev/null 2>&1 &
