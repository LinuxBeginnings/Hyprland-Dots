#!/usr/bin/env bash
set -euo pipefail

if ! command -v hyprctl >/dev/null 2>&1; then
  exit 0
fi

if ! command -v jq >/dev/null 2>&1; then
  exit 0
fi

workspace_json="$(hyprctl -j activeworkspace 2>/dev/null || true)"
layout_name="$(jq -r '.tiledLayout // .tiled_layout // empty' <<<"$workspace_json")"

if [[ "$layout_name" != "scrolling" ]]; then
  exit 0
fi

window_json="$(hyprctl -j activewindow 2>/dev/null || true)"
column_width="$(jq -r '.layout.column.width // .layout.column // empty' <<<"$window_json")"
window_monitor="$(jq -r '.monitor // empty' <<<"$window_json")"
window_width="$(jq -r '.size[0] // empty' <<<"$window_json")"

if [[ -n "$column_width" && "$column_width" != "null" ]]; then
  if ! awk -v v="$column_width" 'BEGIN { exit !(v > 0 && v <= 1.0) }'; then
    column_width=""
  fi
fi

if [[ -z "$column_width" || "$column_width" == "null" ]]; then
  monitors_json="$(hyprctl -j monitors 2>/dev/null || true)"
  monitor_width="$(jq -r --arg id "$window_monitor" '.[] | select((.id | tostring) == $id) | .width' <<<"$monitors_json" 2>/dev/null | head -n1)"
  if [[ -n "$window_width" && -n "$monitor_width" && "$window_width" != "null" && "$monitor_width" != "null" ]]; then
    column_width="$(awk -v w="$window_width" -v mw="$monitor_width" 'BEGIN { if (w > 0 && mw > 0) printf "%.6f", (w / mw); }')"
  fi
fi

if [[ -z "$column_width" || "$column_width" == "null" ]]; then
  exit 0
fi

presets=(0.25 0.33 0.5 0.66 0.75 1.0)
closest_idx=0
best_diff=""

for idx in "${!presets[@]}"; do
  preset="${presets[$idx]}"
  diff="$(awk -v a="$preset" -v b="$column_width" 'BEGIN { d = a - b; if (d < 0) d = -d; printf "%.12f", d }')"
  if [[ -z "$best_diff" ]] || awk -v d="$diff" -v b="$best_diff" 'BEGIN { exit !(d < b) }'; then
    best_diff="$diff"
    closest_idx="$idx"
  fi
done

next_idx=$(( (closest_idx + 1) % ${#presets[@]} ))
hyprctl dispatch layoutmsg "colresize ${presets[$next_idx]}" >/dev/null 2>&1 || true
