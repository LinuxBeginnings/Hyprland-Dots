#!/usr/bin/env bash
# ==================================================
#  KoolDots (2026)
#  Project URL: https://github.com/LinuxBeginnings
#  License: GNU GPLv3
#  SPDX-License-Identifier: GPL-3.0-or-later
# ==================================================
# Start wallpaper daemon, preferring awww with swww fallback

SCRIPTSDIR="$HOME/.config/hypr/scripts"
# shellcheck source=/dev/null
. "$SCRIPTSDIR/WallpaperCmd.sh"

if command -v "$WWW_DAEMON" >/dev/null 2>&1 && command -v "$WWW_CMD" >/dev/null 2>&1; then
  "$WWW_DAEMON" "${WWW_DAEMON_ARGS[@]}" &
fi

# Give the daemon a moment to become ready
for _ in {1..20}; do
  "$WWW_CMD" query >/dev/null 2>&1 && break
  sleep 0.1
done

wallpaper_link="$HOME/.config/rofi/.current_wallpaper"
wallpaper_current="$HOME/.config/hypr/wallpaper_effects/.wallpaper_current"
wallpaper_path=""

# Prefer the symlink target if it's valid
if [ -L "$wallpaper_link" ]; then
  resolved="$(readlink -f "$wallpaper_link")"
  if [ -n "$resolved" ] && [ -f "$resolved" ]; then
    wallpaper_path="$resolved"
  fi
fi

# Fall back to link file or copied current wallpaper
if [ -z "$wallpaper_path" ] && [ -f "$wallpaper_link" ]; then
  wallpaper_path="$wallpaper_link"
fi
if [ -z "$wallpaper_path" ] && [ -f "$wallpaper_current" ]; then
  wallpaper_path="$wallpaper_current"
fi

# Last resort: use cached swww/awww wallpaper paths
if [ -z "$wallpaper_path" ]; then
  for cache_dir in "$HOME/.cache/awww" "$HOME/.cache/swww"; do
    [ -d "$cache_dir" ] || continue
    for cache_file in "$cache_dir"/*; do
      [ -f "$cache_file" ] || continue
      candidate="$(awk 'NF && $0 !~ /^filter/ {print; exit}' "$cache_file")"
      if [ -n "$candidate" ] && [ -f "$candidate" ]; then
        wallpaper_path="$candidate"
        break
      fi
    done
    [ -n "$wallpaper_path" ] && break
  done
fi

if [ -n "$wallpaper_path" ] && [ -f "$wallpaper_path" ]; then
  if ! "$WWW_CMD" img "$wallpaper_path" >/dev/null 2>&1; then
    # Retry once after a short delay
    sleep 0.3
    "$WWW_CMD" img "$wallpaper_path" >/dev/null 2>&1 &
  fi
fi
