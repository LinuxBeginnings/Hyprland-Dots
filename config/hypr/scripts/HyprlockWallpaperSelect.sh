#!/usr/bin/env bash
# ==================================================
#  KoolDots (2026)
#  Project URL: https://github.com/LinuxBeginnings
#  License: GNU GPLv3
#  SPDX-License-Identifier: GPL-3.0-or-later
# ==================================================
# Hyprlock wallpaper selector (per-monitor + video preview fallback)

PICTURES_DIR="$(xdg-user-dir PICTURES 2>/dev/null || echo "$HOME/Pictures")"
wallDIR="$PICTURES_DIR/wallpapers"
scriptsDir="${XDG_CONFIG_HOME:-$HOME/.config}/hypr/scripts"
iDIR="${XDG_CONFIG_HOME:-$HOME/.config}/swaync/images"

rofi_theme="${XDG_CONFIG_HOME:-$HOME/.config}/rofi/config-wallpaper.rasi"
video_cache_dir="$HOME/.cache/hyprlock_preview"

find_notify_send() {
  local candidate=""
  if candidate="$(command -v notify-send 2>/dev/null)"; then
    [ -n "$candidate" ] && [ -x "$candidate" ] && {
      printf '%s\n' "$candidate"
      return 0
    }
  fi
  for candidate in /usr/bin/notify-send /usr/sbin/notify-send /bin/notify-send /sbin/notify-send; do
    [ -x "$candidate" ] && {
      printf '%s\n' "$candidate"
      return 0
    }
  done
  return 1
}

NOTIFY_SEND_BIN="$(find_notify_send || true)"

notify_err() {
  if [ -n "$NOTIFY_SEND_BIN" ]; then
    if [ -f "$iDIR/error.png" ]; then
      "$NOTIFY_SEND_BIN" -i "$iDIR/error.png" "Hyprlock Wallpaper" "$1"
    else
      "$NOTIFY_SEND_BIN" "Hyprlock Wallpaper" "$1"
    fi
  fi
}

notify_ok() {
  if [ -n "$NOTIFY_SEND_BIN" ]; then
    if [ -f "$iDIR/ja.png" ]; then
      "$NOTIFY_SEND_BIN" -i "$iDIR/ja.png" "Hyprlock Wallpaper" "$1"
    else
      "$NOTIFY_SEND_BIN" "Hyprlock Wallpaper" "$1"
    fi
  fi
}

# Pre-flight checks
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

# Detect focused monitor cleanly
focused_monitor=$(hyprctl monitors -j | jq -r '.[] | select(.focused) | .name' | head -n1)
if [[ -z "$focused_monitor" ]]; then
  notify_err "Could not detect target monitor"
  exit 1
fi

# Isolated target files for lockscreen (monitor-specific AND global fallback)
TARGET_LOCKSCREEN_MON="${XDG_CONFIG_HOME:-$HOME/.config}/rofi/.current_lockscreen_${focused_monitor}"
TARGET_LOCKSCREEN_FALLBACK="${XDG_CONFIG_HOME:-$HOME/.config}/rofi/.current_lockscreen"

# Desktop Wallpaper Fallback Targets from WallpaperSelect.sh
DESKTOP_ROFI_LINK="${XDG_CONFIG_HOME:-$HOME/.config}/rofi/.current_wallpaper"
DESKTOP_WALL_CURRENT="${XDG_CONFIG_HOME:-$HOME/.config}/hypr/wallpaper_effects/.wallpaper_current"

# Ensure initial lockscreen file exists on fresh install by pulling active desktop wallpaper
if [ ! -f "$TARGET_LOCKSCREEN_FALLBACK" ]; then
  mkdir -p "$(dirname "$TARGET_LOCKSCREEN_FALLBACK")"
  if [ -f "$DESKTOP_ROFI_LINK" ]; then
    cp -f "$DESKTOP_ROFI_LINK" "$TARGET_LOCKSCREEN_FALLBACK"
  elif [ -f "$DESKTOP_WALL_CURRENT" ]; then
    cp -f "$DESKTOP_WALL_CURRENT" "$TARGET_LOCKSCREEN_FALLBACK"
  fi
fi

# Monitor icon sizing for Rofi
scale_factor=$(hyprctl monitors -j | jq -r --arg mon "$focused_monitor" '.[] | select(.name == $mon) | .scale')
monitor_height=$(hyprctl monitors -j | jq -r --arg mon "$focused_monitor" '.[] | select(.name == $mon) | .height')
icon_size=$(echo "scale=1; ($monitor_height * 3) / ($scale_factor * 150)" | bc)
adjusted_icon_size=$(echo "$icon_size" | awk '{if ($1 < 15) $1 = 20; if ($1 > 25) $1 = 25; print $1}')
rofi_override="element-icon{size:${adjusted_icon_size}%;}"

