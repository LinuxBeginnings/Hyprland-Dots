#!/usr/bin/env bash
# ==================================================
#  KoolDots (2026)
#  Project URL: https://github.com/LinuxBeginnings
#  License: GNU GPLv3
#  SPDX-License-Identifier: GPL-3.0-or-later
# ==================================================
# Hyprlock wallpaper selector (images + video fallback)

PICTURES_DIR="$(xdg-user-dir PICTURES 2>/dev/null || echo "$HOME/Pictures")"
wallDIR="$PICTURES_DIR/wallpapers"
scriptsDir="$HOME/.config/hypr/scripts"
iDIR="$HOME/.config/swaync/images"

rofi_theme="$HOME/.config/rofi/config-wallpaper.rasi"
lock_cache_dir="$HOME/.config/hypr/wallpaper_effects"
lock_wallpaper_link="$lock_cache_dir/.hyprlock_current"
video_cache_dir="$HOME/.cache/hyprlock_preview"

notify_err() {
  if command -v notify-send >/dev/null 2>&1; then
    if [ -f "$iDIR/error.png" ]; then
      notify-send -i "$iDIR/error.png" "Hyprlock Wallpaper" "$1"
    else
      notify-send "Hyprlock Wallpaper" "$1"
    fi
  fi
}

if ! command -v rofi >/dev/null 2>&1; then
  notify_err "rofi not found"
  exit 1
fi
if ! command -v hyprctl >/dev/null 2>&1; then
  notify_err "hyprctl not found"
  exit 1
fi
if ! command -v jq >/dev/null 2>&1; then
  notify_err "jq not found"
  exit 1
fi
if ! command -v bc >/dev/null 2>&1; then
  notify_err "bc not found"
  exit 1
fi

focused_monitor=$(hyprctl monitors -j | jq -r '.[] | select(.focused) | .name')
if [[ -z "$focused_monitor" ]]; then
  notify_err "Could not detect focused monitor"
  exit 1
fi

scale_factor=$(hyprctl monitors -j | jq -r --arg mon "$focused_monitor" '.[] | select(.name == $mon) | .scale')
monitor_height=$(hyprctl monitors -j | jq -r --arg mon "$focused_monitor" '.[] | select(.name == $mon) | .height')
icon_size=$(echo "scale=1; ($monitor_height * 3) / ($scale_factor * 150)" | bc)
adjusted_icon_size=$(echo "$icon_size" | awk '{if ($1 < 15) $1 = 20; if ($1 > 25) $1 = 25; print $1}')
rofi_override="element-icon{size:${adjusted_icon_size}%;}"

mapfile -d '' PICS < <(find -L "${wallDIR}" -type f \( \
  -iname "*.jpg" -o -iname "*.jpeg" -o -iname "*.png" -o -iname "*.gif" -o \
  -iname "*.bmp" -o -iname "*.tiff" -o -iname "*.webp" -o \
  -iname "*.mp4" -o -iname "*.mkv" -o -iname "*.mov" -o -iname "*.webm" \) -print0)

if [ "${#PICS[@]}" -eq 0 ]; then
  notify_err "No wallpapers found in $wallDIR"
  exit 1
fi

RANDOM_PIC="${PICS[$((RANDOM % ${#PICS[@]}))]}"
RANDOM_PIC_NAME="Random: $(basename "$RANDOM_PIC")"

current_lock_path=""
if [ -L "$lock_wallpaper_link" ]; then
  current_lock_path="$(readlink -f "$lock_wallpaper_link" 2>/dev/null || true)"
elif [ -f "$lock_wallpaper_link" ]; then
  current_lock_path="$lock_wallpaper_link"
fi
current_lock_name=""
if [ -n "$current_lock_path" ]; then
  current_lock_name="Current: $(basename "$current_lock_path")"
fi

rofi_command="rofi -i -show -dmenu -config $rofi_theme -theme-str $rofi_override"

