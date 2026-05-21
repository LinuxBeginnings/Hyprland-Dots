#!/usr/bin/env bash
# ==================================================
#  KoolDots (2026)
#  Project URL: https://github.com/LinuxBeginnings
#  License: GNU GPLv3
#  SPDX-License-Identifier: GPL-3.0-or-later
# ==================================================
#
# Made and brought to by Kiran George
# /* -- ✨ https://github.com/SherLock707 ✨ -- */  ##
# Dropdown Terminal
# Usage: ./Dropdown.sh [-d] <terminal_command>
# Example: ./Dropdown.sh foot
#          ./Dropdown.sh -d foot (with debug output)
#          ./Dropdown.sh "kitty -e zsh"
#          ./Dropdown.sh "alacritty --working-directory /home/user"

DEBUG=false
SPECIAL_WS="special:scratchpad"
SPECIAL_NAME="${SPECIAL_WS#special:}"
ADDR_FILE="/tmp/dropdown_terminal_addr"
STATE_FILE="/tmp/dropdown_terminal_state"
LOCK_FILE="/tmp/dropdown_terminal_lock"
LAST_TOGGLE_FILE="/tmp/dropdown_terminal_last_toggle"
MIN_TOGGLE_INTERVAL_MS=250
DROPDOWN_KITTY_CLASS="kitty-dropterm"
CONFIG_HOME="${XDG_CONFIG_HOME:-$HOME/.config}"
HYPR_DIR="$CONFIG_HOME/hypr"
LUA_ENTRY="$HYPR_DIR/hyprland.lua"
LEGACY_LUA_ENTRY="$CONFIG_HOME/hyprland.lua"

if [[ -f "$LUA_ENTRY" || -f "$LEGACY_LUA_ENTRY" ]]; then
  HYPR_CONFIG_MODE="lua"
else
  HYPR_CONFIG_MODE="conf"
fi
lua_escape() {
  local value="$1"
  value=${value//\\/\\\\}
  value=${value//\"/\\\"}
  value=${value//$'\n'/\\n}
  printf '%s' "$value"
}


hypr_dispatch() {
  local dispatcher="$1"
  shift
  local payload="$*"
  if [[ "$HYPR_CONFIG_MODE" == "lua" ]]; then
    local command="$dispatcher"
    if [ -n "$payload" ]; then
      command="$dispatcher $payload"
    fi
    local escaped
    escaped="$(lua_escape "$command")"
    hyprctl dispatch "hl.dsp.exec_raw(\"$escaped\")"
  else
    hyprctl dispatch "$dispatcher" "$payload"
  fi
}

hypr_exec_cmd() {
  local command="$*"
  if [[ "$HYPR_CONFIG_MODE" == "lua" ]]; then
    local escaped
    escaped="$(lua_escape "$command")"
    hyprctl dispatch "hl.dsp.exec_cmd(\"$escaped\")"
  else
    hyprctl dispatch exec "$command"
  fi
}

lua_workspace_expr() {
  local workspace="$1"
  if [[ "$workspace" =~ ^-?[0-9]+$ ]]; then
    printf '%s' "$workspace"
  else
    local escaped
    escaped="$(lua_escape "$workspace")"
    printf '"%s"' "$escaped"
  fi
}

focus_window() {
  local addr="$1"
  if [[ "$HYPR_CONFIG_MODE" == "lua" ]]; then
    local selector escaped
    selector="address:$addr"
    escaped="$(lua_escape "$selector")"
    hyprctl dispatch "hl.dsp.focus({ window = \"$escaped\" })"
  else
    hypr_dispatch focuswindow "address:$addr"
  fi
}

set_window_floating() {
  local addr="$1"
  if [[ "$HYPR_CONFIG_MODE" == "lua" ]]; then
    hyprctl dispatch "hl.dsp.window.float({ window = 'address:$addr', action = 'on' })"
  else
    hypr_dispatch setfloating "address:$addr"
  fi
}

resize_window_exact() {
  local addr="$1"
  local width="$2"
  local height="$3"
  if [[ "$HYPR_CONFIG_MODE" == "lua" ]]; then
    hyprctl dispatch "hl.dsp.window.resize({ window = 'address:$addr', x = $width, y = $height, exact = true })"
  else
    hypr_dispatch resizewindowpixel "exact $width $height,address:$addr"
  fi
}

move_window_exact() {
  local addr="$1"
  local x="$2"
  local y="$3"
  if [[ "$HYPR_CONFIG_MODE" == "lua" ]]; then
    hyprctl dispatch "hl.dsp.window.move({ window = 'address:$addr', x = $x, y = $y, exact = true })"
  else
    hypr_dispatch movewindowpixel "exact $x $y,address:$addr"
  fi
}

# Dropdown size and position configuration (percentages)
WIDTH_PERCENT=65  # Width as percentage of screen width
HEIGHT_PERCENT=65 # Height as percentage of screen height
Y_PERCENT=10      # Y position as percentage from top (X is auto-centered)

# Animation settings
ANIMATION_DURATION=220 # total animation time in milliseconds
SLIDE_STEPS=12
SLIDE_DELAY=$((ANIMATION_DURATION / SLIDE_STEPS))
if [ "$SLIDE_DELAY" -lt 8 ]; then
  SLIDE_DELAY=8
fi

# Parse arguments
STARTUP_MODE=false
while [ $# -gt 0 ]; do
  case "$1" in
  -d | --debug)
    DEBUG=true
    shift
    ;;
  --startup | --init)
    STARTUP_MODE=true
    shift
    ;;
  -h | --help)
    echo "Usage: $0 [-d|--debug] [--startup|--init] <terminal_command>"
    echo "Examples:"
    echo "  $0 kitty"
    echo "  $0 --startup kitty"
    echo "  $0 -d \"kitty -e zsh\""
    exit 0
    ;;
  *)
    break
    ;;
  esac
