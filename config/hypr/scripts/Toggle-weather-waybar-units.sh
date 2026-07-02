#!/usr/bin/env bash
# ==================================================
#  KoolDots (2026)
#  Project URL: https://github.com/LinuxBeginnings
#  License: GNU GPLv3
#  SPDX-License-Identifier: GPL-3.0-or-later
# ==================================================
# Toggle waybar-weather units between metric and imperial

CONFIG_FILE="${XDG_CONFIG_HOME:-$HOME/.config}/waybar-weather/config.toml"

if [ ! -f "$CONFIG_FILE" ]; then
  notify-send "Weather units" "Config not found: $CONFIG_FILE"
  exit 1
fi

# Determine current units (default to metric when unset/commented)
current_units="metric"
if grep -qE '^[[:space:]]*units[[:space:]]*=' "$CONFIG_FILE"; then
  current_units=$(sed -nE 's/^[[:space:]]*units[[:space:]]*=[[:space:]]*"([^"]+)".*/\1/p' "$CONFIG_FILE" | head -n1)
fi

if [ "$current_units" = "imperial" ]; then
  new_units="metric"
else
  new_units="imperial"
fi

# Update config: prefer replacing existing units line, otherwise uncomment default, else append
if grep -qE '^[[:space:]]*units[[:space:]]*=' "$CONFIG_FILE"; then
  sed -i 's/^[[:space:]]*units[[:space:]]*=.*/units = "'"$new_units"'"/' "$CONFIG_FILE"
elif grep -qE '^[[:space:]]*#\s*units[[:space:]]*=' "$CONFIG_FILE"; then
  sed -i 's/^[[:space:]]*#\s*units[[:space:]]*=.*/units = "'"$new_units"'"/' "$CONFIG_FILE"
else
  printf '\nunits = "%s"\n' "$new_units" >> "$CONFIG_FILE"
fi

pkill waybar-weather 2>/dev/null || true
notify-send "Weather units now ${new_units}" "Click on waybar-weather to update units"
