#!/usr/bin/env bash
# ==================================================
#  KoolDots (2026)
#  Project URL: https://github.com/LinuxBeginnings
#  License: GNU GPLv3
#  SPDX-License-Identifier: GPL-3.0-or-later
# ==================================================
# Wallpaper Effects using ImageMagick (SUPER SHIFT W)

# Variables
terminal=kitty
wallpaper_current="${XDG_CONFIG_HOME:-$HOME/.config}/hypr/wallpaper_effects/.wallpaper_current"
wallpaper_output="${XDG_CONFIG_HOME:-$HOME/.config}/hypr/wallpaper_effects/.wallpaper_modified"
wallpaper_base="${XDG_CONFIG_HOME:-$HOME/.config}/hypr/wallpaper_effects/.wallpaper_base"
wallpaper_link="${XDG_CONFIG_HOME:-$HOME/.config}/rofi/.current_wallpaper"
SCRIPTSDIR="${XDG_CONFIG_HOME:-$HOME/.config}/hypr/scripts"
# shellcheck source=/dev/null
. "$SCRIPTSDIR/WallpaperCmd.sh"
focused_monitor=$(hyprctl monitors -j | jq -r '.[] | select(.focused) | .name')
per_monitor_wallpaper_base="${XDG_CONFIG_HOME:-$HOME/.config}/hypr/wallpaper_effects/.wallpaper_base_${focused_monitor}"
per_monitor_wallpaper_current="${XDG_CONFIG_HOME:-$HOME/.config}/hypr/wallpaper_effects/.wallpaper_current_${focused_monitor}"
per_monitor_wallpaper_link="${XDG_CONFIG_HOME:-$HOME/.config}/rofi/.current_wallpaper_${focused_monitor}"
rofi_theme="${XDG_CONFIG_HOME:-$HOME/.config}/rofi/config-wallpaper-effect.rasi"

# Directory for swaync
iDIR="${XDG_CONFIG_HOME:-$HOME/.config}/swaync/images"
iDIRi="${XDG_CONFIG_HOME:-$HOME/.config}/swaync/icons"

# swww/awww transition config
FPS=60
TYPE="wipe"
DURATION=2
BEZIER=".43,1.19,1,.4"
if [[ "$WWW_CMD" == "swww" || "$WWW_CMD" == "awww" ]]; then
    SWWW_PARAMS=(--transition-fps "$FPS" --transition-type "$TYPE" --transition-duration "$DURATION" --transition-bezier "$BEZIER")
else
    SWWW_PARAMS=()
fi

# Define ImageMagick effects
declare -A effects=(
    ["No Effects"]="no-effects"
    ["Black & White"]="magick $wallpaper_base -colorspace gray -sigmoidal-contrast 10,40% $wallpaper_output"
    ["Blurred"]="magick $wallpaper_base -blur 0x10 $wallpaper_output"
    ["Charcoal"]="magick $wallpaper_base -charcoal 0x5 $wallpaper_output"
    ["Edge Detect"]="magick $wallpaper_base -edge 1 $wallpaper_output"
    ["Emboss"]="magick $wallpaper_base -emboss 0x5 $wallpaper_output"
    ["Frame Raised"]="magick $wallpaper_base +raise 150 $wallpaper_output"
    ["Frame Sunk"]="magick $wallpaper_base -raise 150 $wallpaper_output"
    ["Negate"]="magick $wallpaper_base -negate $wallpaper_output"
    ["Oil Paint"]="magick $wallpaper_base -paint 4 $wallpaper_output"
    ["Posterize"]="magick $wallpaper_base -posterize 4 $wallpaper_output"
    ["Polaroid"]="magick $wallpaper_base -polaroid 0 $wallpaper_output"
    ["Sepia Tone"]="magick $wallpaper_base -sepia-tone 65% $wallpaper_output"
    ["Solarize"]="magick $wallpaper_base -solarize 80% $wallpaper_output"
    ["Sharpen"]="magick $wallpaper_base -sharpen 0x5 $wallpaper_output"
    ["Vignette"]="magick $wallpaper_base -vignette 0x3 $wallpaper_output"
    ["Vignette-black"]="magick $wallpaper_base -background black -vignette 0x3 $wallpaper_output"
    ["Zoomed"]="magick $wallpaper_base -gravity Center -extent 1:1 $wallpaper_output"
)
persist_wallpaper_state() {
    local source_wallpaper="$1"
    [ -n "$source_wallpaper" ] && [ -f "$source_wallpaper" ] || return 0

    mkdir -p "$(dirname "$wallpaper_current")" "$(dirname "$wallpaper_link")"
    cp -f "$source_wallpaper" "$wallpaper_current" || true
    ln -sf "$source_wallpaper" "$wallpaper_link" || true

    if [[ -n "$focused_monitor" ]]; then
        cp -f "$source_wallpaper" "$per_monitor_wallpaper_current" || true
        ln -sf "$source_wallpaper" "$per_monitor_wallpaper_link" || true
    fi
}

