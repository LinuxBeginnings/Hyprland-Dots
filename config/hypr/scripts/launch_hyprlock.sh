#!/usr/bin/env bash

GEN_CONFIG="$HOME/.config/hypr/hyprlock_generated.conf"
BASE_CONFIG="$HOME/.config/hypr/hyprlock.conf"

# Start with base labels, input fields, and colors
cp "$BASE_CONFIG" "$GEN_CONFIG"

# Query active monitors via hyprctl
monitors=$(hyprctl monitors -j | jq -r '.[].name')

# Desktop Wallpaper Fallback Targets from WallpaperSelect.sh
DESKTOP_ROFI_LINK="${XDG_CONFIG_HOME:-$HOME/.config}/rofi/.current_wallpaper"
DESKTOP_WALL_CURRENT="${XDG_CONFIG_HOME:-$HOME/.config}/hypr/wallpaper_effects/.wallpaper_current"

for mon in $monitors; do
  wall="${XDG_CONFIG_HOME:-$HOME/.config}/rofi/.current_lockscreen_${mon}"

  # Fallback 1: Per-monitor desktop wallpaper link
  if [ ! -f "$wall" ]; then
    wall="${XDG_CONFIG_HOME:-$HOME/.config}/rofi/.current_wallpaper_${mon}"
  fi

  # Fallback 2: Global lockscreen file
  if [ ! -f "$wall" ]; then
    wall="${XDG_CONFIG_HOME:-$HOME/.config}/rofi/.current_lockscreen"
  fi

  # Fallback 3: Standard desktop rofi link (~/.config/rofi/.current_wallpaper)
  if [ ! -f "$wall" ] && [ -f "$DESKTOP_ROFI_LINK" ]; then
    wall="$DESKTOP_ROFI_LINK"
  fi

  # Fallback 4: Standard desktop effect file (~/.config/hypr/wallpaper_effects/.wallpaper_current)
  if [ ! -f "$wall" ] && [ -f "$DESKTOP_WALL_CURRENT" ]; then
    wall="$DESKTOP_WALL_CURRENT"
  fi

  cat <<EOF >>"$GEN_CONFIG"

# --- Monitor: $mon ---
background {
    # NOTE: use only 1 path
	  #path = screenshot   # screenshot of your desktop
	  #path = $HOME/.config/hypr/wallpaper_effects/.wallpaper_modified # by wallpaper effects
    # path = $HOME/.config/hypr/wallpaper_effects/.wallpaper_current # current wallpaper
    
    monitor = $mon
    path = $wall
    color = rgb(0,0,0) # color will be rendered initially until path is available

    # all these options are taken from hyprland, see https://wiki.hyprland.org/Configuring/Variables/#blur for explanations
    blur_size = 3
    blur_passes = 2 # 0 disables blurring
    noise = 0.0117
    contrast = 1.3000 # Vibrant!!!
    brightness = 0.8000
    vibrancy = 0.2100
    vibrancy_darkness = 0.0
}

# image {
#     monitor = $mon
#     path = $wall
#     size = 240
#     rounding = -1
#     border_size = 4
#     border_color = \$color12
#     rotate = 0
#     reload_time = -1
#     position = 10, 200
#     halign = center
#     valign = center
#}
EOF
done

# Launch hyprlock with the dynamically compiled config
hyprlock --config "$GEN_CONFIG"
