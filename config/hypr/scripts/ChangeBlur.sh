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

LOCK="/tmp/.hypr_change_blur_${HYPRLAND_INSTANCE_SIGNATURE:-default}.lock"

(
  flock -n 200 || exit 0

  # Check if blur is currently enabled
  BLUR_ENABLED=$(hyprctl -j getoption decoration:blur:enabled 2>/dev/null | jq -r ".bool // empty")
  if [[ -z "$BLUR_ENABLED" || "$BLUR_ENABLED" == "null" ]]; then
      BLUR_ENABLED=$(hyprctl getoption decoration:blur:enabled 2>/dev/null | awk 'NR==1{print $2}')
  fi

  STATE=$(hyprctl -j getoption decoration:blur:passes 2>/dev/null | jq -r ".int // empty")
  if [[ -z "$STATE" || "$STATE" == "null" ]]; then
      STATE=$(hyprctl getoption decoration:blur:passes 2>/dev/null | awk 'NR==1{print $2}')
  fi

  # If blur was disabled or 0 passes, enable Normal Blur
  if [[ "$BLUR_ENABLED" == "false" || "$BLUR_ENABLED" == "0" || "${STATE}" == "0" ]]; then
      if [[ "$hypr_config_mode" == "lua" ]]; then
          hyprctl -r eval "hl.config({ decoration = { blur = { enabled = true, size = 6, passes = 3, ignore_opacity = true, xray = false, new_optimizations = true } } })" >/dev/null 2>&1 || true
      else
          hyprctl keyword decoration:blur:enabled 1
          hyprctl keyword decoration:blur:size 6
          hyprctl keyword decoration:blur:passes 3
          hyprctl keyword decoration:blur:ignore_opacity 1
          hyprctl keyword decoration:blur:xray 0
          hyprctl keyword decoration:blur:new_optimizations 1
      fi
      notify-send -e -u low -i "$notif/ja.png" " Normal Blur"
  elif [ "${STATE:-2}" -ge 2 ]; then
      if [[ "$hypr_config_mode" == "lua" ]]; then
          hyprctl -r eval "hl.config({ decoration = { blur = { enabled = true, size = 2, passes = 1, ignore_opacity = true, xray = false, new_optimizations = true } } })" >/dev/null 2>&1 || true
      else
          hyprctl keyword decoration:blur:enabled 1
          hyprctl keyword decoration:blur:size 2
          hyprctl keyword decoration:blur:passes 1
          hyprctl keyword decoration:blur:ignore_opacity 1
          hyprctl keyword decoration:blur:xray 0
          hyprctl keyword decoration:blur:new_optimizations 1
      fi
      notify-send -e -u low -i "$notif/note.png" " Less Blur"
  else
      if [[ "$hypr_config_mode" == "lua" ]]; then
          hyprctl -r eval "hl.config({ decoration = { blur = { enabled = true, size = 6, passes = 3, ignore_opacity = true, xray = false, new_optimizations = true } } })" >/dev/null 2>&1 || true
      else
          hyprctl keyword decoration:blur:enabled 1
          hyprctl keyword decoration:blur:size 6
          hyprctl keyword decoration:blur:passes 3
          hyprctl keyword decoration:blur:ignore_opacity 1
          hyprctl keyword decoration:blur:xray 0
          hyprctl keyword decoration:blur:new_optimizations 1
      fi
      notify-send -e -u low -i "$notif/ja.png" " Normal Blur"
  fi
) 200>"$LOCK"
