#!/usr/bin/env bash
# ==================================================
#  KoolDots (2026)
#  Project URL: https://github.com/LinuxBeginnings
#  License: GNU GPLv3
#  SPDX-License-Identifier: GPL-3.0-or-later
# ==================================================
# Backend for the Quickshell wallpaper carousel
# (~/.config/quickshell/wallpaper).
#
# Subcommands:
#   list                                   every wallpaper, one path per line
#   current                                wallpaper on the focused monitor
#   apply PATH [--monitor NAME]            set a wallpaper and its theming
#              [--no-theming]
#   toggle | open | close | isOpen         drive the carousel panel
#   folder                                 the folder the list comes from
#   select                                 the carousel where it can run,
#                                          WallpaperSelect.sh where it cannot
#
# `open` and `select` also take `--query TEXT`, which opens the deck already
# filtered. It is the same filter the search bar writes, so it opens filled.
#
# The carousel previews still images. Videos, GIFs and the ImageMagick effects
# stay with WallpaperSelect.sh (SUPER W) and WallpaperEffects.sh
# (SUPER SHIFT W); both keep working unchanged.
#
# Applying reuses WallpaperCmd.sh (daemon, resize mode) and WallustSwww.sh, so
# a wallpaper picked in the carousel leaves the same state behind as one picked
# in the rofi menu.

set -u

config_home="${XDG_CONFIG_HOME:-$HOME/.config}"
scripts_dir="$config_home/hypr/scripts"
# The applet installs with the quickshell tree, not under hypr/.
widget_dir="$config_home/quickshell/wallpaper"
qs_target="wallpaper-carousel"
rofi_script="$scripts_dir/WallpaperSelect.sh"

# The folder WallpaperSelect.sh reads. A capitalised Wallpapers/ is common (the
# XDG pictures folder is uppercase on some installs, and hand-made collections
# often follow suit), so it is accepted when the lowercase one is absent.
# KOOLDOTS_WALLPAPER_DIR points the carousel somewhere else without editing the
# script.
resolve_wall_dir() {
  local pictures="$1"
  if [ -d "$pictures/wallpapers" ]; then
    printf '%s\n' "$pictures/wallpapers"
    return 0
  fi
  if [ -d "$pictures/Wallpapers" ]; then
    printf '%s\n' "$pictures/Wallpapers"
    return 0
  fi
  # Neither exists: name the one the dots create, so the message is actionable.
  printf '%s\n' "$pictures/wallpapers"
}

if [ -n "${KOOLDOTS_WALLPAPER_DIR:-}" ]; then
  wall_dir="$KOOLDOTS_WALLPAPER_DIR"
else
  pictures_dir="$(xdg-user-dir PICTURES 2>/dev/null || true)"
  [ -n "$pictures_dir" ] || pictures_dir="$HOME/Pictures"
  wall_dir="$(resolve_wall_dir "$pictures_dir")"
fi

wallpaper_current="$config_home/hypr/wallpaper_effects/.wallpaper_current"
wallpaper_base="$config_home/hypr/wallpaper_effects/.wallpaper_base"
wallpaper_link="$config_home/hypr/rofi/.current_wallpaper"

have() { command -v "$1" >/dev/null 2>&1; }

notify() {
  have notify-send && notify-send -a "Wallpaper" "$1" "$2" >/dev/null 2>&1
  return 0
}

err() { printf '%s\n' "$1" >&2; }

focused_monitor() {
  local monitor=""
  have hyprctl || return 1
  if have jq; then
    monitor="$(hyprctl monitors -j 2>/dev/null |
      jq -r '.[] | select(.focused) | .name' 2>/dev/null | head -n 1)"
  fi
  if [ -z "$monitor" ]; then
    monitor="$(hyprctl monitors 2>/dev/null |
      awk '/^Monitor/ {name=$2} /focused: yes/ {print name; exit}')"
  fi
  [ -n "$monitor" ] || return 1
  printf '%s\n' "$monitor"
}

# --------------------------------------------------------------- wallpaper --

