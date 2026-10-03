#!/usr/bin/env bash
# ==================================================
#  KoolDots (2026)
#  Project URL: https://github.com/LinuxBeginnings
#  License: GNU GPLv3
#  SPDX-License-Identifier: GPL-3.0-or-later
# ==================================================
# This script for selecting wallpapers (SUPER W)

# WALLPAPERS PATH
terminal=kitty
PICTURES_DIR="$(xdg-user-dir PICTURES 2>/dev/null || echo "$HOME/Pictures")"
wallDIR="$PICTURES_DIR/wallpapers"
SCRIPTSDIR="${XDG_CONFIG_HOME:-$HOME/.config}/hypr/scripts"
# shellcheck source=/dev/null
. "$SCRIPTSDIR/WallpaperCmd.sh"
wallpaper_current="${XDG_CONFIG_HOME:-$HOME/.config}/hypr/wallpaper_effects/.wallpaper_current"
wallpaper_link="${XDG_CONFIG_HOME:-$HOME/.config}/hypr/rofi/.current_wallpaper"
wallpaper_base="${XDG_CONFIG_HOME:-$HOME/.config}/hypr/wallpaper_effects/.wallpaper_base"

# Directory for swaync
iDIR="${XDG_CONFIG_HOME:-$HOME/.config}/swaync/images"
iDIRi="${XDG_CONFIG_HOME:-$HOME/.config}/swaync/icons"

# swww/awww transition config
FPS=60 # Could potentially add options for higher refreshrates
TYPE="random"
DURATION=2
BEZIER=".43,1.19,1,.4"
if [[ "$WWW_CMD" == "swww" || "$WWW_CMD" == "awww" ]]; then
  SWWW_PARAMS=(--transition-fps "$FPS" --transition-type "$TYPE" --transition-duration "$DURATION" --transition-bezier "$BEZIER")
else
  SWWW_PARAMS=()
fi


# Check if package bc exists
if ! command -v bc &>/dev/null; then
  notify-send -i "$iDIR/error.png" "bc missing" "Install package bc first"
  exit 1
fi

# Variables
rofi_theme="${XDG_CONFIG_HOME:-$HOME/.config}/hypr/rofi/config-wallpaper.rasi"
focused_monitor=$(hyprctl monitors -j | jq -r '.[] | select(.focused) | .name')

per_monitor_wallpaper_current="${XDG_CONFIG_HOME:-$HOME/.config}/hypr/wallpaper_effects/.wallpaper_current_${focused_monitor}"
per_monitor_wallpaper_link="${XDG_CONFIG_HOME:-$HOME/.config}/hypr/rofi/.current_wallpaper_${focused_monitor}"
per_monitor_wallpaper_base="${XDG_CONFIG_HOME:-$HOME/.config}/hypr/wallpaper_effects/.wallpaper_base_${focused_monitor}"

# Ensure focused_monitor is detected
if [[ -z "$focused_monitor" ]]; then
  notify-send -i "$iDIR/error.png" "E-R-R-O-R" "Could not detect focused monitor"
  exit 1
fi

# Monitor details
scale_factor=$(hyprctl monitors -j | jq -r --arg mon "$focused_monitor" '.[] | select(.name == $mon) | .scale')
monitor_height=$(hyprctl monitors -j | jq -r --arg mon "$focused_monitor" '.[] | select(.name == $mon) | .height')

icon_size=$(echo "scale=1; ($monitor_height * 3) / ($scale_factor * 150)" | bc)
adjusted_icon_size=$(echo "$icon_size" | awk '{if ($1 < 15) $1 = 20; if ($1 > 25) $1 = 25; print $1}')
rofi_override="element-icon{size:${adjusted_icon_size}%;}"

# Kill existing wallpaper daemons for video on the focused monitor only
kill_wallpaper_for_video() {
  pkill -f "mpvpaper.*$focused_monitor" 2>/dev/null
}

# Kill existing wallpaper daemons for image on the focused monitor only
kill_wallpaper_for_image() {
  pkill -f "mpvpaper.*$focused_monitor" 2>/dev/null
}

