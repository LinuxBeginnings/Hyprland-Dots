#!/usr/bin/env bash
# ==================================================
#  KoolDots (2026)
#  Project URL: https://github.com/LinuxBeginnings
#  License: GNU GPLv3
#  SPDX-License-Identifier: GPL-3.0-or-later
# ==================================================
# Start wallpaper daemon, preferring awww with swww fallback

SCRIPTSDIR="${XDG_CONFIG_HOME:-$HOME/.config}/hypr/scripts"
# shellcheck source=/dev/null
. "$SCRIPTSDIR/WallpaperCmd.sh"

wallpaper_ensure_daemon

wallpaper_link="${XDG_CONFIG_HOME:-$HOME/.config}/hypr/rofi/.current_wallpaper"
wallpaper_current="${XDG_CONFIG_HOME:-$HOME/.config}/hypr/wallpaper_effects/.wallpaper_current"

read_cached_wallpaper() {
  local cache_file="$1"
  [ -f "$cache_file" ] || return 1
  awk 'NF && $0 !~ /^filter/ {print; exit}' "$cache_file"
}

get_monitors() {
  if command -v jq >/dev/null 2>&1; then
    hyprctl monitors -j | jq -r '.[].name'
  else
    hyprctl monitors | awk '/^Monitor/{print $2}'
  fi
}

wait_for_monitors() {
  local monitors=""
  for _ in {1..120}; do
    monitors="$(get_monitors 2>/dev/null | awk 'NF')"
    if [ -n "$monitors" ]; then
      printf '%s\n' "$monitors"
      return 0
    fi
    sleep 0.1
  done
  return 1
}

default_wallpaper_path() {
  local pictures_dir wall_dir
  pictures_dir="$(xdg-user-dir PICTURES 2>/dev/null || echo "$HOME/Pictures")"
  wall_dir="$pictures_dir/wallpapers"

  [ -d "$wall_dir" ] || return 1

  find -L "$wall_dir" -type f \( \
    -iname "*.jpg" -o -iname "*.jpeg" -o -iname "*.png" -o -iname "*.bmp" -o \
    -iname "*.gif" -o -iname "*.webp" -o -iname "*.tiff" \
  \) -print | LC_ALL=C sort | awk 'NR == 1 {print; exit}'
}

apply_wallpaper_for_monitor() {
  local monitor="$1"
  local per_monitor_link="${XDG_CONFIG_HOME:-$HOME/.config}/hypr/rofi/.current_wallpaper_${monitor}"
  local per_monitor_current="${XDG_CONFIG_HOME:-$HOME/.config}/hypr/wallpaper_effects/.wallpaper_current_${monitor}"
  local wallpaper_path=""

  # Prefer per-monitor symlink target if valid
  if [ -L "$per_monitor_link" ]; then
    local resolved
    resolved="$(readlink -f "$per_monitor_link")"
    if [ -n "$resolved" ] && [ -f "$resolved" ]; then
      wallpaper_path="$resolved"
    fi
  fi

  # Fall back to per-monitor files
  if [ -z "$wallpaper_path" ] && [ -f "$per_monitor_link" ]; then
    wallpaper_path="$per_monitor_link"
  fi
  if [ -z "$wallpaper_path" ] && [ -f "$per_monitor_current" ]; then
    wallpaper_path="$per_monitor_current"
  fi

  # Fall back to global files
  if [ -z "$wallpaper_path" ] && [ -L "$wallpaper_link" ]; then
    local resolved_global
    resolved_global="$(readlink -f "$wallpaper_link")"
    if [ -n "$resolved_global" ] && [ -f "$resolved_global" ]; then
      wallpaper_path="$resolved_global"
    fi
  fi
  if [ -z "$wallpaper_path" ] && [ -f "$wallpaper_link" ]; then
    wallpaper_path="$wallpaper_link"
  fi
  if [ -z "$wallpaper_path" ] && [ -f "$wallpaper_current" ]; then
    wallpaper_path="$wallpaper_current"
  fi

  # Last resort: use per-monitor cache
  if [ -z "$wallpaper_path" ]; then
    local cache_file="$WWW_CACHE_DIR/$monitor"
    local cache_fallback=""
    if [ "$WWW_CACHE_DIR" = "$HOME/.cache/awww" ]; then
      cache_fallback="$HOME/.cache/swww/$monitor"
    else
      cache_fallback="$HOME/.cache/awww/$monitor"
    fi
    wallpaper_path="$(read_cached_wallpaper "$cache_file")"
    if [ -z "$wallpaper_path" ] && [ -n "$cache_fallback" ]; then
      wallpaper_path="$(read_cached_wallpaper "$cache_fallback")"
    fi
  fi

  # Final fallback: use the first available wallpaper from the wallpapers directory.
  if [ -z "$wallpaper_path" ]; then
    wallpaper_path="$(default_wallpaper_path 2>/dev/null || true)"
  fi

  if [ -n "$wallpaper_path" ] && [ -f "$wallpaper_path" ]; then
    local resize_mode
    resize_mode="$(wallpaper_resize_mode "$wallpaper_path" "$monitor")"
    if ! "$WWW_CMD" img -o "$monitor" --resize "$resize_mode" "$wallpaper_path" >/dev/null 2>&1; then
      sleep 0.3
      "$WWW_CMD" img -o "$monitor" --resize "$resize_mode" "$wallpaper_path" >/dev/null 2>&1 &
    fi
    printf '%s\n' "$wallpaper_path"
    return 0
  fi

  return 1
}

applied_wallpaper=""
while read -r monitor; do
  [ -n "$monitor" ] || continue
  applied_path="$(apply_wallpaper_for_monitor "$monitor" || true)"
  if [ -z "$applied_wallpaper" ] && [ -n "$applied_path" ] && [ -f "$applied_path" ]; then
    applied_wallpaper="$applied_path"
  fi
done < <(wait_for_monitors || true)

"$SCRIPTSDIR/RofiFocusedWallpaperLink.sh" >/dev/null 2>&1 || true

if [ -n "$applied_wallpaper" ] && [ -x "$SCRIPTSDIR/WallustSwww.sh" ]; then
  "$SCRIPTSDIR/WallustSwww.sh" "$applied_wallpaper" >/dev/null 2>&1 || true
fi
