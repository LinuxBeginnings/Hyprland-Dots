#!/usr/bin/env bash
set -euo pipefail

if ! command -v hyprctl >/dev/null 2>&1; then
  exit 1
fi

if ! command -v jq >/dev/null 2>&1; then
  hyprctl dispatch fullscreen 1 >/dev/null 2>&1 || true
  exit 0
fi

run_layoutmsg() {
  local msg="$1"
  local output=""
  output="$(hyprctl dispatch layoutmsg "$msg" 2>&1 || true)"
  [[ "$(printf '%s' "$output" | tr -d '\r\n')" == "ok" ]]
}

workspace_json="$(hyprctl -j activeworkspace 2>/dev/null || true)"
layout_name="$(jq -r '.tiledLayout // .tiled_layout // empty' <<<"$workspace_json")"

if [[ "$layout_name" != "scrolling" ]]; then
  hyprctl dispatch fullscreen 1 >/dev/null 2>&1 || true
  exit 0
fi

window_json="$(hyprctl -j activewindow 2>/dev/null || true)"
if [[ -z "$window_json" || "$window_json" == "null" ]]; then
  exit 0
fi

window_address="$(jq -r '.address // empty' <<<"$window_json")"
window_width="$(jq -r '.size[0] // empty' <<<"$window_json")"
column_width="$(jq -r '
  .layout.column as $col
  | if ($col | type) == "number" then $col
    elif ($col | type) == "object" then ($col.width // empty)
    elif ($col | type) == "string" then ($col | tonumber? // empty)
    else empty
    end
' <<<"$window_json")"
if [[ -n "$column_width" && "$column_width" != "null" ]]; then
  if ! awk -v v="$column_width" 'BEGIN { exit !(v > 0 && v <= 1.0) }'; then
    column_width=""
  fi
fi

if [[ -z "$window_address" || -z "$window_width" || "$window_width" == "null" ]]; then
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

saved_width="$(jq -r --arg key "$window_address" '
  .[$key] as $saved
  | if ($saved | type) == "number" then $saved
    elif ($saved | type) == "object" then ($saved.width // empty)
    elif ($saved | type) == "string" then ($saved | tonumber? // empty)
    else empty
    end
' "$state_file" 2>/dev/null || true)"
tmp_file="$(mktemp "${state_file}.XXXXXX")"
cleanup() {
  rm -f "$tmp_file"
}
trap cleanup EXIT

if [[ -n "$saved_width" && "$saved_width" != "null" ]]; then
  restored=0
  if run_layoutmsg "colresize ${saved_width}"; then
    restored=1
  elif run_layoutmsg "colresize exact ${saved_width}"; then
    restored=1
  fi
  if [[ "$restored" -eq 1 ]]; then
    jq --arg key "$window_address" 'del(.[$key])' "$state_file" > "$tmp_file"
    mv "$tmp_file" "$state_file"
  fi
  trap - EXIT
  exit 0
fi
if [[ -z "$column_width" || "$column_width" == "null" ]]; then
  if run_layoutmsg "colresize 1.0"; then
    max_width=""
    for _ in 1 2 3 4 5 6; do
      candidate_width="$(hyprctl -j activewindow 2>/dev/null | jq -r '.size[0] // empty')"
      if [[ -n "$candidate_width" && "$candidate_width" != "null" ]] && awk -v v="$candidate_width" 'BEGIN { exit !(v > 0) }'; then
        if [[ -z "$max_width" ]] || awk -v c="$candidate_width" -v m="$max_width" 'BEGIN { exit !(c > m) }'; then
          max_width="$candidate_width"
        fi
      fi
      sleep 0.05
    done
    if [[ -n "$max_width" ]]; then
      column_width="$(awk -v w="$window_width" -v mw="$max_width" 'BEGIN { if (w > 0 && mw > 0) printf "%.6f", (w / mw); }')"
    fi
  fi
  if [[ -z "$column_width" || "$column_width" == "null" ]]; then
    trap - EXIT
    exit 0
  fi
  jq --arg key "$window_address" --argjson value "$column_width" '. + {($key): $value}' "$state_file" > "$tmp_file"
  mv "$tmp_file" "$state_file"
  trap - EXIT
  exit 0
fi

jq --arg key "$window_address" --argjson value "$column_width" '. + {($key): $value}' "$state_file" > "$tmp_file"
mv "$tmp_file" "$state_file"
trap - EXIT

run_layoutmsg "colresize 1.0" >/dev/null 2>&1 || true