menu() {
  IFS=$'\n' sorted_options=($(sort <<<"${PICS[*]}"))
  printf "%s\x00icon\x1f%s\n" "$RANDOM_PIC_NAME" "$RANDOM_PIC"
  if [ -n "$current_lock_name" ]; then
    printf "%s\x00icon\x1f%s\n" "$current_lock_name" "$current_lock_path"
  fi
  for pic_path in "${sorted_options[@]}"; do
    pic_name=$(basename "$pic_path")
    if [[ "$pic_name" =~ \.gif$ ]]; then
      cache_gif_image="$HOME/.cache/gif_preview/${pic_name}.png"
      if [[ ! -f "$cache_gif_image" ]]; then
        mkdir -p "$HOME/.cache/gif_preview"
        magick "$pic_path[0]" -resize 1920x1080 "$cache_gif_image"
      fi
      printf "%s\x00icon\x1f%s\n" "$pic_name" "$cache_gif_image"
    elif [[ "$pic_name" =~ \.(mp4|mkv|mov|webm|MP4|MKV|MOV|WEBM)$ ]]; then
      cache_preview_image="$HOME/.cache/video_preview/${pic_name}.png"
      if [[ ! -f "$cache_preview_image" ]]; then
        mkdir -p "$HOME/.cache/video_preview"
        ffmpeg -v error -y -i "$pic_path" -ss 00:00:01.000 -vframes 1 "$cache_preview_image"
      fi
      printf "%s\x00icon\x1f%s\n" "$pic_name" "$cache_preview_image"
    else
      printf "%s\x00icon\x1f%s\n" "$pic_name" "$pic_path"
    fi
  done
}

update_hyprlock_config() {
  local conf="$1"
  local path="$2"
  [ -f "$conf" ] || return 0

  if grep -qE '^[[:space:]]*path[[:space:]]*=' "$conf"; then
    sed -i -E "s|^[[:space:]]*path[[:space:]]*=.*|    path = $path|" "$conf"
  elif grep -qE '^[[:space:]]*background[[:space:]]*{' "$conf"; then
    sed -i -E "/^[[:space:]]*background[[:space:]]*{/a\\    path = $path" "$conf"
  else
    printf "\nbackground {\n    path = %s\n}\n" "$path" >>"$conf"
  fi
}

set_hyprlock_wallpaper() {
  local selected_file="$1"
  local final_path="$selected_file"

  if [ ! -f "$selected_file" ]; then
    notify_err "Selected file not found"
    exit 1
  fi

  if [[ "$selected_file" =~ \.(mp4|mkv|mov|webm|MP4|MKV|MOV|WEBM)$ ]]; then
    if ! command -v ffmpeg >/dev/null 2>&1; then
      notify_err "ffmpeg not found for video preview"
      exit 1
    fi
    mkdir -p "$video_cache_dir"
    local video_name
    video_name="$(basename "$selected_file")"
    final_path="$video_cache_dir/${video_name}.png"
    ffmpeg -v error -y -i "$selected_file" -ss 00:00:01.000 -vframes 1 "$final_path"
  fi

  mkdir -p "$lock_cache_dir"
  ln -sf "$final_path" "$lock_wallpaper_link" || true

  update_hyprlock_config "$HOME/.config/hypr/hyprlock.conf" "$lock_wallpaper_link"
  update_hyprlock_config "$HOME/.config/hypr/hyprlock-2k.conf" "$lock_wallpaper_link"
  update_hyprlock_config "$HOME/.config/hypr/hyprlock-1080p.conf" "$lock_wallpaper_link"

  pkill -USR1 hyprlock 2>/dev/null || true
  if command -v notify-send >/dev/null 2>&1; then
    notify-send "Hyprlock wallpaper set" "$(basename "$selected_file")"
  fi
}

main() {
  choice=$(menu | $rofi_command)
  choice=$(echo "$choice" | xargs)

  if [[ -z "$choice" ]]; then
    exit 0
  fi

  if [[ "$choice" == "$RANDOM_PIC_NAME" ]]; then
    set_hyprlock_wallpaper "$RANDOM_PIC"
    return
  fi

  if [[ "$choice" == "$current_lock_name" && -n "$current_lock_path" ]]; then
    set_hyprlock_wallpaper "$current_lock_path"
    return
  fi

  if [[ -f "$choice" ]]; then
    set_hyprlock_wallpaper "$choice"
    return
  fi

  choice_basename=$(basename "$choice" | sed 's/\(.*\)\.[^.]*$/\1/')
  selected_file=$(find "$wallDIR" -iname "$choice_basename.*" -print -quit)

  if [[ -z "$selected_file" ]]; then
    notify_err "Selected choice not found: $choice"
    exit 1
  fi

  set_hyprlock_wallpaper "$selected_file"
}

if pidof rofi >/dev/null; then
  pkill rofi
fi

main