list_wallpapers() {
  [ -d "$wall_dir" ] || return 0
  find -L "$wall_dir" -type f \( \
    -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.png' -o -iname '*.webp' \) \
    -print0 2>/dev/null | sort -z | tr '\0' '\n'
}

# The symlink keeps pointing at the original file, so reading it back gives the
# path the carousel can match against its list. The `.wallpaper_current` copies
# are fallbacks for a session that has never applied a wallpaper with this
# script.
current_wallpaper() {
  local monitor="" candidate=""

  monitor="$(focused_monitor 2>/dev/null || true)"
  if [ -n "$monitor" ]; then
    candidate="$config_home/hypr/rofi/.current_wallpaper_$monitor"
    if [ -L "$candidate" ]; then
      readlink -f "$candidate" 2>/dev/null && return 0
    fi
    candidate="$config_home/hypr/wallpaper_effects/.wallpaper_current_$monitor"
    [ -f "$candidate" ] && { printf '%s\n' "$candidate"; return 0; }
  fi

  if [ -L "$wallpaper_link" ]; then
    readlink -f "$wallpaper_link" 2>/dev/null && return 0
  fi
  [ -f "$wallpaper_current" ] && { printf '%s\n' "$wallpaper_current"; return 0; }
  return 1
}

apply_wallpaper() {
  local path="$1" monitor="${2:-}" theming="${3:-1}"
  local resize_mode=""

  if [ ! -f "$path" ]; then
    err "no such wallpaper: $path"
    return 1
  fi

  # shellcheck source=/dev/null
  . "$scripts_dir/WallpaperCmd.sh"

  if ! wallpaper_ensure_daemon; then
    notify "Wallpaper not set" "The wallpaper daemon ($WWW_DAEMON) is not available."
    err "wallpaper daemon unavailable"
    return 1
  fi

  [ -n "$monitor" ] || monitor="$(focused_monitor 2>/dev/null || true)"
  [ -n "$monitor" ] || {
    notify "Wallpaper not set" "Could not detect the focused monitor."
    err "no focused monitor"
    return 1
  }

  resize_mode="$(wallpaper_resize_mode "$path" "$monitor")"

  # The carousel cross-fades the backdrop itself, so the set is instant and
  # there is nothing to fade twice.
  "$WWW_CMD" img -o "$monitor" --resize "$resize_mode" \
    --transition-type none "$path" ||
    "$WWW_CMD" img -o "$monitor" --resize "$resize_mode" "$path" || {
    notify "Wallpaper not set" "Could not apply $(basename "$path")."
    err "failed to apply $path"
    return 1
  }

  # Per-monitor state. The global link and .wallpaper_current are written by
  # WallustSwww.sh below, which every other wallpaper path already goes
  # through.
  mkdir -p "$(dirname "$wallpaper_base")" "$(dirname "$wallpaper_link")"
  ln -sf "$path" "$config_home/hypr/rofi/.current_wallpaper_$monitor" || true
  cp -f "$path" "$config_home/hypr/wallpaper_effects/.wallpaper_current_$monitor" || true
  cp -f "$path" "$config_home/hypr/wallpaper_effects/.wallpaper_base_$monitor" || true
  cp -f "$path" "$wallpaper_base" || true

  if [ "$theming" = "0" ]; then
    printf '%s\n' "$path"
    return 0
  fi

  if ! "$scripts_dir/WallustSwww.sh" "$path"; then
    notify "Wallust failed" "Wallpaper theme not refreshed"
    return 1
  fi

  if [ -x "$scripts_dir/Refresh.sh" ]; then
    "$scripts_dir/Refresh.sh" >/dev/null 2>&1 || true
  fi

  printf '%s\n' "$path"
}

# ------------------------------------------------------------------- panel --

qs_ipc() { quickshell ipc -p "$widget_dir" call "$qs_target" "$@" >/dev/null 2>&1; }

# Quickshell installed with the applet missing is the same dead end as no
# quickshell at all.
panel_available() {
  have quickshell && [ -f "$widget_dir/shell.qml" ]
}

launch_panel() {
  quickshell -p "$widget_dir" --daemonize >/dev/null 2>&1

  local attempt
  for ((attempt = 1; attempt <= 50; attempt++)); do
    sleep 0.1
    qs_ipc isOpen && return 0
  done

  err "quickshell did not start"
  return 1
}

# Reads the optional --query TEXT of open/select into $query.
parse_query() {
  query=""
  while [ $# -gt 0 ]; do
    case "$1" in
      --query)
        query="${2:-}"
        shift 2 || shift
        ;;
      *)
        err "unexpected argument: $1"
        exit 2
        ;;
    esac
  done
}

# A query opens the deck rather than toggling it: the caller asked for a
# filtered deck, and toggling a visible one would close it instead.
open_panel() {
  local query="${1:-}"
  if [ -n "$query" ]; then
    qs_ipc openWith "$query" && return 0
    launch_panel && qs_ipc openWith "$query"
    return $?
  fi
  qs_ipc open && return 0
  launch_panel && qs_ipc open
}

toggle_panel() {
  qs_ipc toggle && return 0
  launch_panel && qs_ipc open
}

# The keybind entry point: the same wallpaper menu the dots have always had,
# with the carousel in front of it where Quickshell is installed.
select_wallpaper() {
  local query="${1:-}"
  if panel_available; then
    if [ -n "$query" ]; then
      open_panel "$query" && return 0
    else
      toggle_panel && return 0
    fi
  fi
  if [ -x "$rofi_script" ]; then
    exec "$rofi_script"
  fi
  notify "Wallpaper menu" "No wallpaper menu is available on this system."
  err "no wallpaper menu available"
  return 1
}

case "${1:-select}" in
  list)
    list_wallpapers
    ;;
  folder)
    printf '%s\n' "$wall_dir"
    ;;
  current)
    current_wallpaper
    ;;
  apply)
    shift
    path=""
    monitor=""
    theming=1
    while [ $# -gt 0 ]; do
      case "$1" in
        --monitor)
          monitor="${2:-}"
          shift 2 || shift
          ;;
        --no-theming)
          theming=0
          shift
          ;;
        *)
          if [ -z "$path" ]; then path="$1"; else err "unexpected argument: $1"; exit 2; fi
          shift
          ;;
      esac
    done
    [ -n "$path" ] || { err "usage: $0 apply PATH [--monitor NAME] [--no-theming]"; exit 2; }
    apply_wallpaper "$path" "$monitor" "$theming"
    ;;
  toggle)
    toggle_panel
    ;;
  open)
    shift
    query=""
    parse_query "$@"
    open_panel "$query"
    ;;
  close)
    qs_ipc close
    ;;
  isOpen)
    qs_ipc isOpen
    ;;
  select)
    shift
    query=""
    parse_query "$@"
    select_wallpaper "$query"
    ;;
  *)
    err "usage: $0 [list|folder|current|apply PATH [--monitor NAME] [--no-theming]|toggle|open [--query TEXT]|close|isOpen|select [--query TEXT]]"
    exit 2
    ;;
esac
