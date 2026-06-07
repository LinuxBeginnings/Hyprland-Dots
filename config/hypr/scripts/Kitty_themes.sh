#!/usr/bin/env bash
# ==================================================
#  KoolDots (2026)
#  Project URL: https://github.com/LinuxBeginnings
#  License: GNU GPLv3
#  SPDX-License-Identifier: GPL-3.0-or-later
# ==================================================
# Kitty Themes Source https://github.com/dexpota/kitty-themes #

# Define directories and variables
kitty_themes_DiR="$HOME/.config/kitty/kitty-themes" # Kitty Themes Directory
kitty_config="$HOME/.config/kitty/kitty.conf"
iDIR="$HOME/.config/swaync/images" # For notifications
rofi_theme_for_this_script="$HOME/.config/rofi/config-kitty-theme.rasi"
wallust_refresh_script="$HOME/.config/hypr/scripts/WallustSwww.sh"
debug_log="${XDG_CACHE_HOME:-$HOME/.cache}/kooldots-kitty-themes.log"

# --- Helper Functions ---
notify_user() {
  notify-send -u low -i "$1" "$2" "$3"
}

log_debug() {
  mkdir -p "$(dirname "$debug_log")" 2>/dev/null || true
  printf '[%s] %s\n' "$(date '+%Y-%m-%d %H:%M:%S')" "$*" >>"$debug_log" 2>/dev/null || true
}

resolve_theme_selection() {
  local rofi_output="$1"
  local idx

  rofi_output="${rofi_output//$'\r'/}"
  rofi_output="${rofi_output//$'\n'/}"

  if [[ "$rofi_output" =~ ^[0-9]+$ ]] && [ "$rofi_output" -lt "${#available_theme_names[@]}" ]; then
    current_selection_index="$rofi_output"
    theme_to_preview_now="${available_theme_names[$current_selection_index]}"
    return 0
  fi

  for idx in "${!available_theme_names[@]}"; do
    if [[ "${available_theme_names[$idx]}" == "$rofi_output" ]]; then
      current_selection_index="$idx"
      theme_to_preview_now="${available_theme_names[$current_selection_index]}"
      return 0
    fi
  done

  return 1
}

# Function to apply the selected kitty theme
apply_kitty_theme_to_config() {
  local theme_name_to_apply="$1"
  local apply_mode="${2:-preview}"
  local is_wallpaper_mode=0
  if [ -z "$theme_name_to_apply" ]; then
    echo "Error: No theme name provided to apply_kitty_theme_to_config." >&2
    return 1
  fi
  local theme_file_path_to_apply
  if [ "$theme_name_to_apply" = "Set by wallpaper" ]; then
    is_wallpaper_mode=1
    theme_file_path_to_apply="$kitty_themes_DiR/01-Wallust.conf"
  elif [ "$theme_name_to_apply" = "Default no color" ]; then
    theme_file_path_to_apply="$kitty_themes_DiR/00-Default.conf"
  else
    theme_file_path_to_apply="$kitty_themes_DiR/$theme_name_to_apply.conf"
  fi

  if [ ! -f "$theme_file_path_to_apply" ]; then
    notify_user "$iDIR/error.png" "Error" "Theme file not found: $(basename "$theme_file_path_to_apply")"
    return 1
  fi

  local temp_kitty_config_file
  temp_kitty_config_file=$(mktemp)
  cp "$kitty_config" "$temp_kitty_config_file"

  local include_target
  include_target="include ./kitty-themes/$(basename "$theme_file_path_to_apply")"

  if grep -q -E '^[#[:space:]]*include\s+\./kitty-themes/.*\.conf' "$temp_kitty_config_file"; then
    sed -i -E "s|^([#[:space:]]*include\s+\./kitty-themes/).*\.conf|$include_target|g" "$temp_kitty_config_file"
  else
    if [ -s "$temp_kitty_config_file" ] && [ "$(tail -c1 "$temp_kitty_config_file")" != "" ]; then
      echo >>"$temp_kitty_config_file"
    fi
    echo "$include_target" >>"$temp_kitty_config_file"
  fi

  cp "$temp_kitty_config_file" "$kitty_config"
  rm "$temp_kitty_config_file"
  local trigger_wallust_refresh=0
  if [ "$theme_name_to_apply" = "Set by wallpaper" ] && [ -x "$wallust_refresh_script" ]; then
    trigger_wallust_refresh=1
  fi
  if [ "$trigger_wallust_refresh" -eq 1 ]; then
    "$wallust_refresh_script" >/dev/null 2>&1 &
    log_debug "wallust_refresh_background_started"
  fi
  if pidof kitty >/dev/null 2>&1; then
    if [ "$apply_mode" = "apply" ] && [ "$is_wallpaper_mode" -eq 0 ] && command -v kitty >/dev/null 2>&1; then
      (
        kitty @ load-config >/dev/null 2>&1 || true
        kitty @ set-colors --all --configured "$theme_file_path_to_apply" >/dev/null 2>&1 || true
      ) &
    fi
    for pid_kitty in $(pidof kitty); do
      if [ -n "$pid_kitty" ]; then
        kill -SIGUSR1 "$pid_kitty"
      fi
    done
  fi
  return 0
}

