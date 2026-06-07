#!/usr/bin/env bash
# ==================================================
#  KoolDots (2026)
#  Project URL: https://github.com/LinuxBeginnings
#  License: GNU GPLv3
#  SPDX-License-Identifier: GPL-3.0-or-later
# ==================================================
set -euo pipefail
# Wallust v3/v4 compatibility
wallust_args=()
# shellcheck source=/dev/null
if [ -f "$HOME/.config/hypr/scripts/WallustConfig.sh" ]; then
  . "$HOME/.config/hypr/scripts/WallustConfig.sh"
fi

# SPDX-FileCopyrightText: 2025-present Ahum Maitra theahummaitra@gmail.com
#
# SPDX-License-Identifier: 	GPL-3.0-or-later

# Repository url : https://github.com/TheAhumMaitra/cautious-waddle

require() {
  command -v "$1" >/dev/null 2>&1 || {
    printf '%s\n' "Missing dependency: $1" >&2
    exit 127
  }
}

require wallust
require rofi

# notify-send is optional
have_notify() { command -v notify-send >/dev/null 2>&1; }
capture_current_layout() {
  if command -v jq >/dev/null 2>&1; then
    hyprctl -j getoption general:layout 2>/dev/null | jq -r '.str // empty'
  else
    hyprctl getoption general:layout 2>/dev/null | awk 'NR==1 {print $2}'
  fi
}
restore_layout_after_reload() {
  local layout="$1"
  [ -n "$layout" ] || return 0

  if [ -x "$HOME/.config/hypr/scripts/ChangeLayout.sh" ]; then
    if "$HOME/.config/hypr/scripts/ChangeLayout.sh" --no-notify "$layout" >/dev/null 2>&1; then
      return 0
    fi
  fi

  hyprctl keyword general:layout "$layout" >/dev/null 2>&1 || true
}
reload_hypr_preserve_layout() {
  command -v hyprctl >/dev/null 2>&1 || return 0

  local active_layout
  active_layout="$(capture_current_layout || true)"

  hyprctl reload config-only >/dev/null 2>&1 || true
  sleep 0.1
  restore_layout_after_reload "$active_layout"
}
# Cache theme list to avoid slow re-enumeration on every invocation
cache_dir="${XDG_CACHE_HOME:-$HOME/.cache}"
theme_cache="${cache_dir}/wallust_theme_list.txt"
cache_max_age=86400 # seconds

build_theme_list() {
  wallust "${wallust_args[@]}" theme list \
    | awk '/^- /{sub(/^- /,""); sub(/ \(.*/, ""); print}'
}

update_theme_cache() {
  mkdir -p "$cache_dir"
  local tmp
  tmp="$(mktemp "${cache_dir}/wallust-theme-list.XXXXXX")"
  if build_theme_list > "$tmp"; then
    if [ -s "$tmp" ]; then
      mv "$tmp" "$theme_cache"
      return 0
    fi
  fi
  rm -f "$tmp"
  return 1
}

cache_mtime=$(stat -c %Y "$theme_cache" 2>/dev/null || echo 0)
cache_age=$(( $(date +%s) - cache_mtime ))
if [ ! -s "$theme_cache" ] || [ "$cache_age" -gt "$cache_max_age" ]; then
  update_theme_cache || true
fi

ensure_wallust_waybar_style() {
  local waybar_style="$HOME/.config/waybar/style.css"
  local colors_file="$HOME/.config/waybar/wallust/colors-waybar.css"
  local styles_dir="$HOME/.config/waybar/style"
  [ -f "$colors_file" ] || return 0
  if [ -f "$waybar_style" ] && grep -q 'colors-waybar.css' "$waybar_style"; then
    return 0
  fi
  local candidates=(
    "Wallust-Chroma-Fusion.css"
    "Wallust-ML4W-modern.css"
    "Wallust-Colored.css"
    "Wallust-Box-type.css"
    "Wallust-Simple.css"
  )
  for candidate in "${candidates[@]}"; do
    if [ -f "$styles_dir/$candidate" ]; then
      ln -sf "$styles_dir/$candidate" "$waybar_style"
      break
    fi
  done
}
reload_running_cava_colors() {
  # CAVA supports SIGUSR2 to reload colors without full audio reinitialization.
  if pgrep -x cava >/dev/null 2>&1; then
    pkill -USR2 -x cava >/dev/null 2>&1 || true
  fi
}

