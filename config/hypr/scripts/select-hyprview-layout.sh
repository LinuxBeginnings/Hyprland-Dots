#!/usr/bin/env bash
# ==================================================
#  KoolDots (2026)
#  Project URL: https://github.com/LinuxBeginnings
#  License: GNU GPLv3
#  SPDX-License-Identifier: GPL-3.0-or-later
# ==================================================
# Select and persist Hyprview layout for quickshell toggle

config_home="${XDG_CONFIG_HOME:-$HOME/.config}"
layout_config="$config_home/hypr/UserConfigs/hyprview-layout.conf"
rofi_theme="$config_home/rofi/config-edit.rasi"
default_layout="smartgrid"

layouts=(
  smartgrid
  justified
  masonry
  bands
  hero
  spiral
  satellite
  staggered
  columnar
  vortex
  random
)

current_layout="$default_layout"
if [[ -f "$layout_config" && -r "$layout_config" ]]; then
  saved_layout="$(sed -n '1p' "$layout_config" | tr -d '[:space:]')"
  for layout in "${layouts[@]}"; do
    if [[ "$saved_layout" == "$layout" ]]; then
      current_layout="$saved_layout"
      break
    fi
  done
fi

default_row=0
for i in "${!layouts[@]}"; do
  if [[ "${layouts[$i]}" == "$current_layout" ]]; then
    default_row="$i"
    break
  fi
done

if pidof rofi >/dev/null; then
  pkill rofi
fi

"$config_home/hypr/scripts/RofiFocusedWallpaperLink.sh" >/dev/null 2>&1 || true
choice="$(
  printf '%s\n' "${layouts[@]}" | rofi -i -dmenu -config "$rofi_theme" \
    -p "Hyprview Layout" \
    -mesg "Current layout: $current_layout" \
    -selected-row "$default_row"
)"

[[ -z "$choice" ]] && exit 0

for layout in "${layouts[@]}"; do
  if [[ "$choice" == "$layout" ]]; then
    mkdir -p "$(dirname "$layout_config")"
    printf '%s\n' "$choice" > "$layout_config"
    notify-send -u low "Hyprview layout set to $choice"
    exit 0
  fi
done

notify-send -u normal "Invalid layout selection; keeping current setting"
exit 1
