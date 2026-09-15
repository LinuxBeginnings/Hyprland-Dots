#!/usr/bin/env bash
# ==============================================================================
#  Rofi Wlogout Background Changer with Wallust & Blur Controls
#  Selects an image (with full thumbnails) or uses current wallpaper,
#  lets you control blur radius (0px to 100px), generates wallust colors,
#  and applies it to wlogout while preserving the active preset's style!
# ==============================================================================

# Support headless/automatic execution from WallustSwww.sh
if [[ "${1:-}" == "--auto" && -n "${2:-}" && -f "${2:-}" ]]; then
    # We will invoke apply_wlogout_background after definitions
    AUTO_IMAGE="$2"
else
    # Toggle: close rofi if already open
    if pidof rofi >/dev/null; then
        pkill -x rofi
        exit 0
    fi
fi

PICTURES_DIR="$(xdg-user-dir PICTURES 2>/dev/null || echo "$HOME/Pictures")"
wallDIR="$PICTURES_DIR/wallpapers"
SCRIPTSDIR="${XDG_CONFIG_HOME:-$HOME/.config}/hypr/scripts"
ROFI_CONFIG="${XDG_CONFIG_HOME:-$HOME/.config}/rofi/config.rasi"
ROFI_WALLPAPER_CONFIG="${XDG_CONFIG_HOME:-$HOME/.config}/rofi/config-wallpaper.rasi"
WLOGOUT_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/wlogout"
THEMES_DIR="${WLOGOUT_DIR}/themes"
RAW_WALL="${WLOGOUT_DIR}/.current_wall_raw"
BLUR_FILE="${WLOGOUT_DIR}/.blur_radius"
CURRENT_WALL="${XDG_CONFIG_HOME:-$HOME/.config}/hypr/wallpaper_effects/.wallpaper_current"

# Current theme preset
CURRENT_THEME="sekiro"
if [[ -f "${WLOGOUT_DIR}/.current_theme" ]]; then
    CURRENT_THEME=$(cat "${WLOGOUT_DIR}/.current_theme" 2>/dev/null || echo "sekiro")
fi

# Current blur radius (default 20 if not set)
BLUR_RADIUS=20
if [[ -f "$BLUR_FILE" ]]; then
    SAVED_BLUR=$(cat "$BLUR_FILE" 2>/dev/null || echo "")
    if [[ "$SAVED_BLUR" =~ ^[0-9]+$ ]]; then
        BLUR_RADIUS="$SAVED_BLUR"
    fi
fi

# Function to choose/adjust blur radius
choose_blur_radius() {
    local prompt_title="${1:-Select Blur Level}"
    local blur_options=(
        "✨  Keep Current (${BLUR_RADIUS}px)"
        "0px   - Crisp (No Blur)"
        "10px  - Subtle Blur"
        "20px  - Soft Blur (Default)"
        "35px  - Balanced Glass Blur"
        "50px  - Strong Frosted Blur"
        "70px  - Deep Abstract Blur"
        "✏️   Custom Radius..."
    )

    local blur_choice
    blur_choice=$(printf '%s\n' "${blur_options[@]}" | rofi -i -dmenu \
        -p "$prompt_title" \
        -mesg "Current blur: ${BLUR_RADIUS}px (0px = crisp wallpaper, 20px = soft, 50px = frosted)" \
        -selected-row 0 \
        -theme-str "listview { columns: 1; } window { width: 55%; }" \
        -config "$ROFI_CONFIG")

    if [[ -z "$blur_choice" ]]; then
        return 1
    fi

    local new_radius="$BLUR_RADIUS"
    if [[ "$blur_choice" =~ "Keep Current" ]]; then
        new_radius="$BLUR_RADIUS"
    elif [[ "$blur_choice" =~ ^0px ]]; then
        new_radius=0
    elif [[ "$blur_choice" =~ ^10px ]]; then
        new_radius=10
    elif [[ "$blur_choice" =~ ^20px ]]; then
        new_radius=20
    elif [[ "$blur_choice" =~ ^35px ]]; then
        new_radius=35
    elif [[ "$blur_choice" =~ ^50px ]]; then
        new_radius=50
    elif [[ "$blur_choice" =~ ^70px ]]; then
        new_radius=70
    elif [[ "$blur_choice" =~ "Custom Radius" ]]; then
        local custom_input
        custom_input=$(rofi -dmenu -p "Enter Radius" \
            -mesg "Enter blur radius in pixels (e.g. 0, 15, 30, 50, 80):" \
            -config "$ROFI_CONFIG")
        if [[ "$custom_input" =~ ^[0-9]+$ ]]; then
            new_radius="$custom_input"
        fi
    fi

    BLUR_RADIUS="$new_radius"
    echo "$BLUR_RADIUS" > "$BLUR_FILE"
    return 0
}

