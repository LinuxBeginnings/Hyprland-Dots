#!/usr/bin/env bash
set -euo pipefail

if ! command -v hyprctl >/dev/null 2>&1; then
  exit 1
fi

if ! command -v jq >/dev/null 2>&1; then
  hyprctl dispatch fullscreen 1 >/dev/null 2>&1 || true
  exit 0
fi

workspace_json="$(hyprctl -j activeworkspace 2>/dev/null || true)"
layout_name="$(jq -r '.tiled_layout // empty' <<<"$workspace_json")"

if [[ "$layout_name" != "scrolling" ]]; then
  hyprctl dispatch fullscreen 1 >/dev/null 2>&1 || true
  exit 0
fi

window_json="$(hyprctl -j activewindow 2>/dev/null || true)"
if [[ -z "$window_json" || "$window_json" == "null" ]]; then
  exit 0
fi

window_address="$(jq -r '.address // empty' <<<"$window_json")"
column_width="$(jq -r '.layout.column // empty' <<<"$window_json")"

if [[ -z "$window_address" || -z "$column_width" || "$column_width" == "null" ]]; then
  hyprctl dispatch fullscreen 1 >/dev/null 2>&1 || true
  exit 0
fi

runtime_dir="${XDG_RUNTIME_DIR:-/tmp}"
state_dir="${runtime_dir}/hypr"
state_file="${state_dir}/scrolling-maximize-state.json"
mkdir -p "$state_dir"

if [[ ! -s "$state_file" ]]; then
  printf '{}\n' > "$state_file"
elif ! jq -e . "$state_file" >/dev/null 2>&1; then
  printf '{}\n' > "$state_file"
fi

saved_width="$(jq -r --arg key "$window_address" '.[$key] // empty' "$state_file" 2>/dev/null || true)"
tmp_file="$(mktemp "${state_file}.XXXXXX")"
cleanup() {
  rm -f "$tmp_file"
}
trap cleanup EXIT

if [[ -n "$saved_width" && "$saved_width" != "null" ]]; then
  hyprctl dispatch layoutmsg "colresize exact ${saved_width}" >/dev/null 2>&1 || true
  jq --arg key "$window_address" 'del(.[$key])' "$state_file" > "$tmp_file"
  mv "$tmp_file" "$state_file"
  trap - EXIT
  exit 0
fi

jq --arg key "$window_address" --argjson value "$column_width" '. + {($key): $value}' "$state_file" > "$tmp_file"
mv "$tmp_file" "$state_file"
trap - EXIT

hyprctl dispatch layoutmsg "colresize 1.0" >/dev/null 2>&1 || true
