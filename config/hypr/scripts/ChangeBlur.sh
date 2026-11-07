#!/usr/bin/env bash
# ==================================================
#  KoolDots (2026)
#  Project URL: https://github.com/LinuxBeginnings
#  License: GNU GPLv3
#  SPDX-License-Identifier: GPL-3.0-or-later
# ==================================================
# Script for changing blur levels on the fly with desktop notifications.
# Supports cycling preset levels (Off -> Low -> Medium -> High -> Ultra),
# stepping up/down (--inc / --dec), selecting explicit levels, and cycling the
# Hyprland 0.57+ blur variants (--variant-next / --variant <name>).
# Uses flock to prevent double-execution from dual-config (.conf + .lua) loading.

set -uo pipefail

notif="${XDG_CONFIG_HOME:-$HOME/.config}/swaync/images"
icons_dir="${XDG_CONFIG_HOME:-$HOME/.config}/swaync/icons"

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

# Blur variants (Hyprland 0.57+). `variant` is the only blur key older builds do
# not have, so it is probed instead of written blind: on 0.56 the option does not
# exist and a write is a config error. The int hyprctl reports is the index into
# this list, in Hyprland's own order.
BLUR_VARIANTS=(kawase frost ripple drops water fluid_jar prism heat_shimmer acrylic aurora haze)

variant_int() {
    hyprctl -j getoption decoration:blur:variant 2>/dev/null | jq -r '.int // empty' 2>/dev/null
}

variant_supported() {
    [[ "$(variant_int)" =~ ^[0-9]+$ ]]
}

# Current variant name, or kawase when the compositor reports nothing usable.
variant_current() {
    local idx
    idx="$(variant_int)"
    if [[ ! "$idx" =~ ^[0-9]+$ ]]; then
        printf 'kawase'
        return 0
    fi
    # The enum int is already the 0-based index, so haze (10) reads back as haze
    # and not as an empty slot that falls back to kawase.
    printf '%s' "${BLUR_VARIANTS[idx]:-kawase}"
}

# notify_msg <urgency> <title> <body>. The variant paths report and leave, so
# they cannot reuse the level notification at the bottom of this script.
notify_msg() {
    command -v notify-send >/dev/null 2>&1 || return 0
    [[ -n "${WAYLAND_DISPLAY:-}${DISPLAY:-}" ]] || return 0
    notify-send -e -u "$1" -i "$ICON_ON" "$2" "$3" 2>/dev/null || true
}

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

  # Blur variants. Handled before the strength cycle and only when asked for:
  # SUPER ALT O keeps cycling Off -> Low -> Medium -> High -> Ultra as before.
  new_variant=""
  case "$ACTION" in
    --variant-next|--next-variant|variant-next)
      if ! variant_supported; then
        notify_msg critical "Blur Variant" "Requires Hyprland v0.57 or greater"
        exit 0
      fi
      current_variant="$(variant_current)"
      idx=0
      for i in "${!BLUR_VARIANTS[@]}"; do
        if [[ "${BLUR_VARIANTS[i]}" == "$current_variant" ]]; then idx=$i; fi
      done
      new_variant="${BLUR_VARIANTS[$(( (idx + 1) % ${#BLUR_VARIANTS[@]} ))]}"
      ;;
    --variant|variant)
      if ! variant_supported; then
        notify_msg critical "Blur Variant" "Requires Hyprland v0.57 or greater"
        exit 0
      fi
      new_variant="${2:-}"
      if [[ -z "$new_variant" ]]; then
        notify_msg low "Blur Variant: $(variant_current)" "decoration:blur:variant"
        exit 0
      fi
      ;;
  esac

  if [[ -n "$new_variant" ]]; then
    known=0
    for name in "${BLUR_VARIANTS[@]}"; do
      if [[ "$name" == "$new_variant" ]]; then known=1; fi
    done
    if [[ "$known" -eq 0 ]]; then
      notify_msg critical "Blur Variant" "Unknown variant: ${new_variant}"
      exit 1
    fi
    # hl.config through eval, and only the exact reply "ok" counts: the legacy
    # keyword path answers "unknown request" and still exits 0.
    reply="$(hyprctl -r eval "hl.config({ decoration = { blur = { variant = \"${new_variant}\" } } })" 2>/dev/null)"
    if [[ "$reply" != "ok" ]]; then
      notify_msg critical "Blur Variant" "Hyprland rejected variant: ${new_variant}"
      exit 1
    fi
    notify_msg low "Blur Variant: ${new_variant}" "decoration:blur:variant"
    exit 0
  fi

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

  # Name the active variant when it is not the default, so the strength cycle
  # says which one is in play.
  if variant_supported; then
    active_variant="$(variant_current)"
    if [[ "$active_variant" != "kawase" ]]; then
      DETAIL="${DETAIL} | Variant: ${active_variant}"
    fi
  fi

  # Apply blur properties using native Lua hl.config
  hyprctl -r eval "hl.config({ decoration = { blur = { enabled = ${SET_ENABLED}, size = ${SET_SIZE}, passes = ${SET_PASSES}, ignore_opacity = true, xray = false, new_optimizations = true } } })" >/dev/null 2>&1 || true

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
