#!/usr/bin/env bash
# ==================================================
#  KoolDots (2026)
#  Project URL: https://github.com/LinuxBeginnings
#  License: GNU GPLv3
#  SPDX-License-Identifier: GPL-3.0-or-later
# ==================================================
# Wallust: derive colors from the current wallpaper and update templates
# Usage: WallustSwww.sh [absolute_path_to_wallpaper]

set -euo pipefail
# Wallust v3/v4 compatibility
wallust_args=()
wallust_kitty_args=()
# shellcheck source=/dev/null
if [ -f "$HOME/.config/hypr/scripts/WallustConfig.sh" ]; then
  . "$HOME/.config/hypr/scripts/WallustConfig.sh"
fi
have_notify() { command -v notify-send >/dev/null 2>&1; }
wallust_log="${XDG_CACHE_HOME:-$HOME/.cache}/wallust/wallust-swww.log"
mkdir -p "$(dirname "$wallust_log")"
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

# Inputs and paths
passed_path="${1:-}"
if command -v awww >/dev/null 2>&1; then
  WWW="awww"
  cache_dir="$HOME/.cache/awww/"
  cache_dir_fallback="$HOME/.cache/swww/"
else
  WWW="swww"
  cache_dir="$HOME/.cache/swww/"
  cache_dir_fallback="$HOME/.cache/awww/"
fi
rofi_link="$HOME/.config/rofi/.current_wallpaper"
wallpaper_current="$HOME/.config/hypr/wallpaper_effects/.wallpaper_current"
read_cached_wallpaper() {
  local cache_file="$1"
  if [[ -f "$cache_file" ]]; then
    awk 'NF && $0 !~ /^filter/ {print; exit}' "$cache_file"
  fi
}

read_wallpaper_from_query() {
  local monitor="$1"
  $WWW query | awk -v mon="$monitor" '
    /^Monitor/ {
      cur=$2
      gsub(":", "", cur)
    }
    /image:/ && cur==mon {
      sub(/^.*image: /,"")
      print
      exit
    }
  '
}

# Helper: get focused monitor name (prefer JSON)
get_focused_monitor() {
  if command -v jq >/dev/null 2>&1; then
    hyprctl monitors -j | jq -r '.[] | select(.focused) | .name'
  else
    hyprctl monitors | awk '/^Monitor/{name=$2} /focused: yes/{print name}'
  fi
}

# Determine wallpaper_path
wallpaper_path=""
if [[ -n "$passed_path" && -f "$passed_path" ]]; then
  wallpaper_path="$passed_path"
else
  # Try to read from awww/swww cache for the focused monitor, with a short retry loop
  current_monitor="$(get_focused_monitor)"
  cache_file="$cache_dir$current_monitor"
  alt_cache_file="${cache_dir_fallback}${current_monitor}"

  # Wait briefly for awww/swww to write its cache after an image change
  for i in {1..10}; do
    if [[ -f "$cache_file" || -f "$alt_cache_file" ]]; then
      break
    fi
    sleep 0.1
  done
  if [[ ! -f "$cache_file" && -f "$alt_cache_file" ]]; then
    cache_file="$alt_cache_file"
  fi

  if [[ -f "$cache_file" ]]; then
    # The first non-filter line is the original wallpaper path
    wallpaper_path="$(read_cached_wallpaper "$cache_file")"
  fi

  if [[ -z "$wallpaper_path" ]]; then
    wallpaper_path="$(read_wallpaper_from_query "$current_monitor")"
  fi
fi

if [[ -z "${wallpaper_path:-}" || ! -f "$wallpaper_path" ]]; then
  # Nothing to do; avoid failing loudly so callers can continue
  exit 0
fi

# Update helpers that depend on the path
ln -sf "$wallpaper_path" "$rofi_link" || true
mkdir -p "$(dirname "$wallpaper_current")"
cp -f "$wallpaper_path" "$wallpaper_current" || true

# Ensure Ghostty directory exists so Wallust can write target even if Ghostty isn't installed
mkdir -p "$HOME/.config/ghostty" || true
wait_for_templates() {
  local start_ts="$1"
  shift
  local files=("$@")
  for _ in {1..50}; do
    local ready=true
    for file in "${files[@]}"; do
      if [[ ! -s "$file" ]]; then
        ready=false
        break
      fi
      local mtime
      mtime=$(stat -c %Y "$file" 2>/dev/null || echo 0)
      if (( mtime < start_ts )); then
        ready=false
        break
      fi
    done
    $ready && return 0
    sleep 0.1
  done
  return 1
}

# Run wallust (silent) to regenerate templates defined in ~/.config/wallust/wallust.toml
# -s is used in this repo to keep things quiet and avoid extra prompts
start_ts=$(date +%s)
if ! wallust "${wallust_args[@]}" run -s "$wallpaper_path" >"$wallust_log" 2>&1; then
  have_notify && notify-send -u critical -a WallustSwww \
    "Wallust failed" "See: $wallust_log"
  exit 1
fi
wallust_targets=(
  "$HOME/.config/waybar/wallust/colors-waybar.css"
  "$HOME/.config/rofi/wallust/colors-rofi.rasi"
  "$HOME/.config/hypr/wallust/wallust-hyprland.conf"
)
if ! wait_for_templates "$start_ts" "${wallust_targets[@]}"; then
  have_notify && notify-send -u critical -a WallustSwww \
    "Wallust templates not updated" "See: $wallust_log"
  exit 1
fi
ensure_wallust_waybar_style
reload_running_cava_colors