# Function to apply no effects
no-effects() {
    local resize_mode
    resize_mode="$(wallpaper_resize_mode "$wallpaper_base" "$focused_monitor")"
    "$WWW_CMD" img -o "$focused_monitor" --resize "$resize_mode" "$wallpaper_base" "${SWWW_PARAMS[@]}" || return 1
    persist_wallpaper_state "$wallpaper_base"

    notify-send -u low -i "$iDIR/ja.png" "No wallpaper" "effects applied"
    # copying wallpaper for rofi menu
    cp "$wallpaper_base" "$wallpaper_output"
}

# Function to run rofi menu
main() {
    # Populate rofi menu options
    options=("No Effects")
    for effect in "${!effects[@]}"; do
        [[ "$effect" != "No Effects" ]] && options+=("$effect")
    done

    "${XDG_CONFIG_HOME:-$HOME/.config}/hypr/scripts/RofiFocusedWallpaperLink.sh" >/dev/null 2>&1 || true
    choice=$(printf "%s\n" "${options[@]}" | LC_COLLATE=C sort | rofi -dmenu -i -config $rofi_theme)

    # Process user choice
    if [[ -n "$choice" ]]; then
        if [[ -f "$per_monitor_wallpaper_base" ]]; then
            wallpaper_base="$per_monitor_wallpaper_base"
        fi
        if [[ ! -f "$wallpaper_base" ]]; then
            mkdir -p "$(dirname "$wallpaper_base")"
            cp -f "$wallpaper_current" "$wallpaper_base" || true
        fi
        if [[ "$choice" == "No Effects" ]]; then
            no-effects
        elif [[ "${effects[$choice]+exists}" ]]; then
            # Apply selected effect
            notify-send -u normal -i "$iDIR/ja.png"  "Applying:" "$choice effects"
            if ! eval "${effects[$choice]}"; then
                notify-send -u critical -i "$iDIR/error.png" "Wallpaper effect failed" "$choice could not be applied"
                return 1
            fi

            # intial kill process
            for pid in swaybg mpvpaper; do
            killall -SIGUSR1 "$pid" 2>/dev/null || true
            done

            sleep 1
            local resize_mode
            resize_mode="$(wallpaper_resize_mode "$wallpaper_output" "$focused_monitor")"
            "$WWW_CMD" img -o "$focused_monitor" --resize "$resize_mode" "$wallpaper_output" "${SWWW_PARAMS[@]}"
            persist_wallpaper_state "$wallpaper_output"
            notify-send -u low -i "$iDIR/ja.png" "$choice" "effects applied"
        else
            echo "Effect '$choice' not recognized."
        fi
    fi
}

# Check if rofi is already running and kill it
if pidof rofi > /dev/null; then
    pkill rofi
fi

main

sleep 1
