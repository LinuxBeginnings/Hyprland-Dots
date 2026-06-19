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

  layout="$(hyprctl -j activeworkspace 2>/dev/null | jq -r '.tiledLayout // .tiled_layout // empty' 2>/dev/null || true)"
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

cycle_next() {
  local layout="$1"
  case "$layout" in
  scrolling)
    dispatch_quiet layoutmsg "focus r"
    ;;
  monocle)
    dispatch_quiet layoutmsg cyclenext
    ;;
  *)
    dispatch_quiet cyclenext
    ;;
  esac
}

cycle_prev() {
  local layout="$1"
  case "$layout" in
  scrolling)
    dispatch_quiet layoutmsg "focus l"
    ;;
  monocle)
    dispatch_quiet layoutmsg cycleprev
    ;;
  *)
    dispatch_quiet cyclenext prev
    ;;
  esac
}

focus_by_layout() {
  local layout="$1"
  local direction="$2"

  case "$layout" in
  master)
    dispatch_quiet movefocus "$direction"
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
        dispatch_quiet layoutmsg "focus $direction"
      else
        dispatch_quiet cyclenext prev
      fi
      ;;
    *)
      if [[ "$layout" == "scrolling" ]]; then
        dispatch_quiet layoutmsg "focus $direction"
      else
        dispatch_quiet cyclenext
      fi
      ;;
    esac
    ;;
  *)
    dispatch_quiet movefocus "$direction"
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
