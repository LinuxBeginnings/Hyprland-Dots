#!/usr/bin/env bash
# ==================================================
#  KoolDots (2026)
#  Project URL: https://github.com/LinuxBeginnings
#  License: GNU GPLv3
#  SPDX-License-Identifier: GPL-3.0-or-later
# ==================================================
# searchable keybinds using rofi
#
# The list comes from lua/keybind_index.lua, which records every hl.bind() in
# Hyprland's Lua VM and renders it to the runtime directory. Nothing here parses
# config files, so what rofi shows is what the compositor has bound.
#
# The file is rewritten before every run rather than trusted: a bind added with
# `hyprctl eval` after the last reload changes the VM's registry but not the
# file, and a config load that failed halfway leaves the file one write behind.

# kill yad to not interfere with this binds
pkill yad || true

# check if rofi is already running
if pidof rofi > /dev/null; then
  pkill rofi
fi

config_home="${XDG_CONFIG_HOME:-$HOME/.config}"
runtime_dir="${XDG_RUNTIME_DIR:-/tmp}"
cache="$runtime_dir/kooldots-keybinds.txt"
rofi_theme="$config_home/hypr/rofi/config-keybinds.rasi"
msg='☣️ NOTE ☣️: Clicking with Mouse or Pressing ENTER will have NO function'

# Ask the live Lua VM to rewrite the list. Best effort: on a config whose
# hyprland.lua predates keybind_index.lua there is no module to call.
hyprctl eval 'KOOLDOTS_KEYBIND_INDEX:write_cache()' >/dev/null 2>&1 || true

# Fallback for that case, and for a build where the hook could not be installed:
# read the compositor's own bind table. Mask bits are SHIFT 1, CTRL 4, ALT 8,
# SUPER 64.
if [ ! -s "$cache" ] && command -v jq > /dev/null 2>&1; then
  hyprctl binds -j 2>/dev/null | jq -r '
    def mods($m): [ if (($m / 64 | floor) % 2) == 1 then "SUPER" else empty end,
                    if (($m / 4  | floor) % 2) == 1 then "CTRL"  else empty end,
                    if (($m / 8  | floor) % 2) == 1 then "ALT"   else empty end,
                    if (($m % 2) == 1)             then "SHIFT" else empty end ] | join("+");
    .[] | (mods(.modmask)) as $mods
        | (if $mods == "" then .key else $mods + "+" + .key end) as $chord
        | if (.has_description and .description != "") then "\($chord) — \(.description)" else $chord end
  ' > "$cache" 2>/dev/null || true
fi

if [ ! -s "$cache" ]; then
  notify-send "Keybinds" "Keybind list unavailable - run: hyprctl reload" 2>/dev/null || true
  exit 1
fi

# use rofi to display the keybinds
"$config_home/hypr/scripts/RofiFocusedWallpaperLink.sh" >/dev/null 2>&1 || true
rofi -dmenu -i -config "$rofi_theme" -mesg "$msg" < "$cache"