# Gather wallpapers
mapfile -d '' PICS < <(find -L "${wallDIR}" -type f \( \
  -iname "*.jpg" -o -iname "*.jpeg" -o -iname "*.png" -o -iname "*.gif" -o \
  -iname "*.bmp" -o -iname "*.tiff" -o -iname "*.webp" -o \
  -iname "*.mp4" -o -iname "*.mkv" -o -iname "*.mov" -o -iname "*.webm" \) -print0)

if [ "${#PICS[@]}" -eq 0 ]; then
  notify_err "No wallpapers found in $wallDIR"
  exit 1
fi

RANDOM_PIC="${PICS[$((RANDOM % ${#PICS[@]}))]}"
RANDOM_PIC_NAME="$(basename "$RANDOM_PIC")"

rofi_command="rofi -i -show -dmenu -config $rofi_theme -theme-str $rofi_override"

# Resolve current lockscreen wallpaper path for the active display
CURRENT_MON_PIC_PATH=""

if [ -f "$TARGET_LOCKSCREEN_MON" ]; then
  CURRENT_MON_PIC_PATH="$TARGET_LOCKSCREEN_MON"
elif [ -f "$TARGET_LOCKSCREEN_FALLBACK" ]; then
  CURRENT_MON_PIC_PATH="$TARGET_LOCKSCREEN_FALLBACK"
elif [ -f "$DESKTOP_ROFI_LINK" ]; then
  CURRENT_MON_PIC_PATH="$DESKTOP_ROFI_LINK"
fi

if [ -L "$CURRENT_MON_PIC_PATH" ]; then
  CURRENT_MON_PIC_PATH="$(readlink -f "$CURRENT_MON_PIC_PATH")"
fi

CURRENT_MON_PIC_NAME=""
if [ -n "$CURRENT_MON_PIC_PATH" ]; then
  CURRENT_MON_PIC_NAME="$(basename "$CURRENT_MON_PIC_PATH")"
fi

menu() {
  IFS=$'\n' sorted_options=($(sort <<<"${PICS[*]}"))

  printf "%s\x00icon\x1f%s\n" "Random: $RANDOM_PIC_NAME" "$RANDOM_PIC"
  if [[ -n "$CURRENT_MON_PIC_PATH" ]]; then
    printf "%s\x00icon\x1f%s\n" "Current: $CURRENT_MON_PIC_NAME" "$CURRENT_MON_PIC_PATH"
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

set_hyprlock_wallpaper() {
  local selected_file="$1"
  local final_path="$selected_file"

  if [ ! -f "$selected_file" ]; then
    notify_err "Failed for $focused_monitor: selected file not found"
    return 1
  fi

  # Handle video files by extracting frame 1 as a static wallpaper image
  if [[ "$selected_file" =~ \.(mp4|mkv|mov|webm|MP4|MKV|MOV|WEBM)$ ]]; then
    if ! command -v ffmpeg >/dev/null 2>&1; then
      notify_err "Failed for $focused_monitor: ffmpeg required for video preview"
      return 1
    fi
    mkdir -p "$video_cache_dir"
    local video_name
    video_name="$(basename "$selected_file")"
    final_path="$video_cache_dir/${video_name}.png"
    if ! ffmpeg -v error -y -i "$selected_file" -ss 00:00:01.000 -vframes 1 "$final_path"; then
      notify_err "Failed for $focused_monitor: could not extract video frame"
      return 1
    fi
  fi

  # Ensure target directory exists
  mkdir -p "$(dirname "$TARGET_LOCKSCREEN_MON")"

  # Copy to monitor-specific target AND global fallback target
  cp -f "$final_path" "$TARGET_LOCKSCREEN_MON"
  cp -f "$final_path" "$TARGET_LOCKSCREEN_FALLBACK"

  notify_ok "Set for $focused_monitor: $(basename "$selected_file")"
  return 0
}

main() {
  "${XDG_CONFIG_HOME:-$HOME/.config}/hypr/scripts/RofiFocusedWallpaperLink.sh" >/dev/null 2>&1 || true
  choice=$(menu | $rofi_command)
  choice=$(echo "$choice" | xargs)

  if [[ -z "$choice" ]]; then
    exit 0
  fi

  if [[ "$choice" == "$RANDOM_PIC_NAME" ]]; then
    set_hyprlock_wallpaper "$RANDOM_PIC" || exit 1
    return
  fi

  if [[ -f "$choice" ]]; then
    set_hyprlock_wallpaper "$choice" || exit 1
    return
  fi

  choice_basename=$(basename "$choice" | sed 's/\(.*\)\.[^.]*$/\1/')
  selected_file=$(find "$wallDIR" -iname "$choice_basename.*" -print -quit)

  if [[ -z "$selected_file" ]]; then
    notify_err "Selected choice not found: $choice"
    exit 1
  fi

  set_hyprlock_wallpaper "$selected_file" || exit 1
}

if pidof rofi >/dev/null; then
  pkill rofi
fi

main