# Retrieve wallpapers (both images & videos)
mapfile -d '' PICS < <(find -L "${wallDIR}" -type f \( \
  -iname "*.jpg" -o -iname "*.jpeg" -o -iname "*.png" -o -iname "*.gif" -o \
  -iname "*.bmp" -o -iname "*.tiff" -o -iname "*.webp" -o \
  -iname "*.mp4" -o -iname "*.mkv" -o -iname "*.mov" -o -iname "*.webm" \) -print0)

steamDIR="$HOME/.local/share/Steam/steamapps/workshop/content/431960"
wpengine_assets="$HOME/.local/share/Steam/steamapps/common/wallpaper_engine/assets"

# Retrieve Wallpaper Engine items (looking for scene files, project files, or fallback images)
if [[ -d "$steamDIR" ]]; then
  while IFS= read -r -d '' item_dir; do
    # Find the best image/preview file inside this workshop folder
    found_img=$(find "$item_dir" -maxdepth 2 -type f \( -iname "preview.gif" -o -iname "preview.jpg" -o -iname "preview.png" -o -iname "preview.jpeg" \) -print -quit 2>/dev/null)
    if [[ -z "$found_img" ]]; then
      found_img=$(find "$item_dir" -maxdepth 2 -type f \( -iname "*.jpg" -o -iname "*.png" \) -size +5k -print -quit 2>/dev/null)
    fi
    
    # If we found a valid image, add it to PICS, or fall back to project.json or scene.pkg
    if [[ -n "$found_img" && -f "$found_img" ]]; then
      PICS+=("$found_img")
    else
      fallback_file=$(find "$item_dir" -maxdepth 2 -type f \( -name "scene.json" -o -name "project.json" -o -name "scene.pkg" \) -print -quit 2>/dev/null)
      [[ -n "$fallback_file" ]] && PICS+=("$fallback_file")
    fi
  done < <(find "$steamDIR" -mindepth 1 -maxdepth 1 -type d -print0)
fi

RANDOM_PIC="${PICS[$((RANDOM % ${#PICS[@]}))]}"
RANDOM_PIC_NAME="$(basename "$RANDOM_PIC")"

