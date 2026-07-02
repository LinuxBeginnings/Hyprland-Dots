#!/usr/bin/env bash
# ==================================================
#  KoolDots (2026)
#  Project URL: https://github.com/LinuxBeginnings
#  License: GNU GPLv3
#  SPDX-License-Identifier: GPL-3.0-or-later
# ==================================================
# Dispatch layout-sensitive navigation actions per active workspace.
# This keeps SUPER+J/K and SUPER+arrow behavior aligned with workspace rules.

set -u

if ! command -v hyprctl >/dev/null 2>&1; then
  exit 0
fi

LUA_CYCLE_SCRIPT="${XDG_CONFIG_HOME:-$HOME/.config}/hypr/scripts/LuaCycleWindow.sh"

normalize_layout() {
  case "$1" in
  master | dwindle | scrolling | monocle)
    printf '%s\n' "$1"
    ;;
  *)
    printf '\n'
    ;;
  esac
}

get_active_layout() {
  local layout

  layout="$(hyprctl -j activeworkspace 2>/dev/null | jq -r '.tiledLayout // .tiled_layout // .layout // empty' 2>/dev/null || true)"
  layout="$(normalize_layout "$layout")"

  if [[ -z "$layout" ]]; then
    layout="$(hyprctl -j getoption general:layout 2>/dev/null | jq -r '.str // empty' 2>/dev/null || true)"
    layout="$(normalize_layout "$layout")"
  fi

  if [[ -z "$layout" ]]; then
    layout="dwindle"
  fi

  printf '%s\n' "$layout"
}

dispatch_quiet() {
  local dispatcher="$1"
  shift || true
  if (($# > 0)); then
    hyprctl dispatch "$dispatcher" "$@" >/dev/null 2>&1 || true
  else
    hyprctl dispatch "$dispatcher" >/dev/null 2>&1 || true
  fi
}

get_active_window_address() {
  if ! command -v jq >/dev/null 2>&1; then
    printf '\n'
    return 0
  fi
  hyprctl -j activewindow 2>/dev/null | jq -r '.address // empty' 2>/dev/null || true
}

dispatch_changed_focus() {
  local before after dispatcher="$1"
  shift || true
  before="$(get_active_window_address)"
  dispatch_quiet "$dispatcher" "$@"
  after="$(get_active_window_address)"
  [[ -n "$before" && -n "$after" && "$before" != "$after" ]]
}

direction_word() {
  case "$1" in
  l | left) printf 'left\n' ;;
  r | right) printf 'right\n' ;;
  u | up) printf 'up\n' ;;
  d | down) printf 'down\n' ;;
  *) printf 'right\n' ;;
  esac
}

dispatch_lua_focus() {
  local dir_word
  dir_word="$(direction_word "$1")"
  hyprctl dispatch "hl.dsp.focus({ direction = \"$dir_word\" })" >/dev/null 2>&1 || true
}

cycle_lua() {
  local mode="${1:-next}"
  if [[ -x "$LUA_CYCLE_SCRIPT" ]]; then
    "$LUA_CYCLE_SCRIPT" "$mode" >/dev/null 2>&1 || true
    return 0
  fi
  case "$mode" in
  previous | prev | back) dispatch_lua_focus left ;;
  *) dispatch_lua_focus right ;;
  esac
}

cycle_next() {
  local layout="$1"
  case "$layout" in
  scrolling)
    if ! dispatch_changed_focus layoutmsg "focus r"; then
      dispatch_lua_focus right
    fi
    ;;
  monocle)
    if ! dispatch_changed_focus layoutmsg cyclenext; then
      cycle_lua next
    fi
    ;;
  *)
    if ! dispatch_changed_focus cyclenext; then
      cycle_lua next
    fi
    ;;
  esac
}

cycle_prev() {
  local layout="$1"
  case "$layout" in
  scrolling)
    if ! dispatch_changed_focus layoutmsg "focus l"; then
      dispatch_lua_focus left
    fi
    ;;
  monocle)
    if ! dispatch_changed_focus layoutmsg cycleprev; then
      cycle_lua previous
    fi
    ;;
  *)
    if ! dispatch_changed_focus cyclenext prev; then
      cycle_lua previous
    fi
    ;;
  esac
}

focus_by_layout() {
  local layout="$1"
  local direction="$2"

  case "$layout" in
  master)
    if ! dispatch_changed_focus movefocus "$direction"; then
      dispatch_lua_focus "$direction"
    fi
    ;;
  monocle)
    case "$direction" in
    l | u) cycle_prev "$layout" ;;
    *) cycle_next "$layout" ;;
    esac
    ;;
  dwindle | scrolling)
    case "$direction" in
    l | u)
      if [[ "$layout" == "scrolling" ]]; then
        if ! dispatch_changed_focus layoutmsg "focus $direction"; then
          dispatch_lua_focus "$direction"
        fi
      else
        cycle_prev "$layout"
      fi
      ;;
    *)
      if [[ "$layout" == "scrolling" ]]; then
        if ! dispatch_changed_focus layoutmsg "focus $direction"; then
          dispatch_lua_focus "$direction"
        fi
      else
        cycle_next "$layout"
      fi
      ;;
    esac
    ;;
  *)
    if ! dispatch_changed_focus movefocus "$direction"; then
      dispatch_lua_focus "$direction"
    fi
    ;;
  esac
}

layout="$(get_active_layout)"

case "${1:-}" in
cycle-next | next)
  cycle_next "$layout"
  ;;
cycle-prev | prev | previous)
  cycle_prev "$layout"
  ;;
focus-left | left)
  focus_by_layout "$layout" l
  ;;
focus-right | right)
  focus_by_layout "$layout" r
  ;;
focus-up | up)
  focus_by_layout "$layout" u
  ;;
focus-down | down)
  focus_by_layout "$layout" d
  ;;
layout | current-layout | status)
  printf '%s\n' "$layout"
  ;;
*)
  echo "Usage: $(basename "$0") [cycle-next|cycle-prev|focus-left|focus-right|focus-up|focus-down|layout]" >&2
  exit 1
  ;;
esac
