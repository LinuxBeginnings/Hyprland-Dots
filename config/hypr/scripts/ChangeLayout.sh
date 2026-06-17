#!/usr/bin/env bash
# ==================================================
#  KoolDots (2026)
#  Project URL: https://github.com/LinuxBeginnings
#  License: GNU GPLv3
#  SPDX-License-Identifier: GPL-3.0-or-later
# ==================================================
# Switch Hyprland layouts per active monitor/workspace.
# This avoids global layout mutations and keeps workspace-specific rules intact.

notif="${XDG_CONFIG_HOME:-$HOME/.config}/swaync/images/ja.png"
persist_layout_script="${XDG_CONFIG_HOME:-$HOME/.config}/hypr/scripts/PersistWorkspaceLayout.sh"
layouts=(master dwindle scrolling monocle)
quiet_mode=0

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

persist_current_workspace_layout() {
  local target_layout="$1"

  if [[ ! -x "$persist_layout_script" ]]; then
    return 0
  fi

  "$persist_layout_script" --quiet --layout "$target_layout" >/dev/null 2>&1 || true
}

get_active_workspace_json() {
  hyprctl -j activeworkspace 2>/dev/null || printf '{}'
}

get_layout() {
  local ws_json layout

  ws_json="$(get_active_workspace_json)"
  layout="$(jq -r '.tiledLayout // .tiled_layout // empty' <<<"$ws_json" 2>/dev/null || true)"
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

get_workspace_selector() {
  local ws_json="$1"
  local ws_id ws_name

  ws_id="$(jq -r '.id // empty' <<<"$ws_json" 2>/dev/null || true)"
  ws_name="$(jq -r '.name // empty' <<<"$ws_json" 2>/dev/null || true)"

  if [[ "$ws_id" =~ ^[0-9]+$ ]] && ((ws_id > 0)); then
    printf '%s\n' "$ws_id"
    return 0
  fi

  if [[ -n "$ws_name" && "$ws_name" != "null" ]]; then
    if [[ "$ws_name" == name:* || "$ws_name" == special:* ]]; then
      printf '%s\n' "$ws_name"
    else
      printf 'name:%s\n' "$ws_name"
    fi
    return 0
  fi

  return 1
}

get_workspace_label() {
  local ws_json="$1"
  local ws_name ws_id

  ws_name="$(jq -r '.name // empty' <<<"$ws_json" 2>/dev/null || true)"
  ws_id="$(jq -r '.id // empty' <<<"$ws_json" 2>/dev/null || true)"

  if [[ -n "$ws_name" && "$ws_name" != "null" ]]; then
    printf '%s\n' "$ws_name"
    return
  fi

  if [[ -n "$ws_id" && "$ws_id" != "null" ]]; then
    printf '%s\n' "$ws_id"
    return
  fi

  printf 'current\n'
}

get_monitor_name() {
  local ws_json="$1"
  jq -r '.monitor // empty' <<<"$ws_json" 2>/dev/null || true
}

escape_lua_string() {
  local value="$1"
  value="${value//\\/\\\\}"
  value="${value//\"/\\\"}"
  printf '%s' "$value"
}

is_ok_output() {
  local output="$1"
  local normalized

  normalized="$(printf '%s\n' "$output" | tr -d '\r' | sed '/^[[:space:]]*$/d')"
  [[ -z "$normalized" || "$normalized" == "ok" ]]
}

set_workspace_layout_rule() {
  local target="$1"
  local ws_json workspace_selector monitor_name output
  local ws_escaped monitor_escaped target_escaped

  ws_json="$(get_active_workspace_json)"
  workspace_selector="$(get_workspace_selector "$ws_json" || true)"
  monitor_name="$(get_monitor_name "$ws_json")"

  if [[ -z "$workspace_selector" || -z "$monitor_name" ]]; then
    echo "Unable to resolve active workspace context" >&2
    return 1
  fi

  output="$(hyprctl keyword workspace "${workspace_selector}, monitor:${monitor_name}, layout:${target}" 2>&1 || true)"
  if grep -q "keyword can't work with non-legacy parsers" <<<"$output"; then
    ws_escaped="$(escape_lua_string "$workspace_selector")"
    monitor_escaped="$(escape_lua_string "$monitor_name")"
    target_escaped="$(escape_lua_string "$target")"
    output="$(hyprctl eval "hl.workspace_rule({ workspace = \"${ws_escaped}\", monitor = \"${monitor_escaped}\", layout = \"${target_escaped}\" })" 2>&1 || true)"
  fi

  if ! is_ok_output "$output"; then
    echo "$output" >&2
    return 1
  fi

  hyprctl dispatch workspace "$workspace_selector" >/dev/null 2>&1 || true
}

next_layout() {
  local current="$1"
  local i
  for i in "${!layouts[@]}"; do
    if [[ "${layouts[i]}" == "$current" ]]; then
      echo "${layouts[((i + 1) % ${#layouts[@]})]}"
      return
    fi
  done
  echo "${layouts[0]}"
}

set_layout() {
  local target="$1"
  local ws_json workspace_label monitor_name actual

  ws_json="$(get_active_workspace_json)"
  workspace_label="$(get_workspace_label "$ws_json")"
  monitor_name="$(get_monitor_name "$ws_json")"

  if ! set_workspace_layout_rule "$target"; then
    if [[ "$quiet_mode" -eq 0 ]]; then
      notify-send -e -u critical -i "$notif" " Layout switch failed: $target"
    fi
    return 1
  fi

  sleep 0.03
  actual="$(get_layout)"
  if [[ "$actual" == "$target" ]]; then
    persist_current_workspace_layout "$target"
    if [[ "$quiet_mode" -eq 0 ]]; then
      notify-send -e -u low -i "$notif" " ${actual^} Layout · WS ${workspace_label}${monitor_name:+ @ ${monitor_name}}"
    fi
  else
    if [[ "$quiet_mode" -eq 0 ]]; then
      notify-send -e -u critical -i "$notif" " Layout switch failed: still ${actual}"
    fi
    return 1
  fi
}

if [[ "${1:-}" == "--quiet" || "${1:-}" == "--no-notify" ]]; then
  quiet_mode=1
  shift
fi

current="$(get_layout)"
arg="${1:-toggle}"

case "$arg" in
init)
  # No startup keybind rebinding required anymore.
  exit 0
  ;;
current | status | get)
  printf '%s\n' "$current"
  ;;
toggle | next)
  set_layout "$(next_layout "$current")"
  ;;
master | dwindle | scrolling | monocle)
  set_layout "$arg"
  ;;
*)
  echo "Usage: $(basename "$0") [--quiet|--no-notify] [toggle|next|init|current|master|dwindle|scrolling|monocle]" >&2
  exit 1
  ;;
esac