wallust_hypr_colors="$HOME/.config/hypr/wallust/wallust-hyprland.conf"
extract_wallust_hex() {
  local key="$1"
  awk -v key="$key" '
    $1 == "$" key && $2 == "=" {
      if (match($3, /^rgb\(([0-9A-Fa-f]{6})\)$/, m)) {
        print toupper(m[1])
        exit
      }
    }
  ' "$wallust_hypr_colors"
}

apply_hypr_border_fallback() {
  [ -s "$wallust_hypr_colors" ] || return 0
  local color12 color10 color15 color0
  color12="$(extract_wallust_hex color12)"
  color10="$(extract_wallust_hex color10)"
  color15="$(extract_wallust_hex color15)"
  color0="$(extract_wallust_hex color0)"

  [ -n "$color12" ] && hyprctl keyword general:col.active_border "rgb($color12)" >/dev/null 2>&1 || true
  [ -n "$color10" ] && hyprctl keyword general:col.inactive_border "rgb($color10)" >/dev/null 2>&1 || true
  [ -n "$color12" ] && hyprctl keyword decoration:shadow:color "rgb($color12)" >/dev/null 2>&1 || true
  [ -n "$color10" ] && hyprctl keyword decoration:shadow:color_inactive "rgb($color10)" >/dev/null 2>&1 || true
  [ -n "$color15" ] && hyprctl keyword group:col.border_active "rgb($color15)" >/dev/null 2>&1 || true
  [ -n "$color0" ] && hyprctl keyword group:groupbar:col.active "rgb($color0)" >/dev/null 2>&1 || true
}

# Prompt for theme; guard -e on cancel
set +e
if [ -s "$theme_cache" ]; then
  choice="$(rofi -dmenu -i -p 'Select Global Theme' < "$theme_cache")"
else
  choice="$(build_theme_list | rofi -dmenu -i -p 'Select Global Theme')"
fi
prompt_status=$?
set -e

# Exit cleanly on cancel or empty selection
if (( prompt_status != 0 )) || [[ -z "${choice}" ]]; then
  exit 0
fi

# Record time before applying so we can wait for fresh template outputs
start_ts=$(date +%s)
# Notify quickly so users get feedback immediately
have_notify && notify-send -a ThemeChanger \
  -h string:x-dunst-stack-tag:themechanger \
  "Applying theme" "Selected: ${choice}"

