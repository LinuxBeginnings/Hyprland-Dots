#!/usr/bin/env bash
# ==============================================================================
#  SDDM Theme Preset Selector for Hyprland
#  Switches between Silent SDDM presets (Silvia, Rei, Ken, Catppuccin, etc.)
# ==============================================================================

SCRIPTSDIR="${XDG_CONFIG_HOME:-$HOME/.config}/hypr/scripts"
ROFI_CONFIG="${XDG_CONFIG_HOME:-$HOME/.config}/hypr/rofi/config-sddm.rasi"
THEME_REPO="https://github.com/Mr-Hasan-Hamid/sddm-theme.git"

# Resolve SDDM themes root (standard Linux vs NixOS fallback)
SDDM_THEMES_DIR="/usr/share/sddm/themes"
if [[ ! -d "$SDDM_THEMES_DIR" && -d "/run/current-system/sw/share/sddm/themes" ]]; then
    SDDM_THEMES_DIR="/run/current-system/sw/share/sddm/themes"
fi
THEME_DIR="${SDDM_THEMES_DIR}/silent"
META="${THEME_DIR}/metadata.desktop"

# Fallback to default rofi config if custom sddm config is absent
if [[ ! -f "$ROFI_CONFIG" ]]; then
    ROFI_CONFIG="${XDG_CONFIG_HOME:-$HOME/.config}/hypr/rofi/config.rasi"
fi

# Refresh wallpaper link for Rofi background theme
if [[ -x "$SCRIPTSDIR/RofiFocusedWallpaperLink.sh" ]]; then
    "$SCRIPTSDIR/RofiFocusedWallpaperLink.sh" >/dev/null 2>&1 || true
fi

# If Silent theme is not installed, provide one-click install option
if [[ ! -d "$THEME_DIR" ]]; then
    INSTALL_CHOICE=$(printf "⬇️  Install Silent SDDM Theme & Assets\n❌  Cancel" | rofi -i -dmenu \
        -p "SDDM Theme" \
        -mesg "Silent theme is not installed. Would you like to install it?" \
        -config "$ROFI_CONFIG")

    if [[ "$INSTALL_CHOICE" =~ "Install" ]]; then
        TERMINAL="${TERMINAL:-$(command -v kitty || command -v alacritty || command -v foot || command -v xterm || echo "")}"
        INSTALL_CMD="echo '==> Cloning and installing Silent SDDM Theme...'; rm -rf /tmp/sddm-theme && git clone --depth=1 $THEME_REPO /tmp/sddm-theme && cd /tmp/sddm-theme && ./install.sh && echo '==> Done! Press Enter to exit.'; read -r"
        if [[ "$TERMINAL" =~ kitty ]]; then
            "$TERMINAL" --hold sh -c "$INSTALL_CMD" &
        elif [[ -n "$TERMINAL" ]]; then
            "$TERMINAL" -e sh -c "$INSTALL_CMD" &
        fi
    fi
    exit 0
fi

# Determine currently active preset
CURRENT_PRESET="default"
if [[ -f "$META" ]]; then
    CURRENT_LINE=$(grep "^ConfigFile=" "$META" || true)
    if [[ -n "$CURRENT_LINE" ]]; then
        CLEAN_CONFIG="${CURRENT_LINE#ConfigFile=}"
        CURRENT_PRESET=$(basename "$CLEAN_CONFIG" .conf | sed 's|^configs/||')
    fi
fi

# Presets mapping (display -> preset_id)
declare -A PRESET_MAP=(
    ["󰄛  Silvia"]="silvia"
    ["🌸  Rei"]="rei"
    ["⚔️  Ken"]="ken"
    ["☕  Catppuccin Mocha"]="catppuccin-mocha"
    ["☕  Catppuccin Macchiato"]="catppuccin-macchiato"
    ["☕  Catppuccin Frappé"]="catppuccin-frappe"
    ["☕  Catppuccin Latte"]="catppuccin-latte"
    ["🖥️  Default (Center)"]="default"
    ["◀️  Default (Left)"]="default-left"
    ["▶️  Default (Right)"]="default-right"
)