done

TERMINAL_CMD="$*"
if [[ "$TERMINAL_CMD" == kitty* ]] && [[ "$TERMINAL_CMD" != *"--class"* ]] && [[ "$TERMINAL_CMD" != *"--name"* ]] && [[ "$TERMINAL_CMD" != *"--app-id"* ]]; then
  TERMINAL_CMD="$TERMINAL_CMD --class $DROPDOWN_KITTY_CLASS --app-id $DROPDOWN_KITTY_CLASS"
fi

# Ensure only one instance runs at a time (prevents overlapping animations)
exec 9>"$LOCK_FILE"
flock -n 9 || exit 0

# Debounce rapid toggles
if [ "$STARTUP_MODE" != true ]; then
  now_ms=""
  if date +%s%3N >/dev/null 2>&1; then
    now_ms=$(date +%s%3N)
  else
    now_ms=$(( $(date +%s) * 1000 ))
  fi
  if [ -f "$LAST_TOGGLE_FILE" ]; then
    last_ms=$(cat "$LAST_TOGGLE_FILE" 2>/dev/null || echo 0)
    if [ -n "$last_ms" ] && [ "$last_ms" -ge 0 ] 2>/dev/null; then
      delta_ms=$((now_ms - last_ms))
      if [ "$delta_ms" -lt "$MIN_TOGGLE_INTERVAL_MS" ] 2>/dev/null; then
        if [ "$DEBUG" = true ]; then
          echo "Toggle debounced (${delta_ms}ms < ${MIN_TOGGLE_INTERVAL_MS}ms)" >&2
        fi
        exit 0
      fi
    fi
  fi
  echo "$now_ms" >"$LAST_TOGGLE_FILE"
fi

# Debug echo function
debug_echo() {
  if [ "$DEBUG" = true ]; then
    echo "$@" >&2
  fi
}

# Resolve terminal address, recovering by class if needed
resolve_terminal_address() {
  local addr
  addr=$(get_terminal_address)
  if [ -n "$addr" ] && window_exists "$addr"; then
    echo "$addr"
    return 0
  fi

  local recovered
  recovered=$(find_terminal_by_class)
  if [ -n "$recovered" ] && [ "$recovered" != "null" ]; then
    local mon_name
    mon_name=$(get_monitor_info | awk '{print $6}')
    echo "$recovered $mon_name" >"$ADDR_FILE"
    echo "$recovered"
    return 0
  fi

  rm -f "$ADDR_FILE"
  return 1
}

