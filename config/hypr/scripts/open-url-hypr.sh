#!/usr/bin/env bash
set -euo pipefail

url="${1:?URL required}"

# Open in an existing Firefox tab when possible.
if pgrep -x firefox >/dev/null 2>&1; then
  firefox --new-tab "$url" >/dev/null 2>&1 &
else
  xdg-open "$url" >/dev/null 2>&1 &
fi

if ! command -v hyprctl >/dev/null 2>&1 || ! command -v jq >/dev/null 2>&1; then
  exit 0
fi

browser_re='^(org\.mozilla\.firefox|firefox|Google-chrome|chromium|Brave-browser|zen|Microsoft-edge)$'

for _ in $(seq 1 50); do
  read -r addr ws_id <<< "$(hyprctl clients -j | jq -r --arg re "$browser_re" '
    [.[] | select(.class | test($re; "i"))][0] // empty
    | "\(.address) \(.workspace.id)"
  ')"

  if [ -n "${addr:-}" ] && [ "$addr" != "null" ]; then
    hyprctl dispatch workspace "$ws_id" >/dev/null
    hyprctl dispatch focuswindow "address:$addr" >/dev/null
    hyprctl dispatch bringactivetotop >/dev/null 2>&1 || true
    exit 0
  fi

  sleep 0.1
done