# Ordered menu list
MENU_ITEMS=(
    "󰄛  Silvia"
    "🌸  Rei"
    "⚔️  Ken"
    "☕  Catppuccin Mocha"
    "☕  Catppuccin Macchiato"
    "☕  Catppuccin Frappé"
    "☕  Catppuccin Latte"
    "🖥️  Default (Center)"
    "◀️  Default (Left)"
    "▶️  Default (Right)"
    "───────────────────────────"
    "👁️  Test Current in Preview Window"
)

# Build display options with active marker
DISPLAY_OPTIONS=()
DEFAULT_ROW=0
idx=0

for item in "${MENU_ITEMS[@]}"; do
    preset_id="${PRESET_MAP[$item]}"
    if [[ -n "$preset_id" && "$preset_id" == "$CURRENT_PRESET" ]]; then
        DISPLAY_OPTIONS+=("$item  ✓")
        DEFAULT_ROW=$idx
    else
        DISPLAY_OPTIONS+=("$item")
    fi
    ((idx++))
done

# Check if rofi is already running
if pgrep -x rofi >/dev/null; then
    killall rofi 2>/dev/null || true
fi

# Launch Rofi
CHOICE=$(printf '%s\n' "${DISPLAY_OPTIONS[@]}" | rofi -i -dmenu \
    -p "SDDM Theme" \
    -mesg "Active: $CURRENT_PRESET | Select preset to switch" \
    -selected-row "$DEFAULT_ROW" \
    -config "$ROFI_CONFIG")

if [[ -z "$CHOICE" ]]; then
    exit 0
fi

# Strip the active checkmark if present
CLEAN_CHOICE=$(echo "$CHOICE" | sed 's/  ✓//')

if [[ "$CLEAN_CHOICE" == "───────────────────────────" ]]; then
    exit 0
fi

if [[ "$CLEAN_CHOICE" == "👁️  Test Current in Preview Window" ]]; then
    if command -v notify-send >/dev/null 2>&1; then
        notify-send -u low "SDDM" "Launching preview window (Press Esc to close)"
    fi
    if command -v sddm-greeter-qt6 >/dev/null 2>&1; then
        QT_IM_MODULE=qtvirtualkeyboard QML2_IMPORT_PATH="${THEME_DIR}/components/" sddm-greeter-qt6 --test-mode --theme "$THEME_DIR" &
    elif command -v sddm-greeter >/dev/null 2>&1; then
        QT_IM_MODULE=qtvirtualkeyboard QML2_IMPORT_PATH="${THEME_DIR}/components/" sddm-greeter --test-mode --theme "$THEME_DIR" &
    fi
    exit 0
fi

SELECTED_PRESET="${PRESET_MAP[$CLEAN_CHOICE]}"

if [[ -n "$SELECTED_PRESET" ]]; then
    SUCCESS=0
    if command -v set-sddm-preset >/dev/null 2>&1; then
        if sudo -n set-sddm-preset "$SELECTED_PRESET" 2>/dev/null; then
            SUCCESS=1
        elif command -v pkexec >/dev/null 2>&1 && pkexec set-sddm-preset "$SELECTED_PRESET"; then
            SUCCESS=1
        elif sudo set-sddm-preset "$SELECTED_PRESET"; then
            SUCCESS=1
        fi
    elif [[ -w "$META" ]]; then
        sed -i "s|^ConfigFile=.*|ConfigFile=configs/${SELECTED_PRESET}.conf|" "$META" && SUCCESS=1
    elif command -v pkexec >/dev/null 2>&1; then
        pkexec sed -i "s|^ConfigFile=.*|ConfigFile=configs/${SELECTED_PRESET}.conf|" "$META" && SUCCESS=1
    else
        sudo sed -i "s|^ConfigFile=.*|ConfigFile=configs/${SELECTED_PRESET}.conf|" "$META" && SUCCESS=1
    fi

    if [[ $SUCCESS -eq 1 ]]; then
        if command -v notify-send >/dev/null 2>&1; then
            notify-send -u normal -i "preferences-desktop-theme" "SDDM Theme" "Switched to: $SELECTED_PRESET"
        fi
    else
        if command -v notify-send >/dev/null 2>&1; then
            notify-send -u critical -i "dialog-error" "SDDM Theme" "Failed to switch preset to: $SELECTED_PRESET"
        fi
    fi
fi
