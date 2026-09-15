#!/usr/bin/env bash
# ==============================================================================
#  Rofi Wlogout Theme Switcher
#  Switch between presets: Sekiro, Silvia, Kurenai, Fuji
# ==============================================================================

# Toggle: close rofi if already open
if pidof rofi >/dev/null; then
    pkill -x rofi
    exit 0
fi

SCRIPTSDIR="${XDG_CONFIG_HOME:-$HOME/.config}/hypr/scripts"
ROFI_CONFIG="${XDG_CONFIG_HOME:-$HOME/.config}/rofi/config.rasi"
WLOGOUT_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/wlogout"
THEMES_DIR="${WLOGOUT_DIR}/themes"

# Track current preset
CURRENT_PRESET="sekiro"
if [[ -f "${WLOGOUT_DIR}/.current_theme" ]]; then
    CURRENT_PRESET=$(cat "${WLOGOUT_DIR}/.current_theme")
fi

declare -A PRESET_MAP=(
    ["⚔️  Sekiro (Sumi-e Crimson)"]="sekiro"
    ["🌸  Silvia (Sakura Pink)"]="silvia"
    ["🍁  Kurenai (Crimson Sakura)"]="kurenai"
    ["⛩️   Fuji (Mount Fuji & Torii / 富士)"]="fuji"
)

MENU_ITEMS=(
    "⚔️  Sekiro (Sumi-e Crimson)"
    "🌸  Silvia (Sakura Pink)"
    "🍁  Kurenai (Crimson Sakura)"
    "⛩️   Fuji (Mount Fuji & Torii / 富士)"
    "───────────────────────────"
    "👁️  Preview Active Wlogout"
)

DISPLAY_OPTIONS=()
DEFAULT_ROW=0
idx=0

for item in "${MENU_ITEMS[@]}"; do
    preset_id="${PRESET_MAP[$item]:-}"
    if [[ -n "$preset_id" && "$preset_id" == "$CURRENT_PRESET" ]]; then
        DISPLAY_OPTIONS+=("$item  ✓")
        DEFAULT_ROW=$idx
    else
        DISPLAY_OPTIONS+=("$item")
    fi
    idx=$((idx + 1))
done

CHOICE=$(printf '%s\n' "${DISPLAY_OPTIONS[@]}" | rofi -i -dmenu \
    -p "Wlogout Preset" \
    -mesg "Active: $CURRENT_PRESET | Select preset to apply" \
    -selected-row "$DEFAULT_ROW" \
    -theme-str "listview { columns: 1; } window { width: 55%; }" \
    -config "$ROFI_CONFIG")

if [[ -z "$CHOICE" ]]; then
    exit 0
fi

CLEAN_CHOICE=$(echo "$CHOICE" | sed 's/  ✓//')

if [[ "$CLEAN_CHOICE" == "───────────────────────────" ]]; then
    exit 0
fi

if [[ "$CLEAN_CHOICE" == "👁️  Preview Active Wlogout" ]]; then
    "$SCRIPTSDIR/Wlogout.sh" &
    exit 0
fi

SELECTED="${PRESET_MAP[$CLEAN_CHOICE]:-}"

if [[ -n "$SELECTED" && -d "${THEMES_DIR}/${SELECTED}" ]]; then
    echo "$SELECTED" > "${WLOGOUT_DIR}/.current_theme"

    # Copy theme files to active wlogout config
    cp -f "${THEMES_DIR}/${SELECTED}/style.css" "${WLOGOUT_DIR}/style.css"
    
    # Copy theme layout if present
    if [[ -f "${THEMES_DIR}/${SELECTED}/layout" ]]; then
        cp -f "${THEMES_DIR}/${SELECTED}/layout" "${WLOGOUT_DIR}/layout"
    fi

    # Copy theme flags (grid & margins) if present
    if [[ -f "${THEMES_DIR}/${SELECTED}/.theme_flags" ]]; then
        cp -f "${THEMES_DIR}/${SELECTED}/.theme_flags" "${WLOGOUT_DIR}/.theme_flags"
    fi

    # Replace active icons with theme-specific icons
    mkdir -p "${WLOGOUT_DIR}/icons"
    rm -rf "${WLOGOUT_DIR}/icons"/*
    cp -rf "${THEMES_DIR}/${SELECTED}/icons/"* "${WLOGOUT_DIR}/icons/"
    
    # Read active blur radius
    BLUR_RADIUS=20
    if [[ -f "${WLOGOUT_DIR}/.blur_radius" ]]; then
        BLUR_RADIUS=$(cat "${WLOGOUT_DIR}/.blur_radius")
    fi

    # Track raw unblurred image for subsequent blur adjustments
    if [[ -f "${THEMES_DIR}/${SELECTED}/bg_raw.png" ]]; then
        echo "${THEMES_DIR}/${SELECTED}/bg_raw.png" > "${WLOGOUT_DIR}/.current_wall_raw"
        # Blur the raw theme artwork at user's blur radius
        python3 -c "
from PIL import Image, ImageFilter
import sys, os
try:
    im = Image.open(sys.argv[1]).convert('RGBA')
    im = im.resize((1920, 1080), Image.Resampling.LANCZOS)
    radius = int(sys.argv[3])
    if radius > 0:
        im = im.filter(ImageFilter.GaussianBlur(radius=radius))
    theme = sys.argv[4] if len(sys.argv) > 4 else ''
    if theme == 'fuji':
        ov = sys.argv[5] if len(sys.argv) > 5 else os.path.expanduser('~/.config/wlogout/themes/fuji/grid_overlay.png')
        if os.path.exists(ov):
            overlay = Image.open(ov).convert('RGBA')
            im = Image.alpha_composite(im, overlay)
    im.convert('RGB').save(sys.argv[2], 'PNG')
except Exception as e:
    sys.exit(1)
" "${THEMES_DIR}/${SELECTED}/bg_raw.png" "${WLOGOUT_DIR}/bg.png" "$BLUR_RADIUS" "$SELECTED" "${THEMES_DIR}/fuji/grid_overlay.png"
        cp -f "${WLOGOUT_DIR}/bg.png" "${WLOGOUT_DIR}/sekiro_blurred.png"
    elif [[ -f "${THEMES_DIR}/${SELECTED}/bg.png" ]]; then
        cp -f "${THEMES_DIR}/${SELECTED}/bg.png" "${WLOGOUT_DIR}/bg.png"
        cp -f "${THEMES_DIR}/${SELECTED}/bg.png" "${WLOGOUT_DIR}/sekiro_blurred.png"
    fi

    if command -v notify-send >/dev/null 2>&1; then
        notify-send -u normal -i "preferences-desktop-theme" "Wlogout Theme" "Switched to: $SELECTED"
    fi
fi
