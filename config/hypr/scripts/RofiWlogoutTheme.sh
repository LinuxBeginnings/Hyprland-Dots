#!/usr/bin/env bash
# ==============================================================================
#  Rofi Wlogout Theme Switcher
#  Switch between presets: Default (KoolDots), Sekiro, Silvia, Kurenai, Fuji
#  Includes backup and restore for current wlogout configurations
# ==============================================================================

# Toggle: close rofi if already open
if pidof rofi >/dev/null; then
    pkill -x rofi
    exit 0
fi

SCRIPTSDIR="${XDG_CONFIG_HOME:-$HOME/.config}/hypr/scripts"
WLOGOUT_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/wlogout"
THEMES_DIR="${WLOGOUT_DIR}/themes"
BACKUP_DIR="${THEMES_DIR}/user_backup"

# Locate Rofi config with KoolDots fallback
ROFI_CONFIG="${XDG_CONFIG_HOME:-$HOME/.config}/hypr/rofi/config.rasi"
if [[ ! -f "$ROFI_CONFIG" && -f "${XDG_CONFIG_HOME:-$HOME/.config}/rofi/config.rasi" ]]; then
    ROFI_CONFIG="${XDG_CONFIG_HOME:-$HOME/.config}/rofi/config.rasi"
fi

# Multi-engine background blur renderer (Python-Pillow -> ImageMagick -> ffmpeg -> fallback)
render_theme_background() {
    local src_raw="$1"
    local dst_bg="$2"
    local radius="${3:-20}"
    local theme="${4:-}"
    local overlay="${5:-}"
    local rendered=0

    # 1. Try Python 3 with Pillow
    if python3 -c "import PIL" >/dev/null 2>&1; then
        if python3 -c "
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
        ov = sys.argv[5] if len(sys.argv) > 5 else ''
        if ov and os.path.exists(ov):
            overlay = Image.open(ov).convert('RGBA')
            im = Image.alpha_composite(im, overlay)
    im.convert('RGB').save(sys.argv[2], 'PNG')
except Exception:
    sys.exit(1)
" "$src_raw" "$dst_bg" "$radius" "$theme" "$overlay" 2>/dev/null; then
            rendered=1
        fi
    fi

    # 2. Try ImageMagick (magick / convert)
    if [[ $rendered -eq 0 ]]; then
        local im_cmd=""
        if command -v magick >/dev/null 2>&1; then
            im_cmd="magick"
        elif command -v convert >/dev/null 2>&1; then
            im_cmd="convert"
        fi
        if [[ -n "$im_cmd" ]]; then
            local blur_opt=()
            if [[ "$radius" -gt 0 ]]; then
                blur_opt=(-blur "0x${radius}")
            fi
            if [[ "$theme" == "fuji" && -n "$overlay" && -f "$overlay" ]]; then
                $im_cmd "$src_raw" -resize 1920x1080^ -gravity center -extent 1920x1080 "${blur_opt[@]}" "$overlay" -composite "$dst_bg" 2>/dev/null && rendered=1
            else
                $im_cmd "$src_raw" -resize 1920x1080^ -gravity center -extent 1920x1080 "${blur_opt[@]}" "$dst_bg" 2>/dev/null && rendered=1
            fi
        fi
    fi

    # 3. Try ffmpeg
    if [[ $rendered -eq 0 ]] && command -v ffmpeg >/dev/null 2>&1; then
        local vf="scale=1920:1080:force_original_aspect_ratio=increase,crop=1920:1080"
        if [[ "$radius" -gt 0 ]]; then
            vf="${vf},gblur=sigma=${radius}"
        fi
        if [[ "$theme" == "fuji" && -n "$overlay" && -f "$overlay" ]]; then
            ffmpeg -y -i "$src_raw" -i "$overlay" -filter_complex "[0:v]${vf}[bg];[bg][1:v]overlay=0:0" -frames:v 1 -update 1 "$dst_bg" >/dev/null 2>&1 && rendered=1
        else
            ffmpeg -y -i "$src_raw" -vf "$vf" -frames:v 1 -update 1 "$dst_bg" >/dev/null 2>&1 && rendered=1
        fi
    fi

    # 4. Fallback: Pre-rendered bg.png or direct copy
    if [[ $rendered -eq 0 || ! -s "$dst_bg" ]]; then
        local theme_dir
        theme_dir="$(dirname "$src_raw")"
        if [[ -f "${theme_dir}/bg.png" ]]; then
            cp -f "${theme_dir}/bg.png" "$dst_bg"
        else
            cp -f "$src_raw" "$dst_bg"
        fi
    fi
}