read_wallpaper_from_query() {
  local monitor="$1"
  [ -n "$monitor" ] || return 1
  [ -n "${WWW_CMD:-}" ] || return 1
  command -v "$WWW_CMD" >/dev/null 2>&1 || return 1
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

CURRENT_MON_PIC_PATH="$(read_wallpaper_from_query "$focused_monitor" 2>/dev/null || true)"
if [[ -z "$CURRENT_MON_PIC_PATH" || ! -f "$CURRENT_MON_PIC_PATH" ]]; then
  if [[ -L "$per_monitor_wallpaper_link" ]]; then
    CURRENT_MON_PIC_PATH="$(readlink -f "$per_monitor_wallpaper_link" 2>/dev/null || true)"
  fi
  if [[ -z "$CURRENT_MON_PIC_PATH" || ! -f "$CURRENT_MON_PIC_PATH" ]] && [[ -f "$per_monitor_wallpaper_current" ]]; then
    CURRENT_MON_PIC_PATH="$per_monitor_wallpaper_current"
  fi
  if [[ -z "$CURRENT_MON_PIC_PATH" || ! -f "$CURRENT_MON_PIC_PATH" ]] && [[ -L "$wallpaper_link" ]]; then
    CURRENT_MON_PIC_PATH="$(readlink -f "$wallpaper_link" 2>/dev/null || true)"
  fi
  if [[ -z "$CURRENT_MON_PIC_PATH" || ! -f "$CURRENT_MON_PIC_PATH" ]] && [[ -f "$wallpaper_current" ]]; then
    CURRENT_MON_PIC_PATH="$wallpaper_current"
  fi
  if [[ ! -f "$CURRENT_MON_PIC_PATH" ]]; then
    CURRENT_MON_PIC_PATH=""
  fi
fi
CURRENT_MON_PIC_NAME=""
if [[ -n "$CURRENT_MON_PIC_PATH" ]]; then
  CURRENT_MON_PIC_NAME=$(basename "$CURRENT_MON_PIC_PATH")
fi

# Rofi command
rofi_command="rofi -i -show -dmenu -config $rofi_theme -theme-str $rofi_override"

# Sorting Wallpapers
menu() {
  IFS=$'\n' sorted_options=($(sort <<<"${PICS[*]}"))

  printf "%s\x00icon\x1f%s\n" "Random: $RANDOM_PIC_NAME" "$RANDOM_PIC"
  if [[ -n "$CURRENT_MON_PIC_PATH" && -f "$CURRENT_MON_PIC_PATH" ]]; then
    printf "%s\x00icon\x1f%s\n" "Current: $CURRENT_MON_PIC_NAME" "$CURRENT_MON_PIC_PATH"
  fi

  for pic_path in "${sorted_options[@]}"; do
    pic_name=$(basename "$pic_path")
    # Get wallpaper engine items before general checks
    if [[ "$pic_path" == *"/431960/"* ]]; then
      item_id=$(echo "$pic_path" | grep -oP '431960/\K[0-9]+')
      # Create a unique cache identifier
      file_hash=$(echo "$pic_path" | md5sum | cut -d' ' -f1)
      pic_name="WE_${item_id}_$(basename "$pic_path")"
      wp_dir=$(dirname "$pic_path")
      preview_file="$pic_path"
      # Ensure it is pointing to an actual image/gif
      if [[ ! "$pic_path" =~ \.(jpg|jpeg|png|gif)$ ]]; then
        found_preview=$(find "$wp_dir" -maxdepth 2 -type f \( -iname "preview.gif" -o -iname "preview.jpg" -o -iname "preview.png" \) -print -quit 2>/dev/null)
        [[ -n "$found_preview" ]] && preview_file="$found_preview"
      fi
      # Use a placeholder if no image exists (unlikely)
      if [[ ! -f "$preview_file" ]]; then
        mkdir -p "$HOME/.cache/Rofi-Wallpaper-Engine/WE_Preview"
        preview_file="$HOME/.cache/Rofi-Wallpaper-Engine/WE_Preview/${item_id}.png"
        if [[ ! -f "$preview_file" ]]; then
          magick -size 256x256 xc:"#24273a" "$preview_file" 2>/dev/null
        fi
      fi
      # Unique thumbnail generation for GIFs using their ID at 1 sec
      final_icon="$preview_file"
      if [[ "$preview_file" =~ \.gif$ ]]; then
        cache_we_gif="$HOME/.cache/Rofi-Wallpaper-Engine/WE_Preview/${item_id}_${file_hash}.png"
        if [[ ! -f "$cache_we_gif" ]]; then
          mkdir -p "$HOME/.cache/Rofi-Wallpaper-Engine/WE_Preview"
          ffmpeg -v error -y -ss 00:00:01.000 -i "$preview_file" -vframes 1 "$cache_we_gif" 2>/dev/null || \
          magick "${preview_file}[10]" -background none -flatten -resize 512x512 "$cache_we_gif" 2>/dev/null || \
          cp "$preview_file" "$cache_we_gif"
        fi
        if [[ -f "$cache_we_gif" ]]; then
          final_icon="$cache_we_gif"
        fi
      fi
      
      if [[ -f "$final_icon" ]]; then
        printf "%s\x00icon\x1f%s\n" "$pic_name" "$final_icon"
      else
        printf "%s\n" "$pic_name"
      fi

    # Handle normal standalone GIFs outside of Workshop, videos, and images.
    elif [[ "$pic_name" =~ \.gif$ ]]; then
      cache_gif_image="$HOME/.cache/gif_preview/${pic_name}.png"
      if [[ ! -f "$cache_gif_image" ]]; then
        mkdir -p "$HOME/.cache/gif_preview"
        magick "${pic_path}[0]" -resize 1920x1080 "$cache_gif_image"
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

# Apply Image Wallpaper
apply_image_wallpaper() {
  local image_path="$1"
  if [[ -z "$image_path" || ! -f "$image_path" ]]; then
    echo "Invalid image path: $image_path" >&2
    return 1
  fi

  echo "static" > "$HOME/.cache/Rofi-Wallpaper-Engine/Wallpaper-mode.txt"
  # Get focused monitor and set-up for transition
  local mon="${target_monitor:-${focused_monitor:-$(hyprctl monitors -j | jq -r '.[] | select(.focused == true) .name' 2>/dev/null || echo "DP-1")}}"
  local trans_dir="$HOME/.cache/Rofi-Wallpaper-Engine/WE_Transitions/${mon}"
  mkdir -p "$trans_dir" 2>/dev/null || true
  local current_still="$trans_dir/current.png"
  local source_still="$trans_dir/source.png"

  # Use saved still from wallpaper engine if in use
  if [[ -f "$current_still" ]]; then
    cp -f "$current_still" "$source_still"
  elif [[ -f "${per_monitor_wallpaper_current:-$HOME/.config/hypr/wallpaper_effects/.wallpaper_current_${mon}}" ]]; then
    cp -f "${per_monitor_wallpaper_current:-$HOME/.config/hypr/wallpaper_effects/.wallpaper_current_${mon}}" "$source_still"
  fi
  # Kill wallpaper engine on focused monitor
  while IFS= read -r pid; do
    [[ -n "$pid" ]] && kill -TERM "$pid" 2>/dev/null || true
  done < <(pgrep -f "linux-wallpaperengine.*(${mon}|--screen-root[[:space:]]+${mon})" 2>/dev/null)
  sleep 0.1
  while IFS= read -r pid; do
    [[ -n "$pid" ]] && kill -9 "$pid" 2>/dev/null || true
  done < <(pgrep -f "linux-wallpaperengine.*(${mon}|--screen-root[[:space:]]+${mon})" 2>/dev/null)

  wallpaper_ensure_daemon
  local resize_mode
  resize_mode="$(wallpaper_resize_mode "$image_path" "$mon")"
  if [[ -f "$source_still" && -s "$source_still" ]]; then
    "$WWW_CMD" img -o "$mon" --resize "$resize_mode" "$source_still" &>/dev/null
    sleep 0.05
  fi
  "$WWW_CMD" img -o "$mon" --resize "$resize_mode" "$image_path" "${SWWW_PARAMS[@]}" || {
    sleep 0.2
    "$WWW_CMD" img -o "$mon" --resize "$resize_mode" "$image_path" "${SWWW_PARAMS[@]}"
  }

  # Update transition cache and persistence files
  cp -f "$image_path" "$current_still"
  local cur_link="${per_monitor_wallpaper_link:-$HOME/.config/hypr/rofi/.current_wallpaper_${mon}}"
  local cur_file="${per_monitor_wallpaper_current:-$HOME/.config/hypr/wallpaper_effects/.wallpaper_current_${mon}}"
  mkdir -p "$(dirname "$cur_file")" "$(dirname "$cur_link")" 2>/dev/null || true
  ln -sf "$current_still" "$cur_link" || true
  cp -f "$current_still" "$cur_file" || true
  mkdir -p "$(dirname "$per_monitor_wallpaper_base")" 2>/dev/null || true
  cp -f "$current_still" "$per_monitor_wallpaper_base" || true
  [[ -n "$wallpaper_base" ]] && cp -f "$current_still" "$wallpaper_base" || true
  # Clear wallpaper engine cache to revert to using standard wallpapers
  rm -f "$HOME/.cache/current_wallpaper_${mon}" 2>/dev/null || true

  # Run additional scripts
  if ! "$SCRIPTSDIR/WallustSwww.sh" "$image_path"; then
    notify-send -i "$iDIR/error.png" "Wallust failed" "Wallpaper theme not refreshed"
    return 1
  fi
  sleep 0.5
  "$SCRIPTSDIR/Refresh.sh"
  sleep 0.3
}

# Apply Video Wallpaper
apply_video_wallpaper() {
  local video_path="$1"
  [[ -z "$video_path" ]] && return 1
  local mon="${target_monitor:-${focused_monitor:-$(hyprctl monitors -j | jq -r '.[] | select(.focused == true) .name' 2>/dev/null || echo "DP-1")}}"
  echo "video" > "$HOME/.cache/Rofi-Wallpaper-Engine/Wallpaper-mode.txt"

  # Kill WPE instances on this monitor
  while IFS= read -r pid; do
    [[ -n "$pid" ]] && kill -9 "$pid" 2>/dev/null || true
  done < <(pgrep -f "linux-wallpaperengine.*--screen-root[[:space:]]+${mon}" 2>/dev/null)

  kill_wallpaper_for_video

  # Check if mpvpaper is installed
  if ! command -v mpvpaper &>/dev/null; then
    notify-send -i "$iDIR/error.png" "E-R-R-O-R" "mpvpaper not found"
    return 1
  fi

  # Apply video wallpaper only to the focused monitor
  mpvpaper "$focused_monitor" -o "load-scripts=no no-audio --loop" "$video_path" &
}

# Apply Linux-WallpaperEngine Wallpaper
apply_wpengine_wallpaper() {
  local scene_path="$1"
  [[ -z "$scene_path" ]] && return 1
  local mon="${target_monitor:-${focused_monitor:-$(hyprctl monitors -j | jq -r '.[] | select(.focused == true) .name' 2>/dev/null || echo "DP-1")}}"
  local item_id="${scene_path#*/431960/}"
  item_id="${item_id%%/*}"
  [[ -z "$item_id" ]] && return 1
  local wp_item_dir="${scene_path%/*}"
  [[ ! -f "$wp_item_dir/project.json" && ! -f "$wp_item_dir/scene.json" ]] && wp_item_dir="${wp_item_dir%/*}"
  echo "live" > "$HOME/.cache/Rofi-Wallpaper-Engine/Wallpaper-mode.txt"

  (
    if declare -f wallpaper_ensure_daemon >/dev/null; then
      wallpaper_ensure_daemon
    elif ! pgrep -x "$WWW_CMD" >/dev/null; then
      "$WWW_CMD" daemon &
      sleep 0.5
    fi
    # Create .cache files for transitions
    local assets="${wpengine_assets:-$HOME/.local/share/Steam/steamapps/common/wallpaper_engine/assets}"
    local trans_dir="$HOME/.cache/Rofi-Wallpaper-Engine/WE_Transitions/${mon}"
    mkdir -p "$trans_dir" "$HOME/.cache/Rofi-Wallpaper-Engine/WE_Fullres" 2>/dev/null || true
    local source_still="$trans_dir/source.png"
    local target_still="$trans_dir/target.png"
    local current_still="$trans_dir/current.png"

    # Check for a previously saved still
    rm -f "$source_still" 2>/dev/null || true
    if [[ -f "$current_still" ]]; then
      cp -f "$current_still" "$source_still"
    else
      local cur_file="${per_monitor_wallpaper_current:-$HOME/.config/hypr/wallpaper_effects/.wallpaper_current_${mon}}"
      [[ -f "$cur_file" ]] && cp -f "$cur_file" "$source_still"
    fi

    if [[ ! -f "$source_still" || ! -s "$source_still" ]]; then
      for candidate in "$per_monitor_wallpaper_base" "$CURRENT_MON_PIC_PATH" "$HOME/.config/hypr/rofi/.current_wallpaper_${mon}"; do
        [[ -n "$candidate" && -f "$candidate" ]] && cp -f "$candidate" "$source_still" && break
      done
    fi

    # Render selected wallpaper on headless WPE-Capture to capture a still
    local unique_stamp=$(date +%s%N)
    local target_still="$trans_dir/target_${unique_stamp}.png"
    local final_target="$trans_dir/target.png"
    local target_ref="$wp_item_dir"
    [[ ! -d "$wp_item_dir" ]] && target_ref="$item_id"
    # Clean up old target files
    rm -f "$trans_dir"/target_*.png "$HOME/.cache/Rofi-Wallpaper-Engine/WE_Fullres/${item_id}_snapshot.png" 2>/dev/null || true

    # Ensure WPE-Capture monitor exists, matching the focused monitor's resolution and refresh rate
    if ! hyprctl monitors -j | jq -e '.[] | select(.name == "WPE-Capture")' >/dev/null 2>&1; then
      local mon_info
      mon_info=$(hyprctl monitors -j | jq -r --arg mon "$mon" '.[] | select(.name == $mon) | "\(.width)x\(.height)@\(.refresh)"')
      
      hyprctl output create headless WPE-Capture --quiet >/dev/null 2>&1 || hyprctl output create headless --quiet >/dev/null 2>&1
      hyprctl keyword monitor "WPE-Capture, ${mon_info:-1920x1080@60}, auto, 1" >/dev/null 2>&1
      sleep 0.4
    fi

    linux-wallpaperengine --silent --no-automute --assets-dir "$assets" --screen-root "WPE-Capture" "$target_ref" >/dev/null 2>&1 &
    pkill -x waybar >/dev/null 2>&1 || true
    local new_wpe_pid=$!
    # Give WPE enough time to frame-render on the headless output
    sleep 0.8

    if command -v grim &>/dev/null; then
      grim -o "WPE-Capture" -t png "$target_still" >/dev/null 2>&1 || true
    fi

    # Fallback if grim didn't capture properly
    if [[ ! -f "$target_still" || ! -s "$target_still" ]]; then
      for ext in png jpg jpeg PNG JPG JPEG; do
        if [[ -f "$wp_item_dir/background.$ext" ]]; then
          cp -f "$wp_item_dir/background.$ext" "$target_still"
          break
        fi
      done
    fi

    # If still nothing, fallback the preview image
    if [[ ! -f "$target_still" || ! -s "$target_still" ]]; then
      local found_preview=$(find "$wp_item_dir" -maxdepth 2 -type f \( -iname "preview.jpg" -o -iname "preview.png" \) -print -quit 2>/dev/null)
      [[ -n "$found_preview" ]] && cp -f "$found_preview" "$target_still"
    fi

    # Link/copy to standard target path for swww
    cp -f "$target_still" "$final_target"
    cp -f "$final_target" "$HOME/.cache/Rofi-Wallpaper-Engine/WE_Fullres/${item_id}_snapshot.png" 2>/dev/null || true

    kill -TERM "$new_wpe_pid" >/dev/null 2>&1 || true
    sleep 0.1
    kill -9 "$new_wpe_pid" >/dev/null 2>&1 || true
    pkill

    # Terminate the old monitor's wallpaper engine instance securely
    while IFS= read -r pid; do
      [[ -n "$pid" ]] && kill -TERM "$pid" 2>/dev/null || true
    done < <(pgrep -f "linux-wallpaperengine.*(${mon}|--screen-root[[:space:]]+${mon})" 2>/dev/null)
    sleep 0.1
    while IFS= read -r pid; do
      [[ -n "$pid" ]] && kill -9 "$pid" 2>/dev/null || true
    done < <(pgrep -f "linux-wallpaperengine.*(${mon}|--screen-root[[:space:]]+${mon})" 2>/dev/null)

    # SWWW transition from source.png to target.png
    if [[ -f "$source_still" && -f "$final_target" ]]; then
      local resize_mode="fit"
      if declare -f wallpaper_resize_mode >/dev/null; then
        resize_mode="$(wallpaper_resize_mode "$target_still" "$mon" 2>/dev/null || echo "fit")"
      fi

      "$WWW_CMD" img -o "$mon" --resize "$resize_mode" "$source_still" &>/dev/null
      sleep 0.05
      "$WWW_CMD" img -o "$mon" --resize "$resize_mode" "$target_still" "${SWWW_PARAMS[@]}" &>/dev/null

      [[ -x "$SCRIPTSDIR/WallustSwww.sh" ]] && "$SCRIPTSDIR/WallustSwww.sh" "$target_still" &>/dev/null || true
      [[ -x "$SCRIPTSDIR/Refresh.sh" ]] && "$SCRIPTSDIR/Refresh.sh" &>/dev/null || true
      # Timings are as tight as I could get them to match 
      # Wallpaper engine start with SWWW trasition end
      sleep 0.28
    fi

    hyprctl output remove WPE-Capture >/dev/null 2>&1 || true

    # Save target as the new current.png for the next use.
    cp -f "$target_still" "$current_still"
    local cur_link="${per_monitor_wallpaper_link:-$HOME/.config/hypr/rofi/.current_wallpaper_${mon}}"
    local cur_file="${per_monitor_wallpaper_current:-$HOME/.config/hypr/wallpaper_effects/.wallpaper_current_${mon}}"
    mkdir -p "$(dirname "$cur_file")" "$(dirname "$cur_link")" 2>/dev/null || true
    ln -sf "$current_still" "$cur_link" 2>/dev/null || true
    cp -f "$current_still" "$cur_file" 2>/dev/null || true
    echo "$item_id" > "$HOME/.cache/Rofi-Wallpaper-Engine/current_wallpaper_${mon}" 2>/dev/null || true

    # Start the new wallpaper engine instance strictly on the focused monitor
    linux-wallpaperengine --silent --no-automute --no-audio --assets-dir "$assets" --screen-root "$mon" "$target_ref" >/dev/null 2>&1 &
  ) &>/dev/null &
}

# Main function
main() {
  "${XDG_CONFIG_HOME:-$HOME/.config}/hypr/scripts/RofiFocusedWallpaperLink.sh" >/dev/null 2>&1 || true
  choice=$(menu | $rofi_command)
  choice=$(echo "$choice" | xargs)
  RANDOM_PIC_NAME=$(echo "$RANDOM_PIC_NAME" | xargs)
  raw_choice="$choice"
  choice="${choice#Random: }"
  choice="${choice#Current: }"

  if [[ -z "$choice" ]]; then
    echo "No choice selected. Exiting."
    exit 0
  fi

  # Resolve selection directly when using Random/Current entries
  if [[ "$raw_choice" == Random:\ * ]]; then
    selected_file="$RANDOM_PIC"
  elif [[ "$raw_choice" == Current:\ * && -n "$CURRENT_MON_PIC_PATH" && -f "$CURRENT_MON_PIC_PATH" ]]; then
    selected_file="$CURRENT_MON_PIC_PATH"
  elif [[ -f "$choice" ]]; then
    selected_file="$choice"
  elif [[ "$choice" =~ ^WE_([0-9]+)_ ]]; then
    extracted_id="${BASH_REMATCH[1]}"
    for pic in "${PICS[@]}"; do
      if [[ "$pic" == *"/431960/$extracted_id/"* ]]; then
        selected_file="$pic"
        break
      fi
    done
  else
    # Handle random selection by name when needed
    if [[ "$choice" == "$RANDOM_PIC_NAME" ]]; then
      choice=$(basename "$RANDOM_PIC")
    fi
    choice_basename=$(basename "$choice" | sed 's/\(.*\)\.[^.]*$/\1/')
    
    # Check wallDIR and steamDIR
    selected_file=$(find "$wallDIR" "$steamDIR" -iname "$choice_basename.*" -print -quit 2>/dev/null)
  fi

  if [[ -z "$selected_file" ]]; then
    echo "File not found. Selected choice: $choice"
    exit 1
  fi

  # **CHECK FIRST** if it's a video or an image **before calling any function**
  if [[ "$selected_file" =~ \.(mp4|mkv|mov|webm|MP4|MKV|MOV|WEBM)$ ]]; then
    apply_video_wallpaper "$selected_file"
  elif [[ "$selected_file" =~ scene\.pkg$ || "$selected_file" == *"/431960/"* ]]; then
    apply_wpengine_wallpaper "$selected_file"
  else
    apply_image_wallpaper "$selected_file"
  fi
}

# Check if rofi is already running
if pidof rofi >/dev/null; then
  pkill rofi
fi

main