# Validate input
if [ -z "$TERMINAL_CMD" ]; then
  echo "Missing terminal command. Usage: $0 [-d|--debug] [--startup|--init] <terminal_command>"
  echo "Examples:"
  echo "  $0 kitty"
  echo "  $0 --startup kitty"
  echo "  $0 -d kitty (with debug output)"
  echo "  $0 'kitty -e zsh'"
  echo "  $0 'alacritty --working-directory /home/user'"
  echo ""
  echo "Edit the script to modify size and position:"
  echo "  WIDTH_PERCENT  - Width as percentage of screen (default: 50)"
  echo "  HEIGHT_PERCENT - Height as percentage of screen (default: 50)"
  echo "  Y_PERCENT      - Y position from top as percentage (default: 5)"
  echo "  Note: X position is automatically centered"
  exit 1
fi

# Function to get window geometry
get_window_geometry() {
  local addr="$1"
  hyprctl clients -j | jq -r --arg ADDR "$addr" '.[] | select(.address == $ADDR) | "\(.at[0]) \(.at[1]) \(.size[0]) \(.size[1])"'
}

# Function to check if window is currently hidden off-screen
window_is_hidden() {
  local addr="$1"
  local geometry y height monitor_id monitor_y
  geometry=$(hyprctl clients -j 2>/dev/null | jq -r --arg ADDR "$addr" '.[] | select(.address == $ADDR) | "\(.at[1]) \(.size[1]) \(.monitor)"' 2>/dev/null)
  y=$(echo "$geometry" | awk '{print $1}')
  height=$(echo "$geometry" | awk '{print $2}')
  monitor_id=$(echo "$geometry" | awk '{print $3}')

  if ! [[ "$y" =~ ^-?[0-9]+$ && "$height" =~ ^[0-9]+$ ]]; then
    return 1
  fi

  if [[ "$monitor_id" =~ ^-?[0-9]+$ ]]; then
    monitor_y=$(hyprctl monitors -j 2>/dev/null | jq -r --argjson MID "$monitor_id" '.[] | select(.id == $MID) | .y' 2>/dev/null | head -1)
  fi
  if ! [[ "$monitor_y" =~ ^-?[0-9]+$ ]]; then
    monitor_y=0
  fi

  if [ $((y + height)) -le "$monitor_y" ]; then
    return 0
  fi
  return 1
}

get_window_monitor_top() {
  local addr="$1"
  local monitor_id monitor_y
  monitor_id=$(hyprctl clients -j 2>/dev/null | jq -r --arg ADDR "$addr" '.[] | select(.address == $ADDR) | .monitor' 2>/dev/null | head -1)
  if [[ "$monitor_id" =~ ^-?[0-9]+$ ]]; then
    monitor_y=$(hyprctl monitors -j 2>/dev/null | jq -r --argjson MID "$monitor_id" '.[] | select(.id == $MID) | .y' 2>/dev/null | head -1)
    if [[ "$monitor_y" =~ ^-?[0-9]+$ ]]; then
      echo "$monitor_y"
      return 0
    fi
  fi
  echo 0
}

get_hidden_y_for_window() {
  local addr="$1"
  local height="$2"
  local monitor_top
  if ! [[ "$height" =~ ^[0-9]+$ ]]; then
    height=702
  fi
  monitor_top=$(get_window_monitor_top "$addr")
  if ! [[ "$monitor_top" =~ ^-?[0-9]+$ ]]; then
    monitor_top=0
  fi
  echo $((monitor_top - height - 80))
}

# State helpers
get_hidden_state() {
  if [ -f "$STATE_FILE" ]; then
    cat "$STATE_FILE" 2>/dev/null
  fi
}

set_hidden_state() {
  echo "$1" >"$STATE_FILE"
}

sleep_ms() {
  local ms="$1"
  if command -v awk >/dev/null 2>&1; then
    sleep "$(awk -v value="$ms" 'BEGIN { printf "%.3f", value / 1000 }')"
  else
    sleep 0.01
  fi
}

