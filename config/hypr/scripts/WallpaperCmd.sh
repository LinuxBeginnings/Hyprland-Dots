#!/usr/bin/env bash
# ==================================================
#  KoolDots (2026)
#  Project URL: https://github.com/LinuxBeginnings
#  License: GNU GPLv3
#  SPDX-License-Identifier: GPL-3.0-or-later
# ==================================================
# Wallpaper command selector (awww preferred, swww fallback)

if command -v awww >/dev/null 2>&1; then
  WWW_CMD="awww"
  WWW_DAEMON="awww-daemon"
  WWW_CACHE_DIR="$HOME/.cache/awww"
  WWW_DAEMON_ARGS=()
  WWW_MIGRATION_MARKER="$WWW_CACHE_DIR/.cache_cleared"
else
  WWW_CMD="swww"
  WWW_DAEMON="swww-daemon"
  WWW_CACHE_DIR="$HOME/.cache/swww"
  WWW_DAEMON_ARGS=(--format xrgb)
fi
# One-time cache clear when migrating from swww to awww
if [ "$WWW_CMD" = "awww" ]; then
  mkdir -p "$WWW_CACHE_DIR"
  if [ ! -f "$WWW_MIGRATION_MARKER" ]; then
    awww clear-cache >/dev/null 2>&1 || true
    mkdir -p "$WWW_CACHE_DIR"
    touch "$WWW_MIGRATION_MARKER"
  fi
fi

wallpaper_monitor_dimensions() {
  local monitor="${1:-}"
  local dims=""

  command -v hyprctl >/dev/null 2>&1 || return 1

  if command -v jq >/dev/null 2>&1; then
    if [ -n "$monitor" ]; then
      dims="$(hyprctl monitors -j 2>/dev/null | jq -r --arg mon "$monitor" '.[] | select(.name == $mon) | "\(.width) \(.height)"' | awk 'NF == 2 {print; exit}')"
    else
      dims="$(hyprctl monitors -j 2>/dev/null | jq -r '.[] | select(.focused == true) | "\(.width) \(.height)"' | awk 'NF == 2 {print; exit}')"
      if [ -z "$dims" ]; then
        dims="$(hyprctl monitors -j 2>/dev/null | jq -r '.[0] | "\(.width) \(.height)"' | awk 'NF == 2 {print; exit}')"
      fi
    fi
  fi

  if [ -z "$dims" ]; then
    dims="$(hyprctl monitors 2>/dev/null | awk -v mon="$monitor" '
      $1=="Monitor" {current=$2; target=(mon=="" || current==mon)}
      target {
        if (match($0, /[0-9]+x[0-9]+@/)) {
          res = substr($0, RSTART, RLENGTH)
          sub(/@.*/, "", res)
          split(res, xy, "x")
          print xy[1], xy[2]
          exit
        }
      }
    ')"
  fi

  [ -n "$dims" ] || return 1
  printf '%s\n' "$dims"
}

wallpaper_image_dimensions() {
  local image_path="$1"
  local dims=""

  [ -n "$image_path" ] && [ -f "$image_path" ] || return 1

  if command -v magick >/dev/null 2>&1; then
    dims="$(magick identify -ping -format '%w %h' "${image_path}[0]" 2>/dev/null || true)"
    [ -n "$dims" ] || dims="$(magick identify -ping -format '%w %h' "$image_path" 2>/dev/null || true)"
  elif command -v identify >/dev/null 2>&1; then
    dims="$(identify -ping -format '%w %h' "${image_path}[0]" 2>/dev/null || true)"
    [ -n "$dims" ] || dims="$(identify -ping -format '%w %h' "$image_path" 2>/dev/null || true)"
  fi

  [ -n "$dims" ] || return 1
  printf '%s\n' "$dims"
}

wallpaper_resize_mode() {
  local image_path="$1"
  local monitor="${2:-}"
  local mode="${WALLPAPER_RESIZE_MODE:-auto}"
  local mon_w mon_h img_w img_h

  mode="${mode,,}"
  case "$mode" in
    fit|crop)
      printf '%s\n' "$mode"
      return 0
      ;;
    auto|"")
      ;;
    *)
      mode="auto"
      ;;
  esac

  if ! read -r mon_w mon_h < <(wallpaper_monitor_dimensions "$monitor"); then
    printf '%s\n' "crop"
    return 0
  fi
  if ! read -r img_w img_h < <(wallpaper_image_dimensions "$image_path"); then
    printf '%s\n' "crop"
    return 0
  fi

  if [ "$img_w" -lt "$mon_w" ] || [ "$img_h" -lt "$mon_h" ]; then
    printf '%s\n' "crop"
    return 0
  fi

  # Auto mode prefers full-screen fill; set WALLPAPER_RESIZE_MODE=fit to preserve full image.
  printf '%s\n' "crop"
}
export WWW_CMD WWW_DAEMON WWW_CACHE_DIR WWW_DAEMON_ARGS WWW_MIGRATION_MARKER