# Function to detect active wallpaper
get_active_wallpaper() {
    local selected=""
    if command -v swww >/dev/null 2>&1 && swww query >/dev/null 2>&1; then
        local current_mon
        current_mon=$(hyprctl monitors -j 2>/dev/null | jq -r '.[] | select(.focused) | .name' 2>/dev/null || echo "")
        if [[ -n "$current_mon" ]]; then
            selected=$(swww query 2>/dev/null | grep "$current_mon" | awk '{print $NF}' | head -n 1 || true)
        fi
    fi
    if [[ -z "$selected" || ! -f "$selected" ]]; then
        if [[ -f "$RAW_WALL" && -s "$RAW_WALL" ]]; then
            selected=$(cat "$RAW_WALL")
        elif [[ -f "$HOME/.config/rofi/.current_wallpaper" ]]; then
            selected=$(readlink -f "$HOME/.config/rofi/.current_wallpaper" 2>/dev/null || true)
        elif [[ -f "$CURRENT_WALL" ]]; then
            selected="$CURRENT_WALL"
        fi
    fi
    echo "$selected"
}

# Function to apply image, blur, wallust, and theme-aware CSS
apply_wlogout_background() {
    local img_path="$1"
    local radius="${2:-$BLUR_RADIUS}"

    if [[ ! -f "$img_path" ]]; then
        if command -v notify-send >/dev/null 2>&1; then
            notify-send -u critical "Wlogout BG" "Image not found: $img_path"
        fi
        exit 1
    fi

    # 1. Save original image path as raw backup & update blur radius
    echo "$img_path" > "$RAW_WALL"
    echo "$radius" > "$BLUR_FILE"

    if command -v notify-send >/dev/null 2>&1; then
        notify-send -u low "Wlogout BG" "Applying image (Blur: ${radius}px) with ${CURRENT_THEME} theme..."
    fi

    # 2. Blur image and save directly to bg.png & sekiro_blurred.png
    python3 -c "
from PIL import Image, ImageFilter
import sys, os

img_path = sys.argv[1]
out_path = sys.argv[2]
try:
    radius = int(sys.argv[3])
except Exception:
    radius = 20

theme = sys.argv[4] if len(sys.argv) > 4 else ''

im = Image.open(img_path).convert('RGBA')
im = im.resize((1920, 1080), Image.Resampling.LANCZOS)
if radius > 0:
    im = im.filter(ImageFilter.GaussianBlur(radius=radius))

if theme == 'fuji':
    overlay_path = sys.argv[5] if len(sys.argv) > 5 else os.path.expanduser('~/.config/wlogout/themes/fuji/grid_overlay.png')
    if os.path.exists(overlay_path):
        overlay = Image.open(overlay_path).convert('RGBA')
        im = Image.alpha_composite(im, overlay)

im.convert('RGB').save(out_path, 'PNG')
" "$img_path" "${WLOGOUT_DIR}/bg.png" "$radius" "$CURRENT_THEME" "${THEMES_DIR}/fuji/grid_overlay.png"

    rm -f "${WLOGOUT_DIR}/sekiro_blurred.png"
    cp -f "${WLOGOUT_DIR}/bg.png" "${WLOGOUT_DIR}/sekiro_blurred.png"

    # 3. Run wallust on the raw image to extract palette
    if command -v wallust >/dev/null 2>&1; then
        wallust run -s "$img_path" || true
    fi

    # 4. Read Wallust accent color from waybar template
    local waybar_wallust="${XDG_CONFIG_HOME:-$HOME/.config}/waybar/wallust/colors-waybar.css"
    local accent_color="#f0a6b2"

    if [[ -f "$waybar_wallust" ]]; then
        local c_val
        c_val=$(grep -oP '@define-color color2\s+\K#[A-Fa-f0-9]+' "$waybar_wallust" | head -n 1 || true)
        if [[ -z "$c_val" ]]; then
            c_val=$(grep -oP '@define-color color1\s+\K#[A-Fa-f0-9]+' "$waybar_wallust" | head -n 1 || true)
        fi
        if [[ -n "$c_val" ]]; then
            accent_color="$c_val"
        fi
    fi

    accent_color=$(echo "$accent_color" | tr -d '[:space:]')
    if [[ ! "$accent_color" =~ ^#[A-Fa-f0-9]{6}$ ]]; then
        accent_color="#f0a6b2"
    fi

    local hex="${accent_color#\#}"
    local r=$((16#${hex:0:2}))
    local g=$((16#${hex:2:2}))
    local b=$((16#${hex:4:2}))

    # 5. Apply style preserving the active preset architecture!
    if [[ "$CURRENT_THEME" == "silvia" ]]; then
        # Ensure Silvia's flags, layout, and clean vector icons are active
        if [[ -f "${THEMES_DIR}/silvia/.theme_flags" ]]; then
            cp -f "${THEMES_DIR}/silvia/.theme_flags" "${WLOGOUT_DIR}/.theme_flags"
        fi
        if [[ -f "${THEMES_DIR}/silvia/layout" ]]; then
            cp -f "${THEMES_DIR}/silvia/layout" "${WLOGOUT_DIR}/layout"
        fi
        mkdir -p "${WLOGOUT_DIR}/icons"
        cp -rf "${THEMES_DIR}/silvia/icons/"* "${WLOGOUT_DIR}/icons/"

        # Generate Silvia style with horizontal connected pill dock, integrating the dynamic Wallust accent
        cat <<EOF > "${WLOGOUT_DIR}/style.css"
/* ----------- 🌸 Silvia Sakura Pink Dock (Dynamic Wallust: ${accent_color}) 🌸 -------- */

window {
    font-family: "Noto Sans", "Cantarell", "Fira Code", sans-serif;
    color: rgba(255, 255, 255, 0.95);
    background-image: image(url("./bg.png"));
    background-size: cover;
    background-position: center;
}

button {
    background-repeat: no-repeat;
    background-position: center 36%;
    background-size: 38px;
    background-color: rgba(22, 18, 24, 0.86);
    border: none;
    box-shadow: none;
    border-radius: 0px;
    
    margin: 28px 0px;
    padding-top: 80px;
    
    color: rgba(255, 245, 250, 0.88);
    font-size: 11pt;
    font-weight: 500;
    letter-spacing: 0.5px;
    transition: all 0.25s cubic-bezier(0.16, 1, 0.3, 1);
    outline-style: none;
}

#lock {
    border-top-left-radius: 28px;
    border-bottom-left-radius: 28px;
}

#reboot, #restart {
    border-top-right-radius: 28px;
    border-bottom-right-radius: 28px;
}

button:focus {
    background-color: rgba(${r}, ${g}, ${b}, 0.35);
    outline-style: none;
}

button:hover {
    background-color: rgba(${r}, ${g}, ${b}, 0.38);
    color: #ffffff;
    font-weight: 600;
    border: 1.5px solid rgba(${r}, ${g}, ${b}, 0.85);
    border-radius: 24px;
    margin: 0px 0px;
    padding-top: 96px;
    background-size: 44px;
    background-position: center 34%;
    box-shadow: 0 16px 36px rgba(0, 0, 0, 0.65), 0 0 24px rgba(${r}, ${g}, ${b}, 0.45), inset 0 0 16px rgba(255, 255, 255, 0.30);
    outline-style: none;
}

#lock { background-image: image(url("./icons/lock.png")); }
#lock:hover { background-image: image(url("./icons/lock-hover.png")); }

#logout { background-image: image(url("./icons/logout.png")); }
#logout:hover { background-image: image(url("./icons/logout-hover.png")); }

#suspend, #sleep { background-image: image(url("./icons/sleep.png")); }
#suspend:hover, #sleep:hover { background-image: image(url("./icons/sleep-hover.png")); }

#shutdown, #power { background-image: image(url("./icons/power.png")); }
#shutdown:hover, #power:hover { background-image: image(url("./icons/power-hover.png")); }

#hibernate { background-image: image(url("./icons/hibernate.png")); }
#hibernate:hover { background-image: image(url("./icons/hibernate-hover.png")); }

#reboot, #restart { background-image: image(url("./icons/reboot.png")); }
#reboot:hover, #restart:hover { background-image: image(url("./icons/reboot-hover.png")); }
EOF

        echo "silvia" > "${WLOGOUT_DIR}/.current_theme"

    elif [[ "$CURRENT_THEME" == "kurenai" ]]; then
        # Ensure Kurenai's flags, column-first layout, and clean vector icons are active
        if [[ -f "${THEMES_DIR}/kurenai/.theme_flags" ]]; then
            cp -f "${THEMES_DIR}/kurenai/.theme_flags" "${WLOGOUT_DIR}/.theme_flags"
        fi
        if [[ -f "${THEMES_DIR}/kurenai/layout" ]]; then
            cp -f "${THEMES_DIR}/kurenai/layout" "${WLOGOUT_DIR}/layout"
        fi
        mkdir -p "${WLOGOUT_DIR}/icons"
        cp -rf "${THEMES_DIR}/kurenai/icons/"* "${WLOGOUT_DIR}/icons/"

        # Generate Kurenai style with dynamic Wallust glowing squircle and orbiting glass spheres
        cat <<EOF > "${WLOGOUT_DIR}/style.css"
/* ==============================================================================
   🍁 Kurenai (Dynamic Wallust: ${accent_color})
   Radial Dark Obsidian Glass Spheres with Dynamic Glowing Squircle & Neon Auras
   ============================================================================== */

window {
    font-family: "Noto Sans", "Cantarell", "Fira Code", sans-serif;
    color: #ffffff;
    background-image: image(url("./bg.png"));
    background-size: cover;
    background-position: center;
}

/* 6 Radial Glass Orb Buttons */
button {
    background-repeat: no-repeat;
    background-position: center 30%;
    background-size: 38px;
    background-color: rgba(18, 14, 20, 0.88);
    border: 1.5px solid rgba(${r}, ${g}, ${b}, 0.35);
    border-radius: 9999px;
    box-shadow: 0 8px 24px rgba(0, 0, 0, 0.65), inset 0 2px 4px rgba(255, 255, 255, 0.12), inset 0 -4px 10px rgba(${r}, ${g}, ${b}, 0.25);
    
    color: #ffffff;
    font-size: 11pt;
    font-weight: 500;
    letter-spacing: 0.5px;
    padding-top: 68px;
    outline-style: none;
    transition: all 0.25s cubic-bezier(0.16, 1, 0.3, 1);
}

/* Center Shutdown Squircle */
#shutdown, #power {
    background-repeat: no-repeat;
    background-position: center 30%;
    background-size: 52px;
    background-color: rgba(28, 16, 22, 0.92);
    border: 2.5px solid rgba(${r}, ${g}, ${b}, 0.92);
    border-radius: 44px;
    box-shadow: 0 0 35px rgba(${r}, ${g}, ${b}, 0.75), 0 12px 28px rgba(0, 0, 0, 0.75), inset 0 0 20px rgba(${r}, ${g}, ${b}, 0.40);
    
    color: #ffffff;
    font-size: 12pt;
    font-weight: 600;
    padding-top: 88px;
}

/* Button Focus State */
button:focus {
    background-color: rgba(${r}, ${g}, ${b}, 0.30);
    border-color: rgba(${r}, ${g}, ${b}, 0.90);
    outline-style: none;
}

/* Hover State for Radial Spheres */
button:hover {
    background-color: rgba(${r}, ${g}, ${b}, 0.35);
    border: 2px solid rgba(${r}, ${g}, ${b}, 0.95);
    box-shadow: 0 0 36px rgba(${r}, ${g}, ${b}, 0.85), 0 14px 32px rgba(0, 0, 0, 0.75), inset 0 0 18px rgba(${r}, ${g}, ${b}, 0.50);
    color: #ffffff;
    font-weight: 600;
    background-size: 44px;
    background-position: center 28%;
    outline-style: none;
}

/* Hover State for Center Shutdown Squircle */
#shutdown:hover, #power:hover {
    background-color: rgba(${r}, ${g}, ${b}, 0.45);
    border: 3px solid rgba(${r}, ${g}, ${b}, 1.0);
    box-shadow: 0 0 55px rgba(${r}, ${g}, ${b}, 1.0), 0 16px 36px rgba(0, 0, 0, 0.85), inset 0 0 30px rgba(${r}, ${g}, ${b}, 0.65);
    background-size: 58px;
    background-position: center 28%;
}

/* Click / Active State */
button:active {
    background-color: rgba(${r}, ${g}, ${b}, 0.55);
    box-shadow: 0 0 45px rgba(${r}, ${g}, ${b}, 1.0), inset 0 0 24px rgba(${r}, ${g}, ${b}, 0.85);
}

/* Spacers are strictly invisible, non-interactive layout stabilizers */
#s0, #s1, #s2, #s3, #s4, #s5, #s6, #s7 {
    opacity: 0;
    border: none;
    background: transparent;
    background-color: transparent;
    box-shadow: none;
}

/* Button Icon Bindings */
#lock { background-image: image(url("./icons/lock.png")); }
#lock:hover { background-image: image(url("./icons/lock-hover.png")); }

#reboot, #restart { background-image: image(url("./icons/reboot.png")); }
#reboot:hover, #restart:hover { background-image: image(url("./icons/reboot-hover.png")); }

#logout { background-image: image(url("./icons/logout.png")); }
#logout:hover { background-image: image(url("./icons/logout-hover.png")); }

#hibernate { background-image: image(url("./icons/hibernate.png")); }
#hibernate:hover { background-image: image(url("./icons/hibernate-hover.png")); }

#suspend { background-image: image(url("./icons/suspend.png")); }
#suspend:hover { background-image: image(url("./icons/suspend-hover.png")); }

#sleep { background-image: image(url("./icons/sleep.png")); }
#sleep:hover { background-image: image(url("./icons/sleep-hover.png")); }

#shutdown, #power { background-image: image(url("./icons/shutdown.png")); }
#shutdown:hover, #power:hover { background-image: image(url("./icons/shutdown-hover.png")); }
EOF

        echo "kurenai" > "${WLOGOUT_DIR}/.current_theme"

    elif [[ "$CURRENT_THEME" == "fuji" ]]; then
        # Ensure Fuji's flags, column-first 2x3 layout, and authentic sumi-e icons are active
        if [[ -f "${THEMES_DIR}/fuji/.theme_flags" ]]; then
            cp -f "${THEMES_DIR}/fuji/.theme_flags" "${WLOGOUT_DIR}/.theme_flags"
        fi
        if [[ -f "${THEMES_DIR}/fuji/layout" ]]; then
            cp -f "${THEMES_DIR}/fuji/layout" "${WLOGOUT_DIR}/layout"
        fi
        mkdir -p "${WLOGOUT_DIR}/icons"
        cp -rf "${THEMES_DIR}/fuji/icons/"* "${WLOGOUT_DIR}/icons/"

        # Generate Fuji style with dynamic Wallust hover bloom
        cat <<EOF > "${WLOGOUT_DIR}/style.css"
/* ==============================================================================
   ⛩️  Fuji (Dynamic Wallust: ${accent_color})
   Sumi-e Enso Calligraphy & Tech Grid Matrix with Dynamic Accent Bloom
   ============================================================================== */

window {
    font-family: "Noto Sans", "Cantarell", sans-serif;
    color: transparent;
    background-image: image(url("./bg.png"));
    background-size: cover;
    background-position: center;
}

button {
    background-repeat: no-repeat;
    background-position: center;
    background-size: 190px;
    background-color: transparent;
    border: none;
    box-shadow: none;
    color: transparent;
    outline-style: none;
    transition: all 0.22s cubic-bezier(0.16, 1, 0.3, 1);
}

button:focus {
    outline-style: none;
    background-color: transparent;
    border: none;
    box-shadow: none;
}

button:hover {
    background-size: 202px;
    background-color: rgba(${r}, ${g}, ${b}, 0.08);
    border-radius: 12px;
    border: none;
    box-shadow: 0 0 35px rgba(${r}, ${g}, ${b}, 0.40);
    outline-style: none;
}

button:active {
    background-size: 186px;
    opacity: 0.90;
}

#lock { background-image: image(url("./icons/lock.png")); }
#lock:hover { background-image: image(url("./icons/lock-hover.png")); }

#reboot, #restart { background-image: image(url("./icons/reboot.png")); }
#reboot:hover, #restart:hover { background-image: image(url("./icons/reboot-hover.png")); }

#logout { background-image: image(url("./icons/logout.png")); }
#logout:hover { background-image: image(url("./icons/logout-hover.png")); }

#suspend, #sleep { background-image: image(url("./icons/suspend.png")); }
#suspend:hover, #sleep:hover { background-image: image(url("./icons/suspend-hover.png")); }

#shutdown, #power { background-image: image(url("./icons/shutdown.png")); }
#shutdown:hover, #power:hover { background-image: image(url("./icons/shutdown-hover.png")); }

#hibernate { background-image: image(url("./icons/hibernate.png")); }
#hibernate:hover { background-image: image(url("./icons/hibernate-hover.png")); }
EOF

        echo "fuji" > "${WLOGOUT_DIR}/.current_theme"

    elif [[ "$CURRENT_THEME" == "sekiro" ]]; then
        # Sekiro remains 100% UNTOUCHED
        if [[ -f "${THEMES_DIR}/sekiro/.theme_flags" ]]; then
            cp -f "${THEMES_DIR}/sekiro/.theme_flags" "${WLOGOUT_DIR}/.theme_flags"
        fi
        if [[ -f "${THEMES_DIR}/sekiro/layout" ]]; then
            cp -f "${THEMES_DIR}/sekiro/layout" "${WLOGOUT_DIR}/layout"
        fi
        if [[ -f "${THEMES_DIR}/sekiro/style.css" ]]; then
            cp -f "${THEMES_DIR}/sekiro/style.css" "${WLOGOUT_DIR}/style.css"
        fi
        mkdir -p "${WLOGOUT_DIR}/icons"
        cp -rf "${THEMES_DIR}/sekiro/icons/"* "${WLOGOUT_DIR}/icons/"

        echo "sekiro" > "${WLOGOUT_DIR}/.current_theme"

    else
        # Default dynamic wallust styling for other themes
        if [[ -f "${THEMES_DIR}/${CURRENT_THEME}/style.css" ]]; then
            cp -f "${THEMES_DIR}/${CURRENT_THEME}/style.css" "${WLOGOUT_DIR}/style.css"
        fi
        if [[ -f "${THEMES_DIR}/${CURRENT_THEME}/layout" ]]; then
            cp -f "${THEMES_DIR}/${CURRENT_THEME}/layout" "${WLOGOUT_DIR}/layout"
        fi
        if [[ -f "${THEMES_DIR}/${CURRENT_THEME}/.theme_flags" ]]; then
            cp -f "${THEMES_DIR}/${CURRENT_THEME}/.theme_flags" "${WLOGOUT_DIR}/.theme_flags"
        fi
        if [[ -d "${THEMES_DIR}/${CURRENT_THEME}/icons" ]]; then
            mkdir -p "${WLOGOUT_DIR}/icons"
            cp -rf "${THEMES_DIR}/${CURRENT_THEME}/icons/"* "${WLOGOUT_DIR}/icons/"
        fi
        echo "$CURRENT_THEME" > "${WLOGOUT_DIR}/.current_theme"
    fi

    if command -v notify-send >/dev/null 2>&1; then
        notify-send -u normal -i "preferences-desktop-theme" "Wlogout Wallust" "Applied image (${radius}px blur) with ${CURRENT_THEME} style! Accent: ${accent_color}"
    fi
}

# If called headlessly with --auto, run immediately and exit
if [[ -n "${AUTO_IMAGE:-}" && -f "${AUTO_IMAGE:-}" ]]; then
    apply_wlogout_background "$AUTO_IMAGE" "$BLUR_RADIUS"
    exit 0
fi

# Main Menu
MENU_OPTIONS=(
    "🖼️   Use Current Desktop Wallpaper"
    "📁   Choose from Wallpapers Folder (Thumbnails)"
    "🌫️   Adjust Blur Radius (Current: ${BLUR_RADIUS}px)"
    "🔄   Re-generate Wallust Colors from Current Background"
)

CHOICE=$(printf '%s\n' "${MENU_OPTIONS[@]}" | rofi -i -dmenu \
    -p "Wlogout BG" \
    -mesg "Active: $CURRENT_THEME | Select image or blur level:" \
    -theme-str "listview { columns: 1; } window { width: 55%; }" \
    -config "$ROFI_CONFIG")

if [[ -z "$CHOICE" ]]; then
    exit 0
fi

# Case 1: Adjust Blur Level
if [[ "$CHOICE" =~ "Adjust Blur Radius" ]]; then
    if choose_blur_radius "Adjust Blur Radius"; then
        # Resolve raw unblurred image source
        RAW_IMAGE=""
        if [[ -f "$RAW_WALL" && -s "$RAW_WALL" ]]; then
            RAW_IMAGE=$(cat "$RAW_WALL")
        fi

        if [[ -z "$RAW_IMAGE" || ! -f "$RAW_IMAGE" ]]; then
            if [[ -f "${THEMES_DIR}/${CURRENT_THEME}/bg_raw.png" ]]; then
                RAW_IMAGE="${THEMES_DIR}/${CURRENT_THEME}/bg_raw.png"
            else
                RAW_IMAGE=$(get_active_wallpaper)
            fi
        fi

        if [[ -n "$RAW_IMAGE" && -f "$RAW_IMAGE" ]]; then
            apply_wlogout_background "$RAW_IMAGE" "$BLUR_RADIUS"
        fi
    fi
    exit 0
fi

# Case 2: Use Current Desktop Wallpaper
if [[ "$CHOICE" =~ "Use Current Desktop Wallpaper" ]]; then
    SELECTED_IMAGE=$(get_active_wallpaper)
    if [[ -z "$SELECTED_IMAGE" || ! -f "$SELECTED_IMAGE" ]]; then
        if command -v notify-send >/dev/null 2>&1; then
            notify-send -u critical "Wlogout BG" "Could not detect active desktop wallpaper!"
        fi
        exit 1
    fi

    choose_blur_radius "Blur for Wallpaper" || true
    apply_wlogout_background "$SELECTED_IMAGE" "$BLUR_RADIUS"
    exit 0
fi

# Case 3: Choose from Wallpapers Folder with Visual Thumbnails
if [[ "$CHOICE" =~ "Choose from Wallpapers Folder" ]]; then
    if [[ ! -d "$wallDIR" ]]; then
        wallDIR="$HOME/Pictures"
    fi

    # Detect monitor scaling for thumbnail sizing
    focused_monitor=$(hyprctl monitors -j 2>/dev/null | jq -r '.[] | select(.focused) | .name' 2>/dev/null || echo "")
    scale_factor=$(hyprctl monitors -j 2>/dev/null | jq -r --arg mon "$focused_monitor" '.[] | select(.name == $mon) | .scale' 2>/dev/null || echo 1)
    monitor_height=$(hyprctl monitors -j 2>/dev/null | jq -r --arg mon "$focused_monitor" '.[] | select(.name == $mon) | .height' 2>/dev/null || echo 1080)

    icon_size=$(echo "scale=1; ($monitor_height * 3) / ($scale_factor * 150)" | bc 2>/dev/null || echo 20)
    adjusted_icon_size=$(echo "$icon_size" | awk '{if ($1 < 15) $1 = 20; if ($1 > 25) $1 = 25; print $1}')
    rofi_override="element-icon{size:${adjusted_icon_size}%;}"

    TSV_MAP="/tmp/wlogout_wallpapers_map.tsv"
    IMG_CHOICE=$(python3 -c "
import os, sys, signal
signal.signal(signal.SIGPIPE, signal.SIG_DFL)

walldir = sys.argv[1]
valid_exts = ('.jpg', '.jpeg', '.png', '.webp', '.bmp', '.tiff')
seen = set()

with open(sys.argv[2], 'w') as tsv:
    for root, dirs, files in os.walk(walldir):
        for f in sorted(files):
            if f.lower().endswith(valid_exts):
                full = os.path.join(root, f)
                base = os.path.splitext(f)[0]
                display = base
                if display in seen:
                    folder = os.path.basename(root)
                    display = f'{base} ({folder})'
                seen.add(display)
                tsv.write(f'{display}\t{full}\n')
                sys.stdout.write(f'{display}\x00icon\x1f{full}\n')
" "$wallDIR" "$TSV_MAP" | rofi -i -show -dmenu \
        -config "$ROFI_WALLPAPER_CONFIG" \
        -theme-str "$rofi_override" \
        -p "Select Wallpaper")

    if [[ -z "$IMG_CHOICE" ]]; then
        exit 0
    fi

    SELECTED_IMAGE=$(grep -F -m 1 "$IMG_CHOICE"$'\t' "$TSV_MAP" 2>/dev/null | cut -f2 || echo "")

    if [[ -z "$SELECTED_IMAGE" || ! -f "$SELECTED_IMAGE" ]]; then
        SELECTED_IMAGE=$(find "$wallDIR" -type f -iname "*${IMG_CHOICE}*" -print -quit 2>/dev/null || echo "")
    fi

    if [[ -z "$SELECTED_IMAGE" || ! -f "$SELECTED_IMAGE" ]]; then
        if command -v notify-send >/dev/null 2>&1; then
            notify-send -u critical "Wlogout BG" "Failed to locate wallpaper: $IMG_CHOICE"
        fi
        exit 1
    fi

    choose_blur_radius "Blur for Selected Wallpaper" || true
    apply_wlogout_background "$SELECTED_IMAGE" "$BLUR_RADIUS"
    exit 0
fi

# Case 4: Re-generate Wallust Colors from Current Background
if [[ "$CHOICE" =~ "Re-generate Wallust Colors" ]]; then
    RAW_IMAGE=""
    if [[ -f "$RAW_WALL" && -s "$RAW_WALL" ]]; then
        RAW_IMAGE=$(cat "$RAW_WALL")
    fi
    if [[ -z "$RAW_IMAGE" || ! -f "$RAW_IMAGE" ]]; then
        RAW_IMAGE=$(get_active_wallpaper)
    fi
    if [[ -n "$RAW_IMAGE" && -f "$RAW_IMAGE" ]]; then
        apply_wlogout_background "$RAW_IMAGE" "$BLUR_RADIUS"
    fi
    exit 0
fi