# Function to animate window slide down (show)
animate_slide_down() {
  local addr="$1"
  local target_x="$2"
  local target_y="$3"
  local width="$4"
  local height="$5"
  local start_y="$6"

  debug_echo "Animating slide down for window $addr to position $target_x,$target_y"

  if ! [[ "$start_y" =~ ^-?[0-9]+$ ]]; then
    start_y=$((target_y - height - 50))
  fi
  local total_delta=$((target_y - start_y))

  # Move window to start position instantly (off-screen)
  move_window_exact "$addr" "$target_x" "$start_y" >/dev/null 2>&1 || return 1
  sleep_ms "$SLIDE_DELAY"

  # Animate slide down
  for i in $(seq 1 $SLIDE_STEPS); do
    local current_y=$((start_y + (total_delta * i / SLIDE_STEPS)))
    move_window_exact "$addr" "$target_x" "$current_y" >/dev/null 2>&1 || return 1
    sleep_ms "$SLIDE_DELAY"
  done

  # Ensure final position is exact
  move_window_exact "$addr" "$target_x" "$target_y" >/dev/null 2>&1
}

# Function to animate window slide up (hide)
animate_slide_up() {
  local addr="$1"
  local start_x="$2"
  local start_y="$3"
  local width="$4"
  local height="$5"
  local end_y="$6"

  debug_echo "Animating slide up for window $addr from position $start_x,$start_y"

  if ! [[ "$end_y" =~ ^-?[0-9]+$ ]]; then
    end_y=$((start_y - height - 50))
  fi
  local total_delta=$((start_y - end_y))

  # Animate slide up
  for i in $(seq 1 $SLIDE_STEPS); do
    local current_y=$((start_y - (total_delta * i / SLIDE_STEPS)))
    move_window_exact "$addr" "$start_x" "$current_y" >/dev/null 2>&1 || return 1
    sleep_ms "$SLIDE_DELAY"
  done
  move_window_exact "$addr" "$start_x" "$end_y" >/dev/null 2>&1

  debug_echo "Slide up animation completed"
}

