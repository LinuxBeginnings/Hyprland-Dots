#!/usr/bin/env bash
# ==================================================
#  KoolDots (2026)
#  Project URL: https://github.com/LinuxBeginnings
#  License: GNU GPLv3
#  SPDX-License-Identifier: GPL-3.0-or-later
# ==================================================
##################################################################
#                                                                #
#                  TAK_0'S Per-Window-Switch                     #
#                                                                #
#  Just a little script that I made to switch keyboard layouts   #
#       per-window instead of global switching for the more      #
#                 smooth and comfortable workflow.               #
#                                                                #
##################################################################

set -uo pipefail

MAP_FILE="${XDG_CACHE_HOME:-$HOME/.cache}/kb_layout_per_window"
notif="${XDG_CONFIG_HOME:-$HOME/.config}/swaync/images"
icons_dir="${XDG_CONFIG_HOME:-$HOME/.config}/swaync/icons"
SCRIPT_NAME="$(basename "$0")"
SCRIPT_PATH="$(readlink -f "$0")"

# Detect active Hyprland config mode
config_home="${XDG_CONFIG_HOME:-$HOME/.config}"
hypr_dir="$config_home/hypr"
lua_entry="$hypr_dir/hyprland.lua"
legacy_lua_entry="$config_home/hyprland.lua"

if [[ -f "$lua_entry" || -f "$legacy_lua_entry" ]]; then
    hypr_config_mode="lua"
else
    hypr_config_mode="conf"
fi

# Pick notification icon
if [[ -f "$icons_dir/keyboard.png" ]]; then
    ICON="$icons_dir/keyboard.png"
elif [[ -f "$notif/ja.png" ]]; then
    ICON="$notif/ja.png"
else
    ICON="$notif/note.png"
fi

# Ensure cache directory and map file exist
mkdir -p "$(dirname "$MAP_FILE")"
touch "$MAP_FILE"

# Function to get layouts (queries live Hyprland option first, then config files)
get_layouts() {
    local layouts=""

    # 1. Primary: Live option from active Hyprland session (fast, authoritative in both Lua & conf modes)
    layouts=$(hyprctl -j getoption input:kb_layout 2>/dev/null | jq -r '.str // empty' || true)

    # 2. Secondary: Query keyboards directly from devices JSON
    if [[ -z "$layouts" || "$layouts" == "null" ]]; then
        layouts=$(hyprctl -j devices 2>/dev/null | jq -r '[.keyboards[].layout | select(. != null and . != "")] | first // empty' || true)
    fi

    # 3. Fallback: Parse configuration files
    if [[ -z "$layouts" || "$layouts" == "null" ]]; then
        if [[ "$hypr_config_mode" == "lua" ]]; then
            local lua_user="$hypr_dir/UserConfigs/user_settings.lua"
            local lua_sys="$hypr_dir/configs/system_settings.lua"
            local lua_legacy_sys="$hypr_dir/UserConfigs/system_settings.lua"
            local lua_pristine_sys="$hypr_dir/lua/settings.lua"
            if [[ -f "$lua_user" ]] && grep -q 'kb_layout' "$lua_user" 2>/dev/null; then
                layouts=$(grep 'kb_layout' "$lua_user" | sed -n "s/.*kb_layout[[:space:]]*=[[:space:]]*[\"']\([^\"']*\)[\"'].*/\1/p" | head -n1)
            elif [[ -f "$lua_sys" ]] && grep -q 'kb_layout' "$lua_sys" 2>/dev/null; then
                layouts=$(grep 'kb_layout' "$lua_sys" | sed -n "s/.*kb_layout[[:space:]]*=[[:space:]]*[\"']\([^\"']*\)[\"'].*/\1/p" | head -n1)
            elif [[ -f "$lua_legacy_sys" ]] && grep -q 'kb_layout' "$lua_legacy_sys" 2>/dev/null; then
                layouts=$(grep 'kb_layout' "$lua_legacy_sys" | sed -n "s/.*kb_layout[[:space:]]*=[[:space:]]*[\"']\([^\"']*\)[\"'].*/\1/p" | head -n1)
            elif [[ -f "$lua_pristine_sys" ]] && grep -q 'kb_layout' "$lua_pristine_sys" 2>/dev/null; then
                layouts=$(grep 'kb_layout' "$lua_pristine_sys" | sed -n "s/.*kb_layout[[:space:]]*=[[:space:]]*[\"']\([^\"']*\)[\"'].*/\1/p" | head -n1)
            fi
        else
            local conf_user="$hypr_dir/UserConfigs/UserSettings.conf"
            local conf_sys="$hypr_dir/configs/SystemSettings.conf"
            if [[ -f "$conf_user" ]] && grep -q 'kb_layout' "$conf_user" 2>/dev/null; then
                layouts=$(grep 'kb_layout' "$conf_user" | cut -d '=' -f2 | tr -d '[:space:]' | head -n1)
            elif [[ -f "$conf_sys" ]] && grep -q 'kb_layout' "$conf_sys" 2>/dev/null; then
                layouts=$(grep 'kb_layout' "$conf_sys" | cut -d '=' -f2 | tr -d '[:space:]' | head -n1)
            fi
        fi
    fi

    echo "${layouts:-us}" | tr ',' ' '
}

