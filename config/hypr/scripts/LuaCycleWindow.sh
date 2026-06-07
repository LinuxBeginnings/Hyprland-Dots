#!/usr/bin/env bash
# ==================================================
#  KoolDots (2026)
#  Project URL: https://github.com/LinuxBeginnings
#  License: GNU GPLv3
#  SPDX-License-Identifier: GPL-3.0-or-later
# ==================================================
# Cycle focus through visible windows on the active workspace using the
# Hyprland Lua dispatcher API. This avoids cyclenext/focuswindow no-ops on
# Lua config builds.

set -u

direction="${1:-next}"
case "$direction" in
  next|forward|f)
    direction="next"
    ;;
  previous|prev|back|b)
    direction="previous"
    ;;
  *)
    exit 0
    ;;
esac

active_window="$(hyprctl activewindow -j 2>/dev/null || printf '{}')"
active_address="$(jq -r '.address // empty' <<<"$active_window")"
active_workspace="$(jq -r '.workspace.id // empty' <<<"$active_window")"

if [[ -z "$active_address" ]] || ! [[ "$active_workspace" =~ ^-?[0-9]+$ ]]; then
  exit 0
fi

clients="$(hyprctl clients -j 2>/dev/null || printf '[]')"
target_address="$(
  jq -r \
    --arg active_address "$active_address" \
    --argjson active_workspace "$active_workspace" \
    --arg direction "$direction" '
      [
        .[]
        | select((.mapped // false) == true)
        | select((.hidden // false) == false)
        | select(.workspace.id == $active_workspace)
        | {
            address,
            x: (.at[0] // 0),
            y: (.at[1] // 0)
          }
      ]
      | sort_by(.y, .x, .address)
      | if length < 2 then
          empty
        else
          . as $windows
          | ($windows | map(.address) | index($active_address)) as $index
          | if $index == null then
              empty
            elif $direction == "previous" then
              $windows[(($index - 1 + length) % length)].address
            else
              $windows[(($index + 1) % length)].address
            end
        end
    ' <<<"$clients"
)"

if [[ -z "$target_address" ]]; then
  exit 0
fi

hyprctl dispatch "hl.dsp.focus({ window = \"address:${target_address}\" })" >/dev/null 2>&1 || true