# Function to back up active wlogout configuration
backup_active_wlogout() {
    local silent="${1:-0}"
    mkdir -p "${BACKUP_DIR}/icons"
    [[ -f "${WLOGOUT_DIR}/style.css" ]] && cp -f "${WLOGOUT_DIR}/style.css" "${BACKUP_DIR}/style.css"
    [[ -f "${WLOGOUT_DIR}/layout" ]] && cp -f "${WLOGOUT_DIR}/layout" "${BACKUP_DIR}/layout"
    if [[ -d "${WLOGOUT_DIR}/icons" ]]; then
        cp -rf "${WLOGOUT_DIR}/icons/"* "${BACKUP_DIR}/icons/" 2>/dev/null || true
    fi
    if [[ -f "${WLOGOUT_DIR}/.theme_flags" ]]; then
        cp -f "${WLOGOUT_DIR}/.theme_flags" "${BACKUP_DIR}/.theme_flags"
    else
        rm -f "${BACKUP_DIR}/.theme_flags"
    fi
    if [[ "$silent" != "1" ]] && command -v notify-send >/dev/null 2>&1; then
        notify-send -u normal -i "document-save" "Wlogout Backup" "Saved active config to user_backup"
    fi
}

# Track current preset
CURRENT_PRESET="default"
if [[ -f "${WLOGOUT_DIR}/.current_theme" ]]; then
    CURRENT_PRESET=$(cat "${WLOGOUT_DIR}/.current_theme" 2>/dev/null || echo "default")
fi
[[ -z "$CURRENT_PRESET" ]] && CURRENT_PRESET="default"

declare -A PRESET_MAP=(
    ["💫  Default (KoolDots)"]="default"
    ["⚔️  Sekiro (Sumi-e Crimson)"]="sekiro"
    ["🌸  Silvia (Sakura Pink)"]="silvia"
    ["🍁  Kurenai (Crimson Sakura)"]="kurenai"
    ["⛩️   Fuji (Mount Fuji & Torii / 富士)"]="fuji"
)

MENU_ITEMS=(
    "💫  Default (KoolDots)"
    "⚔️  Sekiro (Sumi-e Crimson)"
    "🌸  Silvia (Sakura Pink)"
    "🍁  Kurenai (Crimson Sakura)"
    "⛩️   Fuji (Mount Fuji & Torii / 富士)"
)

