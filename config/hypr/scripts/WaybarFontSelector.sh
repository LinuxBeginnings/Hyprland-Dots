#!/usr/bin/env bash
# ==================================================
#  KoolDots (2026)
#  Project URL: https://github.com/LinuxBeginnings
#  License: GNU GPLv3
#  SPDX-License-Identifier: GPL-3.0-or-later
# ==================================================
# Launcher for Waybar Font & Size Settings.
# Prefers the Quickshell GUI applet; falls back to Rofi if Quickshell is unavailable.

set -euo pipefail

CONFIG_HOME="${XDG_CONFIG_HOME:-$HOME/.config}"
HYPR_DIR="${KOOLDOTS_HYPR_DIR:-$CONFIG_HOME/hypr}"
QS_APP_DIR="$CONFIG_HOME/quickshell/waybar-font"
ENGINE="$HYPR_DIR/scripts/WaybarFont.sh"

# If Quickshell app directory is missing in ~/.config, look in repository or installed hypr
if [[ ! -d "$QS_APP_DIR" && -d "$HYPR_DIR/../quickshell/waybar-font" ]]; then
  QS_APP_DIR="$(cd "$HYPR_DIR/../quickshell/waybar-font" && pwd)"
fi

# Fallback: Rofi-based font and size selector
rofi_fallback() {
  local rofi_theme="$HYPR_DIR/rofi/config-edit.rasi"
  local rofi_args=()
  [[ -f "$rofi_theme" ]] && rofi_args=(-config "$rofi_theme")

  local action
  action=$(printf '1. Select Font Family\n2. Select Font Size\n3. Restore Defaults\n4. Exit' | rofi -dmenu -i "${rofi_args[@]}" -p "Waybar Font" -mesg "Waybar Font & Scaling Settings") || exit 0

  case "$action" in
    1*)
      local font
      font=$("$ENGINE" list-fonts | rofi -dmenu -i "${rofi_args[@]}" -p "Select Font" -mesg "Choose Waybar font family") || exit 0
      if [[ -n "$font" ]]; then
        "$ENGINE" apply "$font" "$("$ENGINE" get-size)"
      fi
      ;;
    2*)
      local size
      size=$(printf '10\n11\n12\n13\n14\n15\n16\n18\n20\n22\n24' | rofi -dmenu -i "${rofi_args[@]}" -p "Font Size" -mesg "Choose Waybar font size (px)") || exit 0
      if [[ -n "$size" ]]; then
        "$ENGINE" apply "$("$ENGINE" get-font)" "$size"
      fi
      ;;
    3*)
      "$ENGINE" restore
      ;;
    *)
      exit 0
      ;;
  esac
}

# Try Quickshell first
if command -v quickshell >/dev/null 2>&1 && [[ -d "$QS_APP_DIR" ]]; then
  # Kill existing font selector instance if already open
  pkill -f 'quickshell.*waybar-font' 2>/dev/null || true
  quickshell -p "$QS_APP_DIR" >/dev/null 2>&1 &
elif command -v qs >/dev/null 2>&1 && [[ -d "$QS_APP_DIR" ]]; then
  pkill -f 'qs.*waybar-font' 2>/dev/null || true
  qs -p "$QS_APP_DIR" >/dev/null 2>&1 &
elif command -v rofi >/dev/null 2>&1; then
  rofi_fallback
else
  echo "Error: Neither quickshell nor rofi is available to launch Waybar Font Settings." >&2
  exit 1
fi
