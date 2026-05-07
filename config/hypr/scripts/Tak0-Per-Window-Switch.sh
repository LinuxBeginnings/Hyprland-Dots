#!/usr/bin/env bash
# ==================================================
#  KoolDots (2026)
#  Project URL: https://github.com/LinuxBeginnings
#  License: GNU GPLv3
#  SPDX-License-Identifier: GPL-3.0-or-later
# ==================================================
##################################################################
#                                                                #
#                                                                #
#                  TAK_0'S Per-Window-Switch                     #
#                                                                #
#                                                                #
#                                                                #
#  Just a little script that I made to switch keyboard layouts   #
#       per-window instead of global switching for the more      #
#                 smooth and comfortable workflow.               #
#                                                                #
##################################################################

MAP_FILE="$HOME/.cache/kb_layout_per_window"
ICON="$HOME/.config/swaync/images/ja.png"
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

# Ensure map file exists
touch "$MAP_FILE"

# Function to get layouts from config files
get_layouts() {
    local layouts=""
    if [[ "$hypr_config_mode" == "lua" ]]; then
        local lua_user="$hypr_dir/UserConfigs/user_settings.lua"
        local lua_sys="$hypr_dir/lua/settings.lua"
        if [[ -f "$lua_user" ]] && grep -q 'kb_layout' "$lua_user" 2>/dev/null; then
            layouts=$(grep 'kb_layout' "$lua_user" | sed -n 's/.*kb_layout\s*=\s*"\([^"]*\)".*/\1/p' | head -n1)
        elif [[ -f "$lua_sys" ]] && grep -q 'kb_layout' "$lua_sys" 2>/dev/null; then
            layouts=$(grep 'kb_layout' "$lua_sys" | sed -n 's/.*kb_layout\s*=\s*"\([^"]*\)".*/\1/p' | head -n1)
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
    echo "$layouts" | tr ',' ' '
}

raw_layouts=$(get_layouts)
if [[ -z "$raw_layouts" ]]; then
    echo "Error: cannot find kb_layout in configuration files." >&2
    exit 1
fi

kb_layouts=($raw_layouts)
count=${#kb_layouts[@]}

# Get current active window ID
get_win() {
  hyprctl activewindow -j | jq -r '.address // .id'
}

# Get available keyboards
get_keyboards() {
  hyprctl devices -j | jq -r '.keyboards[].name'
}

# Save window-specific layout
save_map() {
  local W=$1 L=$2
  grep -v "^${W}:" "$MAP_FILE" > "$MAP_FILE.tmp" 2>/dev/null
  echo "${W}:${L}" >> "$MAP_FILE.tmp"
  mv "$MAP_FILE.tmp" "$MAP_FILE"
}

# Load layout for window (fallback to default)
load_map() {
  local W=$1
  local E
  E=$(grep "^${W}:" "$MAP_FILE" 2>/dev/null)
  [[ -n "$E" ]] && echo "${E#*:}" || echo "${kb_layouts[0]}"
}

# Switch layout for all keyboards to layout index
do_switch() {
  local IDX=$1
  for kb in $(get_keyboards); do
    hyprctl switchxkblayout "$kb" "$IDX" >/dev/null 2>&1
  done
}

# Toggle layout for current window only
cmd_toggle() {
  local W=$(get_win)
  [[ -z "$W" || "$W" == "null" ]] && return
  local CUR=$(load_map "$W")
  local i=0
  local NEXT
  for idx in "${!kb_layouts[@]}"; do
    if [[ "${kb_layouts[idx]}" == "$CUR" ]]; then
      i=$idx
      break
    fi
  done
  NEXT=$(( (i+1) % count ))
  do_switch "$NEXT"
  save_map "$W" "${kb_layouts[NEXT]}"
  notify-send -u low -i "$ICON" "kb_layout: ${kb_layouts[NEXT]}"
}

# Restore layout on focus
cmd_restore() {
  local W=$(get_win)
  [[ -z "$W" || "$W" == "null" ]] && return
  local LAY=$(load_map "$W")
  for idx in "${!kb_layouts[@]}"; do
    if [[ "${kb_layouts[idx]}" == "$LAY" ]]; then
      do_switch "$idx"
      break
    fi
  done
}

# Listen to focus events and restore window-specific layouts
subscribe() {
  local SOCKET2="$XDG_RUNTIME_DIR/hypr/$HYPRLAND_INSTANCE_SIGNATURE/.socket2.sock"
  if [[ ! -S "$SOCKET2" ]]; then
    # Fallback if HYPRLAND_INSTANCE_SIGNATURE is not set correctly in this subshell
    local sig=$(hyprctl instances -j | jq -r '.[0].instance' 2>/dev/null)
    SOCKET2="$XDG_RUNTIME_DIR/hypr/$sig/.socket2.sock"
  fi

  [[ -S "$SOCKET2" ]] || {
    echo "Error: Hyprland socket not found." >&2
    exit 1
  }

  socat -u UNIX-CONNECT:"$SOCKET2" - | while read -r line; do
    if [[ "$line" =~ ^activewindow ]]; then
        cmd_restore
    fi
  done
}

# CLI
case "$1" in
  --listener)
    subscribe
    ;;
  toggle|"")
    # Ensure only one listener
    if ! pgrep -f "$SCRIPT_NAME.*--listener" >/dev/null; then
      "$SCRIPT_PATH" --listener &
    fi
    cmd_toggle 
    ;;
  *) 
    echo "Usage: $SCRIPT_NAME [toggle]" >&2; exit 1 
    ;;
esac
