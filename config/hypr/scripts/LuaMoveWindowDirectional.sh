#!/usr/bin/env bash
# ==================================================
#  KoolDots (2026)
#  Project URL: https://github.com/LinuxBeginnings
#  License: GNU GPLv3
#  SPDX-License-Identifier: GPL-3.0-or-later
# ==================================================
# Guard directional Lua window movement against Hyprland Lua's no-target
# "invalid workspace" runtime error.

set -u

direction="${1:-}"
case "$direction" in
  l|left)
    direction="left"
    ;;
  r|right)
    direction="right"
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

workspaces="$(hyprctl workspaces -j 2>/dev/null || printf '[]')"
case "$direction" in
  left)
    target_id="$(jq -r --argjson active "$active_id" '[.[] | select((.id < $active) and ((.windows // 0) > 0)) | .id] | max // empty' <<<"$workspaces")"
    ;;
  right)
    target_id="$(jq -r --argjson active "$active_id" '[.[] | select((.id > $active) and ((.windows // 0) > 0)) | .id] | min // empty' <<<"$workspaces")"
    ;;
esac

if ! [[ "${target_id:-}" =~ ^-?[0-9]+$ ]]; then
  exit 0
fi

hyprctl dispatch "hl.dispatch(hl.dsp.window.move({ direction = \"${direction}\" }))" >/dev/null 2>&1 || true
