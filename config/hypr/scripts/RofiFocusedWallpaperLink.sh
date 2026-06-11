#!/usr/bin/env bash
# ==================================================
#  KoolDots (2026)
#  Project URL: https://github.com/LinuxBeginnings
#  License: GNU GPLv3
#  SPDX-License-Identifier: GPL-3.0-or-later
# ==================================================
# Resolve focused-monitor wallpaper and refresh rofi focused wallpaper link.

SCRIPTSDIR="$HOME/.config/hypr/scripts"
ROFI_FOCUSED_LINK="$HOME/.config/rofi/.current_wallpaper_focused"
ROFI_GLOBAL_LINK="$HOME/.config/rofi/.current_wallpaper"
WALLPAPER_CURRENT="$HOME/.config/hypr/wallpaper_effects/.wallpaper_current"

# shellcheck source=/dev/null
. "$SCRIPTSDIR/WallpaperCmd.sh" 2>/dev/null || true

read_cached_wallpaper() {
  local cache_file="$1"
  [[ -f "$cache_file" ]] || return 1
  awk 'NF && $0 !~ /^filter/ {print; exit}' "$cache_file"
}

read_wallpaper_from_query() {
  local monitor="$1"
  [[ -n "$monitor" ]] || return 1
  [[ -n "${WWW_CMD:-}" ]] || return 1
  command -v "$WWW_CMD" >/dev/null 2>&1 || return 1
  "$WWW_CMD" query 2>/dev/null | awk -v mon="$monitor" '
    {
      line=$0
      sub(/^Monitor[[:space:]]+/, "", line)
      sub(/^:[[:space:]]*/, "", line)
      mon_name=line
      sub(/:.*/, "", mon_name)
      gsub(/^[[:space:]]+|[[:space:]]+$/, "", mon_name)
      if (mon_name != mon) next

      path=line
      sub(/^.*image:[[:space:]]*/, "", path)
      gsub(/^[[:space:]]+|[[:space:]]+$/, "", path)
      if (path != line && length(path) > 0) {
        print path
        exit
      }
    }
  '
}

resolve_link_or_file() {
  local path="$1"
  local resolved=""
  if [[ -L "$path" ]]; then
    resolved="$(readlink -f "$path" 2>/dev/null || true)"
    if [[ -n "$resolved" && -f "$resolved" ]]; then
      printf '%s\n' "$resolved"
      return 0
    fi
  fi
  if [[ -f "$path" ]]; then
    printf '%s\n' "$path"
    return 0
  fi
  return 1
}

get_active_workspace_monitor() {
  command -v hyprctl >/dev/null 2>&1 || return 1
  if command -v jq >/dev/null 2>&1; then
    hyprctl activeworkspace -j 2>/dev/null | jq -r '.monitor // empty' | head -n1
  else
    hyprctl monitors 2>/dev/null | awk '/^Monitor/{name=$2} /focused: yes/{print name; exit}'
  fi
}

get_focused_monitor() {
  command -v hyprctl >/dev/null 2>&1 || return 1
  if command -v jq >/dev/null 2>&1; then
    hyprctl monitors -j 2>/dev/null | jq -r '.[] | select(.focused) | .name' | head -n1
  else
    hyprctl monitors 2>/dev/null | awk '/^Monitor/{name=$2} /focused: yes/{print name; exit}'
  fi
}

monitor_exists() {
  local monitor="$1"
  [[ -n "$monitor" ]] || return 1
  command -v hyprctl >/dev/null 2>&1 || return 1
  if command -v jq >/dev/null 2>&1; then
    hyprctl monitors -j 2>/dev/null | jq -r --arg mon "$monitor" '.[] | select(.name == $mon) | .name' | grep -qx "$monitor"
  else
    hyprctl monitors 2>/dev/null | awk '/^Monitor/{print $2}' | grep -qx "$monitor"
  fi
}

resolve_target_monitor() {
  local monitor=""
  monitor="$(get_active_workspace_monitor 2>/dev/null || true)"
  if monitor_exists "$monitor"; then
    printf '%s\n' "$monitor"
    return 0
  fi
  monitor="$(get_focused_monitor 2>/dev/null || true)"
  if [[ -n "$monitor" ]]; then
    printf '%s\n' "$monitor"
    return 0
  fi
  return 1
}

read_wallpaper_from_cache() {
  local monitor="$1"
  local cache_root="${WWW_CACHE_DIR:-$HOME/.cache/awww}"
  local cache_file="$cache_root/$monitor"
  local fallback_cache=""
  local path=""

  case "$cache_root" in
    "$HOME/.cache/awww")
      fallback_cache="$HOME/.cache/swww/$monitor"
      ;;
    "$HOME/.cache/swww")
      fallback_cache="$HOME/.cache/awww/$monitor"
      ;;
  esac

  path="$(read_cached_wallpaper "$cache_file" 2>/dev/null || true)"
  if [[ -z "$path" && -n "$fallback_cache" ]]; then
    path="$(read_cached_wallpaper "$fallback_cache" 2>/dev/null || true)"
  fi
  [[ -n "$path" && -f "$path" ]] || return 1
  printf '%s\n' "$path"
}

resolve_focused_wallpaper() {
  local monitor="$1"
  local path=""
  local per_monitor_link=""
  local per_monitor_current=""

  if [[ -n "$monitor" ]]; then
    per_monitor_link="$HOME/.config/rofi/.current_wallpaper_${monitor}"
    per_monitor_current="$HOME/.config/hypr/wallpaper_effects/.wallpaper_current_${monitor}"

    path="$(read_wallpaper_from_query "$monitor" 2>/dev/null || true)"
    if [[ -z "$path" ]]; then
      path="$(resolve_link_or_file "$per_monitor_link" 2>/dev/null || true)"
    fi
    if [[ -z "$path" ]]; then
      path="$(resolve_link_or_file "$per_monitor_current" 2>/dev/null || true)"
    fi
    if [[ -z "$path" ]]; then
      path="$(read_wallpaper_from_cache "$monitor" 2>/dev/null || true)"
    fi
  fi

  if [[ -z "$path" ]]; then
    path="$(resolve_link_or_file "$ROFI_GLOBAL_LINK" 2>/dev/null || true)"
  fi
  if [[ -z "$path" ]]; then
    path="$(resolve_link_or_file "$WALLPAPER_CURRENT" 2>/dev/null || true)"
  fi

  [[ -n "$path" && -f "$path" ]] || return 1
  printf '%s\n' "$path"
}

main() {
  local target_monitor=""
  local wallpaper_path=""

  target_monitor="$(resolve_target_monitor 2>/dev/null || true)"
  wallpaper_path="$(resolve_focused_wallpaper "$target_monitor" 2>/dev/null || true)"
  [[ -n "$wallpaper_path" && -f "$wallpaper_path" ]] || exit 1

  mkdir -p "$(dirname "$ROFI_FOCUSED_LINK")"
  ln -sf "$wallpaper_path" "$ROFI_FOCUSED_LINK"
}

main "$@"