# Apply the theme and report result
wallust_log="${XDG_CACHE_HOME:-$HOME/.cache}/wallust/themechanger.log"
mkdir -p "$(dirname "$wallust_log")"
if wallust "${wallust_args[@]}" theme -- "${choice}" >"$wallust_log" 2>&1; then
  have_notify && notify-send -a ThemeChanger \
    -h string:x-dunst-stack-tag:themechanger \
    "Global theme changed" "Selected: ${choice}"

  # Wait until template targets exist, are newer than start_ts, and are stable (size/mtime stops changing)
  # Ensure Ghostty directory exists so Wallust can write target even if Ghostty isn't installed
  mkdir -p "$HOME/.config/ghostty" || true

  targets=(
    "$HOME/.config/waybar/wallust/colors-waybar.css"
    "$HOME/.config/rofi/wallust/colors-rofi.rasi"
    "$HOME/.config/hypr/wallust/wallust-hyprland.conf"
  )

  # Normalize Ghostty palette syntax in case upstream templates or older targets used ':'
  ghostty_conf="$HOME/.config/ghostty/wallust.conf"
  if [ -f "$ghostty_conf" ]; then
    sed -i -E 's/^(\s*palette\s*=\s*)([0-9]{1,2}):/\1\2=/' "$ghostty_conf" 2>/dev/null || true
  fi

  # Phase 1: appearance + freshness
  for _ in $(seq 1 100); do # up to ~10s
    ok=1
    for f in "${targets[@]}"; do
      [ -s "$f" ] || { ok=0; break; }
      mtime=$(stat -c %Y "$f" 2>/dev/null || echo 0)
      [ "$mtime" -ge "$start_ts" ] || { ok=0; break; }
    done
    [ $ok -eq 1 ] && break
    sleep 0.1
  done

  # Phase 2: stability (avoid reading half-written files)
  if [ $ok -eq 1 ]; then
    for _ in 1 2 3; do
      sizes_a=(); mtimes_a=()
      for f in "${targets[@]}"; do
        sizes_a+=("$(stat -c %s "$f" 2>/dev/null || echo 0)")
        mtimes_a+=("$(stat -c %Y "$f" 2>/dev/null || echo 0)")
      done
      sleep 0.15
      sizes_b=(); mtimes_b=()
      for f in "${targets[@]}"; do
        sizes_b+=("$(stat -c %s "$f" 2>/dev/null || echo 0)")
        mtimes_b+=("$(stat -c %Y "$f" 2>/dev/null || echo 0)")
      done
      if [ "${sizes_a[*]}" = "${sizes_b[*]}" ] && [ "${mtimes_a[*]}" = "${mtimes_b[*]}" ]; then
        break
      fi
    done
  else
    # As a safety net, wait a bit to avoid racing rofi reload against template writes
    sleep 0.5
  fi

  if [ "${ok:-0}" -ne 1 ]; then
    have_notify && notify-send -u critical -a ThemeChanger \
      -h string:x-dunst-stack-tag:themechanger \
      "Theme files not updated" "See: $wallust_log"
    exit 1
  fi

  # Small cushion before refresh to mirror wallpaper flow
  sleep 0.2
  # Normalize Rofi selection colors to use the palette's accent (color12)
  rofi_colors="$HOME/.config/rofi/wallust/colors-rofi.rasi"
  if [ -f "$rofi_colors" ]; then
    accent_hex=$(sed -n 's/^\s*color12:\s*\(#[0-9A-Fa-f]\{6\}\).*/\1/p' "$rofi_colors" | head -n1)
    [ -z "$accent_hex" ] && accent_hex=$(sed -n 's/^\s*color13:\s*\(#[0-9A-Fa-f]\{6\}\).*/\1/p' "$rofi_colors" | head -n1)
    if [ -n "$accent_hex" ]; then
      sed -i -E "s|^(\s*selected-normal-background:\s*).*$|\1$accent_hex;|" "$rofi_colors"
      sed -i -E "s|^(\s*selected-active-background:\s*).*$|\1$accent_hex;|" "$rofi_colors"
      sed -i -E "s|^(\s*selected-urgent-background:\s*).*$|\1$accent_hex;|" "$rofi_colors"
      sed -i -E "s|^(\s*selected-normal-foreground:\s*).*$|\1#000000;|" "$rofi_colors"
      sed -i -E "s|^(\s*selected-active-foreground:\s*).*$|\1#000000;|" "$rofi_colors"
      sed -i -E "s|^(\s*selected-urgent-foreground:\s*).*$|\1#000000;|" "$rofi_colors"
    fi
  fi

  reload_hypr_preserve_layout
  ensure_wallust_waybar_style
  reload_running_cava_colors

  # Refresh bars/menus after files are ready
  if [ -x "$HOME/.config/hypr/scripts/Refresh.sh" ]; then
    "$HOME/.config/hypr/scripts/Refresh.sh" >/dev/null 2>&1 || true
  else
    if command -v waybar-msg >/dev/null 2>&1; then
      waybar-msg cmd reload >/dev/null 2>&1 || true
    else
      pkill -SIGUSR2 waybar >/dev/null 2>&1 || true
    fi
  fi

  # Ask kitty to reload its config so the new 01-Wallust.conf is picked up
  if pidof kitty >/dev/null; then
    for pid in $(pidof kitty); do kill -SIGUSR1 "$pid" 2>/dev/null || true; done
  fi

  # Ask ghostty to reload its config so the updated wallust.conf is applied
  if pidof ghostty >/dev/null; then
    for pid in $(pidof ghostty); do kill -SIGUSR2 "$pid" 2>/dev/null || true; done
  fi
else
  have_notify && notify-send -u critical -a ThemeChanger \
    -h string:x-dunst-stack-tag:themechanger \
    "Failed to apply theme" "See: $wallust_log"
  exit 1
fi