# Dynamically discover any other custom presets in THEMES_DIR
if [[ -d "$THEMES_DIR" ]]; then
    for dir in "$THEMES_DIR"/*/; do
        [[ -d "$dir" ]] || continue
        theme_name=$(basename "$dir")
        case "$theme_name" in
            default|sekiro|silvia|kurenai|fuji|user_backup) continue ;;
            *)
                label="🎨  ${theme_name}"
                PRESET_MAP["$label"]="$theme_name"
                MENU_ITEMS+=("$label")
                ;;
        esac
    done
fi

# Add restore option if a user backup exists
if [[ -d "$BACKUP_DIR" && (-f "${BACKUP_DIR}/style.css" || -d "${BACKUP_DIR}/icons") ]]; then
    PRESET_MAP["⏮️  Restore User Backup"]="user_backup"
    MENU_ITEMS+=("⏮️  Restore User Backup")
fi

MENU_ITEMS+=(
    "───────────────────────────"
    "💾  Backup Current Config"
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

# Sync focused wallpaper link before showing Rofi
if [[ -x "${SCRIPTSDIR}/RofiFocusedWallpaperLink.sh" ]]; then
    "${SCRIPTSDIR}/RofiFocusedWallpaperLink.sh" >/dev/null 2>&1 || true
fi

CHOICE=$(printf '%s\n' "${DISPLAY_OPTIONS[@]}" | rofi -i -dmenu \
    -p "Wlogout Preset" \
    -mesg "Active: $CURRENT_PRESET | Select preset or action to apply" \
    -selected-row "$DEFAULT_ROW" \
    -theme-str "listview { columns: 1; } window { width: 55%; }" \
    -config "$ROFI_CONFIG")

if [[ -z "$CHOICE" ]]; then
    exit 0
fi

CLEAN_CHOICE="${CHOICE//  ✓/}"

if [[ "$CLEAN_CHOICE" == "───────────────────────────" ]]; then
    exit 0
fi

if [[ "$CLEAN_CHOICE" == "💾  Backup Current Config" ]]; then
    backup_active_wlogout 0
    exit 0
fi

if [[ "$CLEAN_CHOICE" == "👁️  Preview Active Wlogout" ]]; then
    "$SCRIPTSDIR/Wlogout.sh" &
    exit 0
fi

SELECTED="${PRESET_MAP[$CLEAN_CHOICE]:-}"

if [[ -n "$SELECTED" && -d "${THEMES_DIR}/${SELECTED}" ]]; then
    # If switching away from an unsaved custom config, automatically create user_backup
    if [[ ! -d "$BACKUP_DIR" && "$CURRENT_PRESET" != "default" && "$CURRENT_PRESET" != "$SELECTED" ]]; then
        backup_active_wlogout 1
    fi

    echo "$SELECTED" > "${WLOGOUT_DIR}/.current_theme"

    # Copy theme style
    if [[ -f "${THEMES_DIR}/${SELECTED}/style.css" ]]; then
        cp -f "${THEMES_DIR}/${SELECTED}/style.css" "${WLOGOUT_DIR}/style.css"
    fi
    
    # Copy theme layout if present
    if [[ -f "${THEMES_DIR}/${SELECTED}/layout" ]]; then
        cp -f "${THEMES_DIR}/${SELECTED}/layout" "${WLOGOUT_DIR}/layout"
    fi

    # Copy theme flags if present, or remove them so default responsive calculations apply
    if [[ -f "${THEMES_DIR}/${SELECTED}/.theme_flags" ]]; then
        cp -f "${THEMES_DIR}/${SELECTED}/.theme_flags" "${WLOGOUT_DIR}/.theme_flags"
    else
        rm -f "${WLOGOUT_DIR}/.theme_flags"
    fi

    # Replace active icons with theme-specific icons
    mkdir -p "${WLOGOUT_DIR}/icons"
    rm -rf "${WLOGOUT_DIR}/icons"/*
    if [[ -d "${THEMES_DIR}/${SELECTED}/icons" ]]; then
        cp -rf "${THEMES_DIR}/${SELECTED}/icons/"* "${WLOGOUT_DIR}/icons/"
    fi
    
    # Background handling
    if [[ "$SELECTED" == "default" ]]; then
        # Default KoolDots wlogout uses dynamic Wallust color styling without a static wallpaper background
        rm -f "${WLOGOUT_DIR}/bg.png" "${WLOGOUT_DIR}/sekiro_blurred.png"
    else
        # Read active blur radius
        BLUR_RADIUS=20
        if [[ -f "${WLOGOUT_DIR}/.blur_radius" ]]; then
            SAVED_BLUR=$(cat "${WLOGOUT_DIR}/.blur_radius" 2>/dev/null || echo "")
            if [[ "$SAVED_BLUR" =~ ^[0-9]+$ ]]; then
                BLUR_RADIUS="$SAVED_BLUR"
            fi
        fi

        if [[ -f "${THEMES_DIR}/${SELECTED}/bg_raw.png" ]]; then
            echo "${THEMES_DIR}/${SELECTED}/bg_raw.png" > "${WLOGOUT_DIR}/.current_wall_raw"
            render_theme_background "${THEMES_DIR}/${SELECTED}/bg_raw.png" "${WLOGOUT_DIR}/bg.png" "$BLUR_RADIUS" "$SELECTED" "${THEMES_DIR}/fuji/grid_overlay.png"
        elif [[ -f "${THEMES_DIR}/${SELECTED}/bg.png" ]]; then
            cp -f "${THEMES_DIR}/${SELECTED}/bg.png" "${WLOGOUT_DIR}/bg.png"
        fi
    fi

    if command -v notify-send >/dev/null 2>&1; then
        if [[ "$SELECTED" == "default" ]]; then
            notify-send -u normal -i "preferences-desktop-theme" "Wlogout Theme" "Restored: Default (KoolDots)"
        elif [[ "$SELECTED" == "user_backup" ]]; then
            notify-send -u normal -i "document-revert" "Wlogout Theme" "Restored: User Backup Config"
        else
            notify-send -u normal -i "preferences-desktop-theme" "Wlogout Theme" "Switched to: $SELECTED"
        fi
    fi
fi