raw_layouts=$(get_layouts)
if [[ -z "$raw_layouts" ]]; then
    echo "Error: cannot find kb_layout in configuration files or active session." >&2
    exit 1
fi

kb_layouts=($raw_layouts)
count=${#kb_layouts[@]}

# Get current active window ID/address
get_win() {
  hyprctl activewindow -j 2>/dev/null | jq -r '.address // .id // empty'
}

# Get available keyboard names
get_keyboards() {
  hyprctl devices -j 2>/dev/null | jq -r '.keyboards[].name // empty'
}

# Save window-specific layout
save_map() {
  local W=$1 L=$2
  grep -v "^${W}:" "$MAP_FILE" > "$MAP_FILE.tmp" 2>/dev/null || true
  echo "${W}:${L}" >> "$MAP_FILE.tmp"
  mv "$MAP_FILE.tmp" "$MAP_FILE"
}

# Load layout for window (fallback to default layout)
load_map() {
  local W=$1
  local E
  E=$(grep "^${W}:" "$MAP_FILE" 2>/dev/null || true)
  [[ -n "$E" ]] && echo "${E#*:}" || echo "${kb_layouts[0]}"
}

# Switch layout for all keyboards to layout index
do_switch() {
  local IDX=$1
  for kb in $(get_keyboards); do
    hyprctl switchxkblayout "$kb" "$IDX" >/dev/null 2>&1 || true
  done
}

# Toggle layout for current window only
cmd_toggle() {
  local W
  W=$(get_win)
  [[ -z "$W" || "$W" == "null" ]] && return

  local CUR
  CUR=$(load_map "$W")
  local i=0
  local NEXT

  for idx in "${!kb_layouts[@]}"; do
    if [[ "${kb_layouts[idx]}" == "$CUR" ]]; then
      i=$idx
      break
    fi
  done

  NEXT=$(( (i + 1) % count ))
  do_switch "$NEXT"
  save_map "$W" "${kb_layouts[NEXT]}"

  if command -v notify-send >/dev/null 2>&1 && [[ -n "${WAYLAND_DISPLAY:-}${DISPLAY:-}" ]]; then
    notify-send -e \
      -h string:x-canonical-private-synchronous:kb_layout_notif \
      -h boolean:SWAYNC_BYPASS_DND:true \
      -u low \
      -i "$ICON" \
      " Keyboard Layout (Per-Window)" " ${kb_layouts[NEXT]}" 2>/dev/null || true
  fi
}

# Restore layout on focus
cmd_restore() {
  local W
  W=$(get_win)
  [[ -z "$W" || "$W" == "null" ]] && return

  local LAY
  LAY=$(load_map "$W")
  for idx in "${!kb_layouts[@]}"; do
    if [[ "${kb_layouts[idx]}" == "$LAY" ]]; then
      do_switch "$idx"
      break
    fi
  done
}

# Listen to focus events and restore window-specific layouts
subscribe() {
  local runtime_dir="${XDG_RUNTIME_DIR:-/run/user/$(id -u)}"
  local SOCKET2=""

  if [[ -n "${HYPRLAND_INSTANCE_SIGNATURE:-}" ]]; then
    SOCKET2="$runtime_dir/hypr/$HYPRLAND_INSTANCE_SIGNATURE/.socket2.sock"
  fi

  if [[ ! -S "$SOCKET2" ]]; then
    local sig
    sig=$(hyprctl instances -j 2>/dev/null | jq -r '.[0].instance // empty')
    [[ -n "$sig" ]] && SOCKET2="$runtime_dir/hypr/$sig/.socket2.sock"
  fi

  if [[ ! -S "$SOCKET2" ]]; then
    echo "Error: Hyprland socket not found." >&2
    exit 1
  fi

  if ! command -v socat >/dev/null 2>&1; then
    echo "Error: socat is required for socket listening." >&2
    exit 1
  fi

  socat -u UNIX-CONNECT:"$SOCKET2" - 2>/dev/null | while read -r line; do
    if [[ "$line" =~ ^activewindow ]]; then
      cmd_restore
    fi
  done
}

# CLI
case "${1:-toggle}" in
  --listener)
    subscribe
    ;;
  status)
    W=$(get_win)
    load_map "$W"
    ;;
  toggle|"")
    # Ensure only one listener is active
    if ! pgrep -f "$SCRIPT_NAME.*--listener" >/dev/null 2>&1; then
      "$SCRIPT_PATH" --listener &
    fi
    cmd_toggle
    ;;
  *)
    echo "Usage: $SCRIPT_NAME [toggle|status]" >&2
    exit 1
    ;;
esac
