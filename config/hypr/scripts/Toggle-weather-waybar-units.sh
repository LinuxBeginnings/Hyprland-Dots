#!/usr/bin/env bash
# ==================================================
#  KoolDots (2026)
#  Project URL: https://github.com/LinuxBeginnings
#  License: GNU GPLv3
#  SPDX-License-Identifier: GPL-3.0-or-later
# ==================================================
# Toggle weather units between metric and imperial across UserConfigs (Lua/Conf), waybar-weather, and systemd/dbus env.

set -euo pipefail

config_home="${XDG_CONFIG_HOME:-$HOME/.config}"
hypr_dir="$config_home/hypr"
user_env_lua="$hypr_dir/UserConfigs/user_env.lua"
user_env_conf="$hypr_dir/UserConfigs/ENVariables.conf"
waybar_weather_cfg="$config_home/waybar-weather/config.toml"
scripts_dir="$hypr_dir/scripts"

# Determine current units
current_units="metric"

if [[ -f "$user_env_lua" ]] && grep -qE '^[[:space:]]*hl\.env\([[:space:]]*["'\'']WEATHER_UNITS["'\'']' "$user_env_lua"; then
  val=$(sed -nE 's/^[[:space:]]*hl\.env\([[:space:]]*["'\'']WEATHER_UNITS["'\''][[:space:]]*,[[:space:]]*["'\'']([^"'\'']+)["'\''].*/\1/p' "$user_env_lua" | tail -n1)
  [[ -n "$val" ]] && current_units="$val"
elif [[ -f "$user_env_conf" ]] && grep -qE '^[[:space:]]*env[[:space:]]*=[[:space:]]*WEATHER_UNITS' "$user_env_conf"; then
  val=$(sed -nE 's/^[[:space:]]*env[[:space:]]*=[[:space:]]*WEATHER_UNITS[[:space:]]*,[[:space:]]*([^#[:space:]]+).*/\1/p' "$user_env_conf" | tail -n1)
  [[ -n "$val" ]] && current_units="$val"
elif [[ -f "$waybar_weather_cfg" ]] && grep -qE '^[[:space:]]*units[[:space:]]*=' "$waybar_weather_cfg"; then
  val=$(sed -nE 's/^[[:space:]]*units[[:space:]]*=[[:space:]]*"([^"]+)".*/\1/p' "$waybar_weather_cfg" | tail -n1)
  [[ -n "$val" ]] && current_units="$val"
elif [[ -n "${WEATHER_UNITS:-}" ]]; then
  current_units="$WEATHER_UNITS"
fi

current_units=$(echo "$current_units" | tr '[:upper:]' '[:lower:]' | tr -d '[:space:]')

if [[ "$current_units" == "imperial" || "$current_units" == "fahrenheit" || "$current_units" == "f" ]]; then
  new_units="metric"
  unit_label="Metric (°C)"
else
  new_units="imperial"
  unit_label="Imperial (°F)"
fi

# 1. Update user_env.lua
if [[ -f "$user_env_lua" ]]; then
  if grep -qE '^[[:space:]]*hl\.env\([[:space:]]*["'\'']WEATHER_UNITS["'\'']' "$user_env_lua"; then
    sed -i -E 's/^[[:space:]]*hl\.env\([[:space:]]*["'\'']WEATHER_UNITS["'\''].*/hl.env("WEATHER_UNITS", "'"$new_units"'")/' "$user_env_lua"
  elif grep -qE '^[[:space:]]*--[[:space:]]*hl\.env\([[:space:]]*["'\'']WEATHER_UNITS["'\'']' "$user_env_lua"; then
    sed -i -E 's/^[[:space:]]*--[[:space:]]*hl\.env\([[:space:]]*["'\'']WEATHER_UNITS["'\''].*/hl.env("WEATHER_UNITS", "'"$new_units"'")/' "$user_env_lua"
  else
    printf '\nhl.env("WEATHER_UNITS", "%s")\n' "$new_units" >> "$user_env_lua"
  fi
fi

# 2. Update ENVariables.conf
if [[ -f "$user_env_conf" ]]; then
  if grep -qE '^[[:space:]]*env[[:space:]]*=[[:space:]]*WEATHER_UNITS' "$user_env_conf"; then
    sed -i -E 's/^[[:space:]]*env[[:space:]]*=[[:space:]]*WEATHER_UNITS.*/env = WEATHER_UNITS,'"$new_units"'/' "$user_env_conf"
  elif grep -qE '^[[:space:]]*#[[:space:]]*env[[:space:]]*=[[:space:]]*WEATHER_UNITS' "$user_env_conf"; then
    sed -i -E 's/^[[:space:]]*#[[:space:]]*env[[:space:]]*=[[:space:]]*WEATHER_UNITS.*/env = WEATHER_UNITS,'"$new_units"'/' "$user_env_conf"
  else
    printf '\nenv = WEATHER_UNITS,%s\n' "$new_units" >> "$user_env_conf"
  fi
fi

# 3. Update waybar-weather config.toml if present
if [[ -f "$waybar_weather_cfg" ]]; then
  if grep -qE '^[[:space:]]*units[[:space:]]*=' "$waybar_weather_cfg"; then
    sed -i 's/^[[:space:]]*units[[:space:]]*=.*/units = "'"$new_units"'"/' "$waybar_weather_cfg"
  elif grep -qE '^[[:space:]]*#[[:space:]]*units[[:space:]]*=' "$waybar_weather_cfg"; then
    sed -i 's/^[[:space:]]*#[[:space:]]*units[[:space:]]*=.*/units = "'"$new_units"'"/' "$waybar_weather_cfg"
  else
    printf '\nunits = "%s"\n' "$new_units" >> "$waybar_weather_cfg"
  fi
fi

# 4. Export to current session and systemd/D-Bus
export WEATHER_UNITS="$new_units"
if command -v systemctl >/dev/null 2>&1; then
  systemctl --user import-environment WEATHER_UNITS >/dev/null 2>&1 || true
fi
if command -v dbus-update-activation-environment >/dev/null 2>&1; then
  dbus-update-activation-environment --systemd WEATHER_UNITS >/dev/null 2>&1 || true
fi

# 5. Clear caches & signal legacy waybar-weather if running
rm -f "$HOME/.cache/open_meteo_cache.json" "$HOME/.cache/.weather_cache" >/dev/null 2>&1 || true
pkill waybar-weather >/dev/null 2>&1 || true

# 6. Refresh Waybar so it runs with the updated environment
if [[ -x "$scripts_dir/Refresh.sh" ]]; then
  "$scripts_dir/Refresh.sh" &
fi

# 7. Notify user
icon="$config_home/swaync/images/note.png"
if [[ -f "$icon" ]] && command -v notify-send >/dev/null 2>&1; then
  notify-send -i "$icon" "Weather Units" "Switched to $unit_label"
elif command -v notify-send >/dev/null 2>&1; then
  notify-send "Weather Units" "Switched to $unit_label"
fi
