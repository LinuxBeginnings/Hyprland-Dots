#!/usr/bin/env bash
# ==================================================
#  KoolDots (2026)
#  Project URL: https://github.com/LinuxBeginnings
#  License: GNU GPLv3
#  SPDX-License-Identifier: GPL-3.0-or-later
# ==================================================
# Toggle active_opacity using Lua hl.config (or legacy keyword in conf mode).
# Uses flock to prevent double-execution from dual-config (.conf + .lua) loading.

TRANSPARENCY=0.85
NORMAL=1.0
LOCK="/tmp/.hypr_toggle_opacity_${HYPRLAND_INSTANCE_SIGNATURE:-default}.lock"

config_home="${XDG_CONFIG_HOME:-$HOME/.config}"
hypr_dir="$config_home/hypr"
lua_entry="$hypr_dir/hyprland.lua"
legacy_lua_entry="$config_home/hyprland.lua"

if [[ -f "$lua_entry" || -f "$legacy_lua_entry" ]]; then
    hypr_config_mode="lua"
else
    hypr_config_mode="conf"
fi

(
  flock -n 200 || exit 0

  CURRENT=$(hyprctl -j getoption decoration:active_opacity 2>/dev/null | jq -r '.float // empty')
  if [[ -z "$CURRENT" || "$CURRENT" == "null" ]]; then
    CURRENT=$(hyprctl getoption decoration:active_opacity 2>/dev/null | awk 'NR==1{print $2}')
  fi

  IS_FULL=$(awk -v c="${CURRENT:-1.0}" 'BEGIN {print (c >= 0.999) ? "1" : "0"}')

  if [ "$IS_FULL" = "1" ]; then
    TARGET="$TRANSPARENCY"
  else
    TARGET="$NORMAL"
  fi

  if [[ "$hypr_config_mode" == "lua" ]]; then
    hyprctl eval "hl.config({ decoration = { active_opacity = ${TARGET} } })"
  else
    hyprctl keyword decoration:active_opacity "$TARGET"
  fi
) 200>"$LOCK"
