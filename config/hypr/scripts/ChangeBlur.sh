#!/usr/bin/env bash
# ==================================================
#  KoolDots (2026)
#  Project URL: https://github.com/LinuxBeginnings
#  License: GNU GPLv3
#  SPDX-License-Identifier: GPL-3.0-or-later
# ==================================================
# Script for changing blur levels on the fly with desktop notifications.
# Supports cycling preset levels (Off -> Low -> Medium -> High -> Ultra),
# stepping up/down (--inc / --dec), or selecting explicit levels.
# Uses flock to prevent double-execution from dual-config (.conf + .lua) loading.

set -uo pipefail

notif="${XDG_CONFIG_HOME:-$HOME/.config}/swaync/images"
icons_dir="${XDG_CONFIG_HOME:-$HOME/.config}/swaync/icons"

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

# Pick appropriate icons
if [[ -f "$icons_dir/palette.png" ]]; then
    ICON_ON="$icons_dir/palette.png"
elif [[ -f "$notif/ja.png" ]]; then
    ICON_ON="$notif/ja.png"
else
    ICON_ON="$notif/note.png"
fi

if [[ -f "$notif/note.png" ]]; then
    ICON_OFF="$notif/note.png"
else
    ICON_OFF="$ICON_ON"
fi

(
  flock -n 200 || exit 0

  # Check if blur is currently enabled
  BLUR_ENABLED=$(hyprctl -j getoption decoration:blur:enabled 2>/dev/null | jq -r ".bool // empty")
  if [[ -z "$BLUR_ENABLED" || "$BLUR_ENABLED" == "null" ]]; then
      BLUR_ENABLED=$(hyprctl getoption decoration:blur:enabled 2>/dev/null | awk 'NR==1{print $2}')
  fi

  PASSES=$(hyprctl -j getoption decoration:blur:passes 2>/dev/null | jq -r ".int // empty")
  if [[ -z "$PASSES" || "$PASSES" == "null" ]]; then
      PASSES=$(hyprctl getoption decoration:blur:passes 2>/dev/null | awk 'NR==1{print $2}')
  fi

  # Determine current level (0: Off, 1: Low, 2: Medium, 3: High, 4: Ultra)
  if [[ "$BLUR_ENABLED" == "false" || "$BLUR_ENABLED" == "0" || "${PASSES:-0}" -le 0 ]]; then
      CURRENT_LEVEL=0
  elif [ "${PASSES}" -eq 1 ]; then
      CURRENT_LEVEL=1
  elif [ "${PASSES}" -eq 2 ]; then
      CURRENT_LEVEL=2
  elif [ "${PASSES}" -eq 3 ]; then
      CURRENT_LEVEL=3
  else
      CURRENT_LEVEL=4
  fi

  ACTION="${1:---toggle}"

  case "$ACTION" in
    --inc|+|-inc|inc|up|--up)
      TARGET_LEVEL=$((CURRENT_LEVEL + 1))
      (( TARGET_LEVEL > 4 )) && TARGET_LEVEL=4
      ;;
    --dec|-|-dec|dec|down|--down)
      TARGET_LEVEL=$((CURRENT_LEVEL - 1))
      (( TARGET_LEVEL < 0 )) && TARGET_LEVEL=0
      ;;
    --off|off|0)
      TARGET_LEVEL=0
      ;;
    --low|low|1)
      TARGET_LEVEL=1
      ;;
    --med|--medium|--normal|medium|normal|2)
      TARGET_LEVEL=2
      ;;
    --high|high|3)
      TARGET_LEVEL=3
      ;;
    --ultra|--max|ultra|max|4)
      TARGET_LEVEL=4
      ;;
    --toggle|toggle|"")
      # Cycle: Off (0) -> Low (1) -> Medium (2) -> High (3) -> Ultra (4) -> Off (0)
      case "$CURRENT_LEVEL" in
        0) TARGET_LEVEL=1 ;;
        1) TARGET_LEVEL=2 ;;
        2) TARGET_LEVEL=3 ;;
        3) TARGET_LEVEL=4 ;;
        *) TARGET_LEVEL=0 ;;
      esac
      ;;
    *)
      # Parse numeric arg directly
      if [[ "$ACTION" =~ ^[0-4]$ ]]; then
        TARGET_LEVEL="$ACTION"
      else
        TARGET_LEVEL=$(( (CURRENT_LEVEL + 1) % 5 ))
      fi
      ;;
  esac

  # Map target level to Hyprland blur properties
  case "$TARGET_LEVEL" in
    0)
      SET_ENABLED="false"
      SET_SIZE=0
      SET_PASSES=0
      LEVEL_NAME="Disabled"
      PERCENT=0
      ICON="$ICON_OFF"
      DETAIL="Blur Off"
      ;;
    1)
      SET_ENABLED="true"
      SET_SIZE=3
      SET_PASSES=1
      LEVEL_NAME="Low"
      PERCENT=25
      ICON="$ICON_ON"
      DETAIL="Size: 3 | Passes: 1"
      ;;
    2)
      SET_ENABLED="true"
      SET_SIZE=6
      SET_PASSES=2
      LEVEL_NAME="Medium"
      PERCENT=50
      ICON="$ICON_ON"
      DETAIL="Size: 6 | Passes: 2"
      ;;
    3)
      SET_ENABLED="true"
      SET_SIZE=8
      SET_PASSES=3
      LEVEL_NAME="High"
      PERCENT=75
      ICON="$ICON_ON"
      DETAIL="Size: 8 | Passes: 3"
      ;;
    4|*)
      SET_ENABLED="true"
      SET_SIZE=10
      SET_PASSES=4
      LEVEL_NAME="Ultra"
      PERCENT=100
      ICON="$ICON_ON"
      DETAIL="Size: 10 | Passes: 4"
      ;;
  esac

  if [[ "$hypr_config_mode" == "lua" ]]; then
    hyprctl -r eval "hl.config({ decoration = { blur = { enabled = ${SET_ENABLED}, size = ${SET_SIZE}, passes = ${SET_PASSES}, ignore_opacity = true, xray = false, new_optimizations = true } } })" >/dev/null 2>&1 || true
  else
    if [[ "$SET_ENABLED" == "true" ]]; then
      hyprctl keyword decoration:blur:enabled 1
    else
      hyprctl keyword decoration:blur:enabled 0
    fi
    hyprctl keyword decoration:blur:size "$SET_SIZE"
    hyprctl keyword decoration:blur:passes "$SET_PASSES"
    hyprctl keyword decoration:blur:ignore_opacity 1
    hyprctl keyword decoration:blur:xray 0
    hyprctl keyword decoration:blur:new_optimizations 1
  fi

  # Send notification
  if command -v notify-send >/dev/null 2>&1 && [[ -n "${WAYLAND_DISPLAY:-}${DISPLAY:-}" ]]; then
    notify-send -e \
      -h string:x-canonical-private-synchronous:blur_notif \
      -h int:value:"$PERCENT" \
      -u low \
      -i "$ICON" \
      " Blur: ${LEVEL_NAME}" " ${DETAIL}" 2>/dev/null || true
  fi
) 200>"$LOCK"