# Normalize Rofi selection colors to a brighter accent and readable foreground
rofi_colors="$HOME/.config/rofi/wallust/colors-rofi.rasi"
if [ -f "$rofi_colors" ]; then
  accent_hex=$(sed -n 's/^\s*color13:\s*\(#[0-9A-Fa-f]\{6\}\).*/\1/p' "$rofi_colors" | head -n1)
  [ -z "$accent_hex" ] && accent_hex=$(sed -n 's/^\s*color12:\s*\(#[0-9A-Fa-f]\{6\}\).*/\1/p' "$rofi_colors" | head -n1)
  fg_hex=$(sed -n 's/^\s*foreground:\s*\(#[0-9A-Fa-f]\{6\}\).*/\1/p' "$rofi_colors" | head -n1)
  if [ -n "$accent_hex" ]; then
    sed -i -E "s|^(\s*selected-normal-background:\s*).*$|\1$accent_hex;|" "$rofi_colors"
    sed -i -E "s|^(\s*selected-active-background:\s*).*$|\1$accent_hex;|" "$rofi_colors"
    sed -i -E "s|^(\s*selected-urgent-background:\s*).*$|\1$accent_hex;|" "$rofi_colors"
  fi
  if [ -n "$fg_hex" ]; then
    sed -i -E "s|^(\s*selected-normal-foreground:\s*).*$|\1$fg_hex;|" "$rofi_colors"
    sed -i -E "s|^(\s*selected-active-foreground:\s*).*$|\1$fg_hex;|" "$rofi_colors"
    sed -i -E "s|^(\s*selected-urgent-foreground:\s*).*$|\1$fg_hex;|" "$rofi_colors"
  fi
fi

# Run kitty-only wallust config to keep terminal palette separate
run_wallust_with_config() {
  local cfg="$1"
  # Wallust v4: prefer config-file flag via WallustConfig.sh
  if [ "${#wallust_kitty_args[@]}" -gt 0 ]; then
    wallust "${wallust_kitty_args[@]}" run -s "$wallpaper_path" || true
    return
  fi
  # Wallust v3+: prefer config-file flag when available.
  # NOTE: Do not use -c here; on wallust 3.x it means colorspace, not config file.
  if wallust run --help 2>&1 | grep -q -E -- '(^|[[:space:]])-C([,[:space:]]|$)|--config-file'; then
    wallust run -s -C "$cfg" "$wallpaper_path" || true
    return
  fi
  # Legacy fallback for builds that still honor env-based config override.
  WALLUST_CONFIG="$cfg" wallust run -s "$wallpaper_path" || true
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

apply_hypr_gap_fallback() {
  local decorations_lua="$HOME/.config/hypr/UserConfigs/user_decorations.lua"
  [ -s "$decorations_lua" ] || return 0
  local gaps_in gaps_out border_size
  gaps_in="$(sed -n 's/^[[:space:]]*gaps_in[[:space:]]*=[[:space:]]*\([0-9]\+\).*/\1/p' "$decorations_lua" | head -n1)"
  gaps_out="$(sed -n 's/^[[:space:]]*gaps_out[[:space:]]*=[[:space:]]*\([0-9]\+\).*/\1/p' "$decorations_lua" | head -n1)"
  border_size="$(sed -n 's/^[[:space:]]*border_size[[:space:]]*=[[:space:]]*\([0-9]\+\).*/\1/p' "$decorations_lua" | head -n1)"

  [ -n "$gaps_in" ] && hyprctl keyword general:gaps_in "$gaps_in" >/dev/null 2>&1 || true
  [ -n "$gaps_out" ] && hyprctl keyword general:gaps_out "$gaps_out" >/dev/null 2>&1 || true
  [ -n "$border_size" ] && hyprctl keyword general:border_size "$border_size" >/dev/null 2>&1 || true
}

# Apply Hyprland updates immediately to avoid delayed border/gap changes.
reload_hypr_preserve_layout

kitty_cfg="$HOME/.config/wallust/wallust-kitty.toml"
if [ "${#wallust_kitty_args[@]}" -gt 0 ]; then
  kitty_cfg="$HOME/.config/wallust/wallust-kitty-v4.toml"
fi
(
  if [ -f "$kitty_cfg" ]; then
    run_wallust_with_config "$kitty_cfg"
  fi

  # Reload kitty colors when wallpaper-based theme is active.
  # Use SIGUSR1 directly to avoid extra latency from kitty remote-control calls.
  kitty_wallust_theme="$HOME/.config/kitty/kitty-themes/01-Wallust.conf"
  if [ -s "$kitty_wallust_theme" ]; then
    if pidof kitty >/dev/null 2>&1; then
      for pid in $(pidof kitty); do
        kill -SIGUSR1 "$pid" 2>/dev/null || true
      done
    fi
  fi

  # Normalize Ghostty palette syntax in case ':' was used by older files
  if [ -f "$HOME/.config/ghostty/wallust.conf" ]; then
    sed -i -E 's/^(\s*palette\s*=\s*)([0-9]{1,2}):/\1\2=/' "$HOME/.config/ghostty/wallust.conf" 2>/dev/null || true
  fi

  # Light wait for Ghostty colors file to be present then signal Ghostty to reload (SIGUSR2)
  for _ in 1 2 3; do
    [ -s "$HOME/.config/ghostty/wallust.conf" ] && break
    sleep 0.1
  done
  if pidof ghostty >/dev/null; then
    for pid in $(pidof ghostty); do kill -SIGUSR2 "$pid" 2>/dev/null || true; done
  fi
  # Hyprland reload/keyword updates are applied above to avoid delayed color/gap updates.
) >/dev/null 2>&1 &