# Function to get monitor info including scale and name of focused monitor
get_monitor_info() {
  local monitor_data
  monitor_data=$(hyprctl monitors -j 2>/dev/null | jq -er 'map(select(.focused == true)) | .[0] | "\(.x) \(.y) \(.width) \(.height) \(.scale) \(.name)"' 2>/dev/null) || monitor_data=""
  if [ -z "$monitor_data" ]; then
    # Fallback for older Hyprland without -j support
    monitor_data=$(hyprctl monitors 2>/dev/null | awk '
      /^Monitor / {name=$2; sub(/\(.*/, "", name); x=y=w=h=scale=""; focused="no"}
      / at / {
        # e.g. "1920x1080@74.97300 at 0x0"
        split($1, res, "x"); w=res[1]; split(res[2], tmp, "@"); h=tmp[1]
        split($4, pos, "x"); x=pos[1]; y=pos[2]
      }
      /scale:/ {scale=$2}
      /focused:/ {focused=$2}
      /^$/ {
        if (focused=="yes" && x!="" && y!="" && w!="" && h!="" && scale!="" && name!="") {
          print x, y, w, h, scale, name; exit
        }
      }
      END {
        if (focused=="yes" && x!="" && y!="" && w!="" && h!="" && scale!="" && name!="") {
          print x, y, w, h, scale, name
        }
      }')
  fi
  if [ -z "$monitor_data" ] || [[ "$monitor_data" =~ ^null ]]; then
    debug_echo "Error: Could not get focused monitor information"
    return 1
  fi
  echo "$monitor_data"
}


# Function to calculate dropdown position with proper scaling and centering
calculate_dropdown_position() {
  local monitor_info=$(get_monitor_info)

  if [ $? -ne 0 ] || [ -z "$monitor_info" ]; then
    debug_echo "Error: Failed to get monitor info, using fallback values"
    echo "100 100 800 600 fallback-monitor"
    return 1
  fi

  local mon_x=$(echo $monitor_info | cut -d' ' -f1)
  local mon_y=$(echo $monitor_info | cut -d' ' -f2)
  local mon_width=$(echo $monitor_info | cut -d' ' -f3)
  local mon_height=$(echo $monitor_info | cut -d' ' -f4)
  local mon_scale=$(echo $monitor_info | cut -d' ' -f5)
  local mon_name=$(echo $monitor_info | cut -d' ' -f6)

  debug_echo "Monitor info: x=$mon_x, y=$mon_y, width=$mon_width, height=$mon_height, scale=$mon_scale"

  # Validate numeric fields
  if ! [[ "$mon_x" =~ ^-?[0-9]+$ && "$mon_y" =~ ^-?[0-9]+$ && "$mon_width" =~ ^[0-9]+$ && "$mon_height" =~ ^[0-9]+$ ]]; then
    debug_echo "Invalid monitor info format, using fallback values"
    echo "100 100 800 600 fallback-monitor"
    return 1
  fi

  # Validate scale value and provide fallback
  if [ -z "$mon_scale" ] || [ "$mon_scale" = "null" ] || [ "$mon_scale" = "0" ]; then
    debug_echo "Invalid scale value, using 1.0 as fallback"
    mon_scale="1.0"
  fi

  # Calculate logical dimensions by dividing physical dimensions by scale
  local logical_width logical_height
  if command -v bc >/dev/null 2>&1; then
    # Use bc for precise floating point calculation
    logical_width=$(echo "scale=0; $mon_width / $mon_scale" | bc | cut -d'.' -f1)
    logical_height=$(echo "scale=0; $mon_height / $mon_scale" | bc | cut -d'.' -f1)
  else
    # Fallback to integer math (multiply by 100 for precision, then divide)
    local scale_int=$(echo "$mon_scale" | sed 's/\.//' | sed 's/^0*//')
    if [ -z "$scale_int" ]; then scale_int=100; fi

    logical_width=$(((mon_width * 100) / scale_int))
    logical_height=$(((mon_height * 100) / scale_int))
  fi

  # Ensure we have valid integer values
  if ! [[ "$logical_width" =~ ^-?[0-9]+$ ]]; then logical_width=$mon_width; fi
  if ! [[ "$logical_height" =~ ^-?[0-9]+$ ]]; then logical_height=$mon_height; fi

  debug_echo "Physical resolution: ${mon_width}x${mon_height}"
  debug_echo "Logical resolution: ${logical_width}x${logical_height} (physical ÷ scale)"

  # Calculate window dimensions based on LOGICAL space percentages
  local width=$((logical_width * WIDTH_PERCENT / 100))
  local height=$((logical_height * HEIGHT_PERCENT / 100))

  # Calculate Y position from top based on percentage of LOGICAL height
  local y_offset=$((logical_height * Y_PERCENT / 100))

  # Calculate centered X position in LOGICAL space
  local x_offset=$(((logical_width - width) / 2))

  # Apply monitor offset to get final positions in logical coordinates
  local final_x=$((mon_x + x_offset))
  local final_y=$((mon_y + y_offset))

  debug_echo "Window size: ${width}x${height} (logical pixels)"
  debug_echo "Final position: x=$final_x, y=$final_y (logical coordinates)"
  debug_echo "Hyprland will scale these to physical coordinates automatically"

  echo "$final_x $final_y $width $height $mon_name"
}

get_current_workspace() {
  hyprctl activeworkspace -j 2>/dev/null | jq -r '.id // empty'
}

# Function to get stored terminal address
get_terminal_address() {
  if [ -f "$ADDR_FILE" ] && [ -s "$ADDR_FILE" ]; then
    cut -d' ' -f1 "$ADDR_FILE"
  fi
}

# Try to find an existing dropdown terminal by class (kitty only)
find_terminal_by_class() {
  hyprctl clients -j 2>/dev/null | jq -r --arg CLASS "$DROPDOWN_KITTY_CLASS" \
    '.[] | select((.class == $CLASS) or (.initialClass == $CLASS)) | .address' | head -1
}

# Function to get stored monitor name
get_terminal_monitor() {
  if [ -f "$ADDR_FILE" ] && [ -s "$ADDR_FILE" ]; then
    cut -d' ' -f2- "$ADDR_FILE"
  fi
}

# Function to check if terminal exists
terminal_exists() {
  local addr=$(get_terminal_address)
  if [ -n "$addr" ]; then
    hyprctl clients -j 2>/dev/null | jq -e --arg ADDR "$addr" 'any(.[]; .address == $ADDR)' >/dev/null 2>&1
  else
    return 1
  fi
}

# Function to check if a window address exists
window_exists() {
  local addr="$1"
  if [ -n "$addr" ]; then
    hyprctl clients -j 2>/dev/null | jq -e --arg ADDR "$addr" 'any(.[]; .address == $ADDR)' >/dev/null 2>&1
  else
    return 1
  fi
}


window_workspace_name() {
  local addr="$1"
  hyprctl clients -j 2>/dev/null | jq -r --arg ADDR "$addr" '.[] | select(.address == $ADDR) | .workspace.name // empty'
}

window_is_on_special_workspace() {
  local addr="$1"
  local workspace_name
  workspace_name=$(window_workspace_name "$addr")
  [ "$workspace_name" = "$SPECIAL_WS" ] || [ "$workspace_name" = "$SPECIAL_NAME" ]
}

workspace_matches_target() {
  local target_ws="$1"
  local current_ws="$2"
  if [ "$target_ws" = "$SPECIAL_WS" ] || [ "$target_ws" = "$SPECIAL_NAME" ]; then
    [ "$current_ws" = "$SPECIAL_WS" ] || [ "$current_ws" = "$SPECIAL_NAME" ]
  else
    [ "$current_ws" = "$target_ws" ]
  fi
}

move_window_to_workspace_silent() {
  local target_ws="$1"
  local addr="$2"
  local post_ws=""

  if [[ "$HYPR_CONFIG_MODE" == "lua" ]]; then
    local ws_expr
    ws_expr=$(lua_workspace_expr "$target_ws")
    hyprctl dispatch "hl.dsp.window.move({ window = 'address:$addr', workspace = $ws_expr, follow = false })" >/dev/null 2>&1 || return 1
    sleep 0.03
    post_ws=$(window_workspace_name "$addr")
    workspace_matches_target "$target_ws" "$post_ws"
    return $?
  fi

  # Preferred syntax on newer Hyprland builds (target a specific window by selector).
  if hypr_dispatch movetoworkspacesilent "$target_ws,address:$addr" >/dev/null 2>&1; then
    sleep 0.03
    post_ws=$(window_workspace_name "$addr")
    if workspace_matches_target "$target_ws" "$post_ws"; then
      return 0
    fi
  fi

  # Compatibility fallback for builds where selector syntax is ignored.
  hypr_dispatch focuswindow "address:$addr" >/dev/null 2>&1 || return 1
  hypr_dispatch movetoworkspacesilent "$target_ws" >/dev/null 2>&1 || return 1
  sleep 0.03
  post_ws=$(window_workspace_name "$addr")
  workspace_matches_target "$target_ws" "$post_ws"
}

infer_hidden_state() {
  local addr="$1"
  if window_is_hidden "$addr"; then
    echo "hidden"
  elif window_is_on_special_workspace "$addr"; then
    echo "hidden"
  else
    echo "shown"
  fi
}

apply_dropdown_layout() {
  local addr="$1"
  local pos_info
  pos_info=$(calculate_dropdown_position)
  if [ $? -ne 0 ]; then
    debug_echo "Warning: Failed to calculate dropdown position, layout update skipped"
    return 1
  fi

  local target_x=$(echo "$pos_info" | cut -d' ' -f1)
  local target_y=$(echo "$pos_info" | cut -d' ' -f2)
  local width=$(echo "$pos_info" | cut -d' ' -f3)
  local height=$(echo "$pos_info" | cut -d' ' -f4)
  set_window_floating "$addr" >/dev/null 2>&1
  resize_window_exact "$addr" "$width" "$height" >/dev/null 2>&1
  move_window_exact "$addr" "$target_x" "$target_y" >/dev/null 2>&1
  return 0
}

show_terminal() {
  local addr="$1"
  local current_ws
  local pos_info target_x target_y width height hidden_y
  current_ws=$(get_current_workspace)
  if ! [[ "$current_ws" =~ ^-?[0-9]+$ ]]; then
    current_ws=1
  fi
  pos_info=$(calculate_dropdown_position)
  if [ $? -ne 0 ] || [ -z "$pos_info" ]; then
    debug_echo "Failed to calculate dropdown position for show; falling back to direct layout"
    move_window_to_workspace_silent "$current_ws" "$addr" >/dev/null 2>&1 || debug_echo "Failed to move dropdown terminal to workspace $current_ws"
    apply_dropdown_layout "$addr" || debug_echo "Dropdown layout update returned non-zero"
    focus_window "$addr" >/dev/null 2>&1 || true
    set_hidden_state "shown"
    debug_echo "Dropdown terminal shown"
    return 0
  fi

  target_x=$(echo "$pos_info" | cut -d' ' -f1)
  target_y=$(echo "$pos_info" | cut -d' ' -f2)
  width=$(echo "$pos_info" | cut -d' ' -f3)
  height=$(echo "$pos_info" | cut -d' ' -f4)
  hidden_y=$(get_hidden_y_for_window "$addr" "$height")
  if window_is_on_special_workspace "$addr"; then
    move_window_to_workspace_silent "$current_ws" "$addr" >/dev/null 2>&1 || debug_echo "Failed to move dropdown terminal to workspace $current_ws"
  fi
  set_window_floating "$addr" >/dev/null 2>&1 || true
  resize_window_exact "$addr" "$width" "$height" >/dev/null 2>&1 || true
  animate_slide_down "$addr" "$target_x" "$target_y" "$width" "$height" "$hidden_y" || move_window_exact "$addr" "$target_x" "$target_y" >/dev/null 2>&1
  focus_window "$addr" >/dev/null 2>&1 || true
  set_hidden_state "shown"
  debug_echo "Dropdown terminal shown"
  return 0
}

hide_terminal() {
  local addr="$1"
  local geometry start_x start_y width height hidden_y
  if window_is_hidden "$addr" || window_is_on_special_workspace "$addr"; then
    set_hidden_state "hidden"
    debug_echo "Dropdown terminal already hidden"
    return 0
  fi

  geometry=$(get_window_geometry "$addr")
  if [ -n "$geometry" ]; then
    start_x=$(echo "$geometry" | awk '{print $1}')
    start_y=$(echo "$geometry" | awk '{print $2}')
    width=$(echo "$geometry" | awk '{print $3}')
    height=$(echo "$geometry" | awk '{print $4}')
  else
    local pos_info
    pos_info=$(calculate_dropdown_position)
    start_x=$(echo "$pos_info" | cut -d' ' -f1)
    start_y=$(echo "$pos_info" | cut -d' ' -f2)
    width=$(echo "$pos_info" | cut -d' ' -f3)
    height=$(echo "$pos_info" | cut -d' ' -f4)
  fi

  if ! [[ "$height" =~ ^[0-9]+$ ]]; then
    height=702
  fi
  hidden_y=$(get_hidden_y_for_window "$addr" "$height")
  if ! [[ "$start_x" =~ ^-?[0-9]+$ && "$start_y" =~ ^-?[0-9]+$ ]]; then
    debug_echo "Missing geometry for slide-up animation; moving off-screen directly"
    move_window_exact "$addr" "$start_x" "$hidden_y" >/dev/null 2>&1 || true
  else
    animate_slide_up "$addr" "$start_x" "$start_y" "$width" "$height" "$hidden_y" || true
  fi

  if ! window_is_hidden "$addr"; then
    debug_echo "Dropdown not off-screen after slide; trying direct off-screen move"
    move_window_exact "$addr" "$start_x" "$hidden_y" >/dev/null 2>&1 || true
  fi
  if ! window_is_hidden "$addr"; then
    debug_echo "Off-screen hide failed, falling back to $SPECIAL_WS"
    if ! move_window_to_workspace_silent "$SPECIAL_WS" "$addr"; then
      debug_echo "Failed to move dropdown terminal to $SPECIAL_WS"
      return 1
    fi
  fi
  set_hidden_state "hidden"
  debug_echo "Dropdown terminal hidden"
  return 0
}

hide_terminal_silent() {
  local addr="$1"
  local geometry start_x height hidden_y
  geometry=$(get_window_geometry "$addr")
  if [ -n "$geometry" ]; then
    start_x=$(echo "$geometry" | awk '{print $1}')
    height=$(echo "$geometry" | awk '{print $4}')
  fi
  if ! [[ "$height" =~ ^[0-9]+$ ]]; then
    height=702
  fi
  hidden_y=$(get_hidden_y_for_window "$addr" "$height")
  if ! [[ "$start_x" =~ ^-?[0-9]+$ ]]; then
    start_x=0
  fi
  move_window_exact "$addr" "$start_x" "$hidden_y" >/dev/null 2>&1 || true
  move_window_to_workspace_silent "$SPECIAL_WS" "$addr" >/dev/null 2>&1 || true
  set_hidden_state "hidden"
  debug_echo "Dropdown terminal hidden (silent)"
  return 0
}

# Function to spawn terminal and capture its address
spawn_terminal() {
  debug_echo "Creating new dropdown terminal with command: $TERMINAL_CMD"

  # Calculate dropdown position for later use
  local pos_info=$(calculate_dropdown_position)
  if [ $? -ne 0 ]; then
    debug_echo "Warning: Using fallback positioning"
  fi

  local target_x=$(echo $pos_info | cut -d' ' -f1)
  local target_y=$(echo $pos_info | cut -d' ' -f2)
  local width=$(echo $pos_info | cut -d' ' -f3)
  local height=$(echo $pos_info | cut -d' ' -f4)
  local monitor_name=$(echo $pos_info | cut -d' ' -f5)

  debug_echo "Target position: ${target_x},${target_y}, size: ${width}x${height}"

  # Get window count before spawning
  local windows_before=$(hyprctl clients -j)
  local count_before=$(echo "$windows_before" | jq 'length')

  # Launch terminal with pre-applied workspace/geometry hints to avoid visible zigzag.
  local launch_cmd="[workspace $SPECIAL_WS silent;float;size $width $height;move $target_x $target_y] $TERMINAL_CMD"
  hypr_exec_cmd "$launch_cmd"

  local new_addr=""
  for _ in $(seq 1 20); do
    local windows_after=$(hyprctl clients -j)
    local recovered
    recovered=$(echo "$windows_after" | jq -r --arg CLASS "$DROPDOWN_KITTY_CLASS" \
      '.[] | select((.class == $CLASS) or (.initialClass == $CLASS)) | .address' | head -1)
    if [ -n "$recovered" ] && [ "$recovered" != "null" ]; then
      new_addr="$recovered"
      break
    fi

    local count_after=$(echo "$windows_after" | jq 'length')
    if [ "$count_after" -gt "$count_before" ]; then
      new_addr=$(comm -13 \
        <(echo "$windows_before" | jq -r '.[].address' | sort) \
        <(echo "$windows_after" | jq -r '.[].address' | sort) |
        head -1)
      if [ -n "$new_addr" ] && [ "$new_addr" != "null" ]; then
        break
      fi
    fi
    sleep 0.1
  done

  if [ -n "$new_addr" ] && [ "$new_addr" != "null" ]; then
    # Store the address and monitor name
    echo "$new_addr $monitor_name" >"$ADDR_FILE"
    debug_echo "Terminal created with address: $new_addr in special workspace on monitor $monitor_name"

    # Configure in special workspace and keep hidden until explicitly toggled.
    set_window_floating "$new_addr" >/dev/null 2>&1
    resize_window_exact "$new_addr" "$width" "$height" >/dev/null 2>&1
    move_window_exact "$new_addr" "$target_x" "$target_y" >/dev/null 2>&1
    if [ "$STARTUP_MODE" = true ]; then
      hide_terminal_silent "$new_addr" || debug_echo "Failed to hide new dropdown terminal after spawn (silent)"
    else
      hide_terminal "$new_addr" || debug_echo "Failed to hide new dropdown terminal after spawn"
    fi

    return 0
  fi

  debug_echo "Failed to get terminal address"
  return 1
}

# Main logic
TERMINAL_ADDR=$(resolve_terminal_address)
if [ -z "$TERMINAL_ADDR" ]; then
  debug_echo "No existing terminal found, creating new one"
  if spawn_terminal; then
    TERMINAL_ADDR=$(get_terminal_address)
  fi
fi

if [ -z "$TERMINAL_ADDR" ]; then
  debug_echo "No dropdown terminal instance is available"
  exit 1
fi

if [ "$STARTUP_MODE" = true ]; then
  debug_echo "Startup mode requested: ensuring dropdown terminal exists and stays hidden"
  hide_terminal_silent "$TERMINAL_ADDR"
  exit 0
fi
HIDDEN_STATE=$(get_hidden_state)
if [ "$HIDDEN_STATE" != "hidden" ] && [ "$HIDDEN_STATE" != "shown" ]; then
  HIDDEN_STATE=$(infer_hidden_state "$TERMINAL_ADDR")
  set_hidden_state "$HIDDEN_STATE"
fi

if [ "$HIDDEN_STATE" = "hidden" ]; then
  show_terminal "$TERMINAL_ADDR"
else
  hide_terminal "$TERMINAL_ADDR"
fi
