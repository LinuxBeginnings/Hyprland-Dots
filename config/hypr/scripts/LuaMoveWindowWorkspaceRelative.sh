#!/usr/bin/env bash
# ==================================================
#  KoolDots (2026)
#  Project URL: https://github.com/LinuxBeginnings
#  License: GNU GPLv3
#  SPDX-License-Identifier: GPL-3.0-or-later
# ==================================================
# Move the active window to the previous/next numeric workspace through
# the Lua dispatcher. This allows moving into empty workspaces while
# avoiding invalid workspace 0.

set -u

direction="${1:-}"
case "$direction" in
  next|right|+1)
    direction="next"
    ;;
  previous|prev|left|-1)
    direction="previous"
    ;;
  *)
    exit 0
    ;;
esac

active_window="$(hyprctl activewindow -j 2>/dev/null || printf '{}')"
if ! jq -e '.address? and .address != ""' >/dev/null 2>&1 <<<"$active_window"; then
  exit 0
fi

active_workspace="$(hyprctl activeworkspace -j 2>/dev/null || printf '{}')"
active_id="$(jq -r '.id // empty' <<<"$active_workspace")"
if ! [[ "$active_id" =~ ^-?[0-9]+$ ]]; then
  exit 0
fi

case "$direction" in
  next)
    target_id=$((active_id + 1))
    ;;
  previous)
    target_id=$((active_id - 1))
    ;;
esac

if ! [[ "${target_id:-}" =~ ^-?[0-9]+$ ]] || [ "$target_id" -lt 1 ]; then
  exit 0
fi

hyprctl dispatch "hl.dispatch(hl.dsp.window.move({ workspace = ${target_id} }))" >/dev/null 2>&1 || true
