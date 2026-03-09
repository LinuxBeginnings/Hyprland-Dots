#!/usr/bin/env bash
# ==================================================
#  KoolDots (2026)
#  Project URL: https://github.com/LinuxBeginnings
#  License: GNU GPLv3
#  SPDX-License-Identifier: GPL-3.0-or-later
# ==================================================
# Start wallpaper daemon, preferring awww with swww fallback

if command -v awww-daemon >/dev/null 2>&1 && command -v awww >/dev/null 2>&1; then
  WWW="awww"
  DAEMON="awww-daemon"
elif command -v swww-daemon >/dev/null 2>&1 && command -v swww >/dev/null 2>&1; then
  WWW="swww"
  DAEMON="swww-daemon"
else
  exit 0
fi

$DAEMON --format xrgb &

wallpaper_link="$HOME/.config/rofi/.current_wallpaper"
wallpaper_current="$HOME/.config/hypr/wallpaper_effects/.wallpaper_current"
wallpaper_path=""

if [ -L "$wallpaper_link" ]; then
  wallpaper_path="$(readlink -f "$wallpaper_link")"
elif [ -f "$wallpaper_link" ]; then
  wallpaper_path="$wallpaper_link"
elif [ -f "$wallpaper_current" ]; then
  wallpaper_path="$wallpaper_current"
fi

if [ -n "$wallpaper_path" ] && [ -f "$wallpaper_path" ]; then
  $WWW img "$wallpaper_path" >/dev/null 2>&1 &
fi
