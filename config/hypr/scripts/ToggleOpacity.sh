#!/usr/bin/env bash
# ==================================================
#  KoolDots (2026)
#  Project URL: https://github.com/LinuxBeginnings
#  License: GNU GPLv3
#  SPDX-License-Identifier: GPL-3.0-or-later
# ==================================================
# Toggle active window opacity using window set_prop (and active_opacity in conf mode).
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

  CURRENT_PROP=$(hyprctl getprop active opacity 2>/dev/null || true)
  CURRENT_OPAQUE=$(hyprctl getprop active opaque 2>/dev/null || true)

  CURRENT_VAL=""
  if [[ -n "$CURRENT_PROP" && "$CURRENT_PROP" != *"not found"* && "$CURRENT_PROP" != *"unknown"* ]]; then
    CURRENT_VAL=$(echo "$CURRENT_PROP" | awk '{v = $1; if (v ~ /^[0-9.]+$/) print v;}')
  fi

  if [[ -z "$CURRENT_VAL" ]]; then
    CURRENT_VAL=$(hyprctl -j getoption decoration:active_opacity 2>/dev/null | jq -r '.float // empty')
  fi
  if [[ -z "$CURRENT_VAL" || "$CURRENT_VAL" == "null" ]]; then
    CURRENT_VAL=$(hyprctl getoption decoration:active_opacity 2>/dev/null | awk 'NR==1{print $2}')
  fi

  IS_FULL=$(awk -v c="${CURRENT_VAL:-1.0}" -v op="${CURRENT_OPAQUE:-false}" 'BEGIN {
    if (op == "true") {
      print "1";
    } else if (c >= 0.999) {
      print "1";
    } else {
      print "0";
    }
  }')

  if [ "$IS_FULL" = "1" ]; then
    TARGET_VAL="$TRANSPARENCY"
    TARGET_PROP="${TRANSPARENCY} ${TRANSPARENCY}"
    OPAQUE_ACTION="false"
  else
    TARGET_VAL="$NORMAL"
    TARGET_PROP="${NORMAL} ${NORMAL}"
    OPAQUE_ACTION="true"
  fi

  if [[ "$hypr_config_mode" == "lua" ]]; then
    # Set window-level property so it affects the active window even when windowrules are active
    hyprctl eval "return hl.dispatch(hl.dsp.window.set_prop({ prop = 'opacity', value = '${TARGET_PROP}' }))" >/dev/null 2>&1 || true
    hyprctl eval "return hl.dispatch(hl.dsp.window.set_prop({ prop = 'opaque', value = '${OPAQUE_ACTION}' }))" >/dev/null 2>&1 || true
    # Also update global active_opacity config
    hyprctl eval "hl.config({ decoration = { active_opacity = ${TARGET_VAL} } })" >/dev/null 2>&1 || true
  else
    hyprctl dispatch setprop active opacity "$TARGET_PROP" >/dev/null 2>&1 || true
    hyprctl dispatch setprop active opaque "$OPAQUE_ACTION" >/dev/null 2>&1 || true
    hyprctl keyword decoration:active_opacity "$TARGET_VAL" >/dev/null 2>&1 || true
  fi
) 200>"$LOCK"
