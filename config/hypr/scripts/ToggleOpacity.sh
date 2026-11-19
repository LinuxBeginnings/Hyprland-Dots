#!/usr/bin/env bash
# ==================================================
#  KoolDots (2026)
#  Project URL: https://github.com/LinuxBeginnings
#  License: GNU GPLv3
#  SPDX-License-Identifier: GPL-3.0-or-later
# ==================================================
# Toggle or incrementally adjust active window opacity with desktop notifications.
# Supports cycling opacity levels (100% on first toggle, stepping down by STEP to MIN_OPACITY, then 100%),
# stepping up/down (--inc / --dec), or setting explicit values.
# Uses flock to prevent double-execution from dual-config (.conf + .lua) loading.

set -uo pipefail

LOCK="/tmp/.hypr_toggle_opacity_${HYPRLAND_INSTANCE_SIGNATURE:-default}.lock"
STEP=0.10
MIN_OPACITY=0.40
MAX_OPACITY=1.00

config_home="${XDG_CONFIG_HOME:-$HOME/.config}"
icons_dir="$config_home/swaync/icons"
images_dir="$config_home/swaync/images"

if [[ -f "$icons_dir/palette.png" ]]; then
  ICON="$icons_dir/palette.png"
elif [[ -f "$icons_dir/dropper.png" ]]; then
  ICON="$icons_dir/dropper.png"
elif [[ -f "$images_dir/note.png" ]]; then
  ICON="$images_dir/note.png"
else
  ICON="$images_dir/ja.png"
fi

(
  flock -n 200 || exit 0

  # Get active window info
  ACTIVE_JSON=$(hyprctl activewindow -j 2>/dev/null || true)
  ACTIVE_CLASS=""
  IS_TOGGLED="false"
  if [[ -n "$ACTIVE_JSON" ]]; then
    ACTIVE_CLASS=$(echo "$ACTIVE_JSON" | jq -r '.class // empty' 2>/dev/null || true)
    if echo "$ACTIVE_JSON" | jq -e '.tags // [] | index("opacity_toggled")' >/dev/null 2>&1; then
      IS_TOGGLED="true"
    fi
  fi

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

  # Fallback to 1.0 if detection was empty
  CURRENT_NUM=$(awk -v c="${CURRENT_VAL:-1.0}" 'BEGIN { v = c + 0; if (v <= 0 || v > 1.0) v = 1.0; printf "%.2f", v }')

  # If window is explicitly opaque property true, consider it 1.0
  if [[ "${CURRENT_OPAQUE:-false}" == "true" ]]; then
    CURRENT_NUM="1.00"
  fi

  ACTION="${1:---toggle}"

  case "$ACTION" in
  --inc | + | -inc | inc | up | --up)
    TARGET_NUM=$(awk -v c="$CURRENT_NUM" -v s="$STEP" -v max="$MAX_OPACITY" 'BEGIN {
        v = c + s;
        if (v > max) v = max;
        printf "%.2f", v;
      }')
    ;;
  --dec | - | -dec | dec | down | --down)
    TARGET_NUM=$(awk -v c="$CURRENT_NUM" -v s="$STEP" -v min="$MIN_OPACITY" 'BEGIN {
        v = c - s;
        if (v < min) v = min;
        printf "%.2f", v;
      }')
    ;;
  --toggle | toggle | "")
    # Cycle: 100% on first toggle, then decrease by STEP down to MIN_OPACITY, then 100% and repeat
    if [[ "$IS_TOGGLED" != "true" && "${CURRENT_OPAQUE:-false}" != "true" ]]; then
      TARGET_NUM="1.00"
    else
      TARGET_NUM=$(awk -v c="$CURRENT_NUM" -v s="$STEP" -v min="$MIN_OPACITY" -v max="$MAX_OPACITY" 'BEGIN {
          step_pct = int((s * 100) + 0.5);
          min_pct = int((min * 100) + 0.5);
          max_pct = int((max * 100) + 0.5);
          if (step_pct <= 0) step_pct = 5;
          if (min_pct <= 0) min_pct = 5;
          if (max_pct <= min_pct) max_pct = 100;

          pct = int((c * 100) + 0.5);
          if (pct >= (max_pct - int(step_pct / 2))) {
            target = max_pct - step_pct;
          } else if (pct <= min_pct) {
            target = max_pct;
          } else {
            rem = (pct - min_pct) % step_pct;
            if (rem == 0) {
              target = pct - step_pct;
            } else {
              target = pct - rem;
            }
            if (target < min_pct) target = max_pct;
          }
          printf "%.2f", target / 100.0;
        }')
    fi
    ;;
  *)
    # Parse explicit number / percentage, e.g. 0.85 or 85 or 85%
    RAW_ARG="${ACTION#--}"
    RAW_ARG="${RAW_ARG%\%}"
    TARGET_NUM=$(awk -v a="$RAW_ARG" -v min="$MIN_OPACITY" -v max="$MAX_OPACITY" 'BEGIN {
        v = a + 0;
        if (v > 1.0) v = v / 100.0;
        if (v > max) v = max;
        if (v < min) v = min;
        printf "%.2f", v;
      }')
    ;;
  esac

  TARGET_PROP="${TARGET_NUM} ${TARGET_NUM}"
  PERCENT=$(awk -v v="$TARGET_NUM" 'BEGIN { printf "%d", (v * 100) + 0.5 }')

  if [ "$PERCENT" -ge 99 ]; then
    OPAQUE_ACTION="true"
    DISPLAY_MSG="100% (Opaque)"
  else
    OPAQUE_ACTION="false"
    DISPLAY_MSG="${PERCENT}%"
  fi

  # Set window-level property so it affects the active window even when windowrules are active
  hyprctl eval "return hl.dispatch(hl.dsp.window.set_prop({ prop = 'opacity', value = '${TARGET_PROP}' }))" >/dev/null 2>&1 || true
  hyprctl eval "return hl.dispatch(hl.dsp.window.set_prop({ prop = 'opaque', value = '${OPAQUE_ACTION}' }))" >/dev/null 2>&1 || true
  # Tag window so subsequent toggles know it has entered the cycle
  if [[ "$IS_TOGGLED" != "true" ]]; then
    hyprctl eval "return hl.dispatch(hl.dsp.window.tag({ tag = '+opacity_toggled' }))" >/dev/null 2>&1 || true
  fi
  # Also update global active_opacity config
  hyprctl eval "hl.config({ decoration = { active_opacity = ${TARGET_NUM} } })" >/dev/null 2>&1 || true

  # Send notification
  if command -v notify-send >/dev/null 2>&1 && [[ -n "${WAYLAND_DISPLAY:-}${DISPLAY:-}" ]]; then
    SUBTITLE="${ACTIVE_CLASS:-Active Window}"
    notify-send -e \
      -h string:x-canonical-private-synchronous:opacity_notif \
      -h int:value:"$PERCENT" \
      -u low \
      -i "$ICON" \
      " Opacity: ${DISPLAY_MSG}" " ${SUBTITLE}" 2>/dev/null || true
  fi
) 200>"$LOCK"
