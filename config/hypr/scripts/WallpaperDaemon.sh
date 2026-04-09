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

apply_wallpaper_for_monitor() {
  local monitor="$1"
  local per_monitor_link="$HOME/.config/rofi/.current_wallpaper_${monitor}"
  local per_monitor_current="$HOME/.config/hypr/wallpaper_effects/.wallpaper_current_${monitor}"
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

  if [ -n "$wallpaper_path" ] && [ -f "$wallpaper_path" ]; then
    if ! "$WWW_CMD" img -o "$monitor" "$wallpaper_path" >/dev/null 2>&1; then
      sleep 0.3
      "$WWW_CMD" img -o "$monitor" "$wallpaper_path" >/dev/null 2>&1 &
    fi
  fi
}

while read -r monitor; do
  [ -n "$monitor" ] || continue
  apply_wallpaper_for_monitor "$monitor"
done < <(get_monitors)