# --- Main Script Execution ---

if [ ! -d "$kitty_themes_DiR" ]; then
  notify_user "$iDIR/error.png" "E-R-R-O-R" "Kitty Themes directory not found: $kitty_themes_DiR"
  exit 1
fi

if [ ! -f "$rofi_theme_for_this_script" ]; then
  notify_user "$iDIR/error.png" "Rofi Config Missing" "Rofi theme for Kitty selector not found at: $rofi_theme_for_this_script."
  exit 1
fi

original_kitty_config_content_backup=$(cat "$kitty_config")

mapfile -t available_theme_names < <(find "$kitty_themes_DiR" -maxdepth 1 -name "*.conf" -type f -printf "%f\n" | sed 's/\.conf$//' | grep -v -E '^(00-Default|01-Wallust)$' | sort)
available_theme_names=("Set by wallpaper" "Default no color" "${available_theme_names[@]}")

if [ ${#available_theme_names[@]} -eq 0 ]; then
  notify_user "$iDIR/error.png" "No Kitty Themes" "No .conf files found in $kitty_themes_DiR."
  exit 1
fi

current_selection_index=0
current_active_theme_name=$(awk -F'include ./kitty-themes/|\\.conf' '/^[[:space:]]*include \\.\/kitty-themes\/.*\\.conf/{print $2; exit}' "$kitty_config")
if [ "$current_active_theme_name" = "01-Wallust" ]; then
  current_active_theme_name="Set by wallpaper"
elif [ "$current_active_theme_name" = "00-Default" ]; then
  current_active_theme_name="Default no color"
fi

if [ -n "$current_active_theme_name" ]; then
  for i in "${!available_theme_names[@]}"; do
    if [[ "${available_theme_names[$i]}" == "$current_active_theme_name" ]]; then
      current_selection_index=$i
      break
    fi
  done
fi
theme_to_preview_now="${available_theme_names[$current_selection_index]}"

while true; do

  rofi_input_list=""
  for theme_name_in_list in "${available_theme_names[@]}"; do
    rofi_input_list+="$theme_name_in_list\n"
  done
  rofi_input_list_trimmed="${rofi_input_list%\\n}"

  chosen_selection_from_rofi=$(echo -e "$rofi_input_list_trimmed" |
    rofi -dmenu -i \
      -no-custom \
      -format 'i' \
      -p "Kitty Theme" \
      -mesg "Enter: Preview | Ctrl+S (or Alt+1): Apply & Exit | Esc: Cancel" \
      -config "$rofi_theme_for_this_script" \
      -selected-row "$current_selection_index" \
      -kb-custom-1 "Control+s,Control+S,Alt+1")

  rofi_exit_code=$?
  log_debug "rofi_exit=$rofi_exit_code rofi_output='${chosen_selection_from_rofi}' current_index=$current_selection_index current_theme='${available_theme_names[$current_selection_index]}'"

  if [ $rofi_exit_code -eq 0 ]; then
    if resolve_theme_selection "$chosen_selection_from_rofi"; then
      log_debug "resolved_enter index=$current_selection_index theme='${theme_to_preview_now}'"
      if ! apply_kitty_theme_to_config "$theme_to_preview_now" "preview"; then
        echo "$original_kitty_config_content_backup" >"$kitty_config"
        for pid_kitty in $(pidof kitty); do if [ -n "$pid_kitty" ]; then kill -SIGUSR1 "$pid_kitty"; fi; done
        notify_user "$iDIR/error.png" "Preview Error" "Failed to apply $theme_to_preview_now. Reverted."
        exit 1
      fi
      continue
    else
      :
    fi
  elif [ $rofi_exit_code -eq 1 ]; then
    notify_user "$iDIR/note.png" "Kitty Theme" "Selection cancelled. Reverting to original theme."
    echo "$original_kitty_config_content_backup" >"$kitty_config"
    for pid_kitty in $(pidof kitty); do if [ -n "$pid_kitty" ]; then kill -SIGUSR1 "$pid_kitty"; fi; done
    break
  elif [ $rofi_exit_code -ge 10 ] && [ $rofi_exit_code -le 28 ]; then # custom keybindings
    resolve_theme_selection "$chosen_selection_from_rofi" || true
    log_debug "resolved_custom index=$current_selection_index theme='${theme_to_preview_now}' exit=$rofi_exit_code"
    apply_kitty_theme_to_config "$theme_to_preview_now" "apply"
    notify_user "$iDIR/ja.png" "Kitty Theme Applied" "$theme_to_preview_now"
    break
  else
    notify_user "$iDIR/error.png" "Rofi Error" "Unexpected Rofi exit ($rofi_exit_code). Reverting."
    echo "$original_kitty_config_content_backup" >"$kitty_config"
    for pid_kitty in $(pidof kitty); do if [ -n "$pid_kitty" ]; then kill -SIGUSR1 "$pid_kitty"; fi; done
    break
  fi
done

exit 0
