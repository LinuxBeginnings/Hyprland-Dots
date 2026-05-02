#!/usr/bin/env bash
# Resize the active window by delta values (dx, dy) using Lua dispatch.

dx="${1:-0}"
dy="${2:-0}"

window_json="$(hyprctl activewindow -j)"
width="$(jq -r '.size[0]' <<<"$window_json")"
height="$(jq -r '.size[1]' <<<"$window_json")"

new_width=$((width + dx))
new_height=$((height + dy))

if ((new_width < 100)); then
  new_width=100
fi
if ((new_height < 100)); then
  new_height=100
fi

hyprctl dispatch "hl.dsp.window.resize({ x = ${new_width}, y = ${new_height} })"
