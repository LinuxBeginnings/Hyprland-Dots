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
scriptsDir="${XDG_CONFIG_HOME:-$HOME/.config}/hypr/scripts"
iDIR="${XDG_CONFIG_HOME:-$HOME/.config}/swaync/images"
# shellcheck source=/dev/null
. "$scriptsDir/WallpaperCmd.sh" 2>/dev/null || true

rofi_theme="${XDG_CONFIG_HOME:-$HOME/.config}/rofi/config-wallpaper.rasi"
lock_cache_dir="${XDG_CONFIG_HOME:-$HOME/.config}/hypr/wallpaper_effects"
lock_wallpaper_link="$lock_cache_dir/.hyprlock_current"
lock_wallpaper_current="$lock_cache_dir/.wallpaper_current"
video_cache_dir="$HOME/.cache/hyprlock_preview"
find_notify_send() {
  local candidate=""
  if candidate="$(command -v notify-send 2>/dev/null)"; then
    [ -n "$candidate" ] && [ -x "$candidate" ] && { printf '%s\n' "$candidate"; return 0; }
  fi
  for candidate in /usr/bin/notify-send /usr/sbin/notify-send /bin/notify-send /sbin/notify-send; do
    [ -x "$candidate" ] && { printf '%s\n' "$candidate"; return 0; }
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
read_wallpaper_from_query() {
  local monitor="$1"
  [ -n "$monitor" ] || return 1
  "$WWW_CMD" query 2>/dev/null | awk -v mon="$monitor" '
    {
      line=$0
      sub(/^Monitor[[:space:]]+/, "", line)
      sub(/^:[[:space:]]*/, "", line)
      mon_name=line
      sub(/:.*/, "", mon_name)
      gsub(/^[[:space:]]+|[[:space:]]+$/, "", mon_name)
      if (mon_name != mon) next

      path=line
      sub(/^.*image:[[:space:]]*/, "", path)
      gsub(/^[[:space:]]+|[[:space:]]+$/, "", path)
      if (path != line && length(path) > 0) {
        print path
        exit
      }
    }
  '
}

read_cached_wallpaper() {
  local cache_file="$1"
  [ -f "$cache_file" ] || return 1
  awk 'NF && $0 !~ /^filter/ {print; exit}' "$cache_file"
}

read_wallpaper_from_cache() {
  local monitor="$1"
  local cache_root="${WWW_CACHE_DIR:-$HOME/.cache/awww}"
  local cache_file="$cache_root/$monitor"
  local fallback_cache=""
  local path=""

  case "$cache_root" in
    "$HOME/.cache/awww")
      fallback_cache="$HOME/.cache/swww/$monitor"
      ;;
    "$HOME/.cache/swww")
      fallback_cache="$HOME/.cache/awww/$monitor"
      ;;
  esac

  path="$(read_cached_wallpaper "$cache_file" 2>/dev/null || true)"
  if [ -z "$path" ] && [ -n "$fallback_cache" ]; then
    path="$(read_cached_wallpaper "$fallback_cache" 2>/dev/null || true)"
  fi

  [ -n "$path" ] && [ -f "$path" ] || return 1
  printf '%s\n' "$path"
}

get_active_workspace_monitor() {
  hyprctl activeworkspace -j 2>/dev/null | jq -r '.monitor // empty' | head -n1
}

monitor_exists() {
  local monitor="$1"
  [ -n "$monitor" ] || return 1
  hyprctl monitors -j 2>/dev/null | jq -r --arg mon "$monitor" '.[] | select(.name == $mon) | .name' | grep -qx "$monitor"
}

focused_monitor=""
requested_monitor="${1:-${HYPRLOCK_TARGET_MONITOR:-}}"
if monitor_exists "$requested_monitor"; then
  focused_monitor="$requested_monitor"
fi
if [[ -z "$focused_monitor" ]]; then
  workspace_monitor="$(get_active_workspace_monitor)"
  if monitor_exists "$workspace_monitor"; then
    focused_monitor="$workspace_monitor"
  fi
fi
if [[ -z "$focused_monitor" ]]; then
  focused_monitor=$(hyprctl monitors -j | jq -r '.[] | select(.focused) | .name' | head -n1)
fi
if [[ -z "$focused_monitor" ]]; then
  notify_err "Could not detect target monitor"
  exit 1
fi

per_monitor_rofi_link="${XDG_CONFIG_HOME:-$HOME/.config}/rofi/.current_wallpaper_${focused_monitor}"
per_monitor_wallpaper_current="$lock_cache_dir/.wallpaper_current_${focused_monitor}"

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

current_monitor_path=""
if [ -n "${WWW_CMD:-}" ] && command -v "$WWW_CMD" >/dev/null 2>&1; then
  current_monitor_path="$(read_wallpaper_from_query "$focused_monitor")"
fi
if [ -z "$current_monitor_path" ] && [ -L "$per_monitor_rofi_link" ]; then
  current_monitor_path="$(readlink -f "$per_monitor_rofi_link" 2>/dev/null || true)"
fi
if [ -z "$current_monitor_path" ] && [ -f "$per_monitor_rofi_link" ]; then
  current_monitor_path="$per_monitor_rofi_link"
fi
if [ -z "$current_monitor_path" ] && [ -f "$per_monitor_wallpaper_current" ]; then
  current_monitor_path="$per_monitor_wallpaper_current"
fi
if [ -z "$current_monitor_path" ]; then
  current_monitor_path="$(read_wallpaper_from_cache "$focused_monitor" 2>/dev/null || true)"
fi
if [ -n "$current_monitor_path" ] && [ ! -f "$current_monitor_path" ]; then
  current_monitor_path=""
fi
current_monitor_name=""
if [ -n "$current_monitor_path" ]; then
  current_monitor_name="Current monitor: $(basename "$current_monitor_path")"
fi

rofi_command="rofi -i -show -dmenu -config $rofi_theme -theme-str $rofi_override"

menu() {
  IFS=$'\n' sorted_options=($(sort <<<"${PICS[*]}"))
  printf "%s\x00icon\x1f%s\n" "$RANDOM_PIC_NAME" "$RANDOM_PIC"
  if [ -n "$current_monitor_name" ]; then
    printf "%s\x00icon\x1f%s\n" "$current_monitor_name" "$current_monitor_path"
  fi
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
  local target_monitor="${2:-$focused_monitor}"
  local final_path="$selected_file"

  if [ ! -f "$selected_file" ]; then
    notify_err "Failed for $target_monitor: selected file not found"
    return 1
  fi

  if [[ "$selected_file" =~ \.(mp4|mkv|mov|webm|MP4|MKV|MOV|WEBM)$ ]]; then
    if ! command -v ffmpeg >/dev/null 2>&1; then
      notify_err "Failed for $target_monitor: ffmpeg not found for video preview"
      return 1
    fi
    mkdir -p "$video_cache_dir"
    local video_name
    video_name="$(basename "$selected_file")"
    final_path="$video_cache_dir/${video_name}.png"
    if ! ffmpeg -v error -y -i "$selected_file" -ss 00:00:01.000 -vframes 1 "$final_path"; then
      notify_err "Failed for $target_monitor: could not generate video preview"
      return 1
    fi
  fi

  mkdir -p "$lock_cache_dir"
  if ! ln -sf "$final_path" "$lock_wallpaper_link"; then
    notify_err "Failed for $target_monitor: could not update hyprlock wallpaper link"
    return 1
  fi
  if ! cp -f "$final_path" "$lock_wallpaper_current"; then
    notify_err "Failed for $target_monitor: could not update lock fallback wallpaper"
    return 1
  fi

  update_hyprlock_config "${XDG_CONFIG_HOME:-$HOME/.config}/hypr/hyprlock.conf" "$lock_wallpaper_link"
  update_hyprlock_config "${XDG_CONFIG_HOME:-$HOME/.config}/hypr/hyprlock-2k.conf" "$lock_wallpaper_link"
  update_hyprlock_config "${XDG_CONFIG_HOME:-$HOME/.config}/hypr/hyprlock-1080p.conf" "$lock_wallpaper_link"

  pkill -USR1 hyprlock 2>/dev/null || true

  local resolved_path=""
  if [ -L "$lock_wallpaper_link" ]; then
    resolved_path="$(readlink -f "$lock_wallpaper_link" 2>/dev/null || true)"
  elif [ -f "$lock_wallpaper_link" ]; then
    resolved_path="$lock_wallpaper_link"
  fi

  if [ -z "$resolved_path" ] || [ ! -f "$resolved_path" ]; then
    notify_err "Failed for $target_monitor: hyprlock wallpaper was not applied"
    return 1
  fi

  notify_ok "Set for $target_monitor: $(basename "$resolved_path")"
  return 0
}

main() {
  choice=$(menu | $rofi_command)
  choice=$(echo "$choice" | xargs)

  if [[ -z "$choice" ]]; then
    exit 0
  fi

  if [[ "$choice" == "$RANDOM_PIC_NAME" ]]; then
    set_hyprlock_wallpaper "$RANDOM_PIC" "$focused_monitor" || exit 1
    return
  fi
  if [[ "$choice" == "$current_monitor_name" && -n "$current_monitor_path" ]]; then
    set_hyprlock_wallpaper "$current_monitor_path" "$focused_monitor" || exit 1
    return
  fi

  if [[ "$choice" == "$current_lock_name" && -n "$current_lock_path" ]]; then
    set_hyprlock_wallpaper "$current_lock_path" "$focused_monitor" || exit 1
    return
  fi

  if [[ -f "$choice" ]]; then
    set_hyprlock_wallpaper "$choice" "$focused_monitor" || exit 1
    return
  fi

  choice_basename=$(basename "$choice" | sed 's/\(.*\)\.[^.]*$/\1/')
  selected_file=$(find "$wallDIR" -iname "$choice_basename.*" -print -quit)

  if [[ -z "$selected_file" ]]; then
    notify_err "Selected choice not found: $choice"
    exit 1
  fi

  set_hyprlock_wallpaper "$selected_file" "$focused_monitor" || exit 1
}

if pidof rofi >/dev/null; then
  pkill rofi
fi

main
