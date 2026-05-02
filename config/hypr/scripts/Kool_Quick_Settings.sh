#!/usr/bin/env bash
# ==================================================
#  KoolDots (2026)
#  Project URL: https://github.com/LinuxBeginnings
#  License: GNU GPLv3
#  SPDX-License-Identifier: GPL-3.0-or-later
# ==================================================
# Rofi menu for KooL Hyprland Quick Settings (SUPER SHIFT E)
# Updated for UserConfigs/configs separation

# Detect active Hyprland config mode (Lua entrypoint vs legacy .conf includes)
config_home="${XDG_CONFIG_HOME:-$HOME/.config}"
hypr_dir="$config_home/hypr"
lua_entry="$hypr_dir/hyprland.lua"
legacy_lua_entry="$config_home/hyprland.lua"
if [[ -f "$lua_entry" || -f "$legacy_lua_entry" ]]; then
    hypr_config_mode="lua"
else
    hypr_config_mode="conf"
fi

# Resolve defaults file used to get terminal/editor values
config_file="$hypr_dir/UserConfigs/01-UserDefaults.conf"
lua_defaults_file="$hypr_dir/lua/user_defaults.lua"
term="${term:-${TERM:-kitty}}"
edit="${edit:-${EDITOR:-nano}}"

if [[ "$hypr_config_mode" == "conf" && -f "$config_file" ]]; then
    tmp_config_file=$(mktemp)
    sed 's/^\$//g; s/ = /=/g' "$config_file" > "$tmp_config_file"
    source "$tmp_config_file"
elif [[ "$hypr_config_mode" == "lua" && -f "$lua_defaults_file" ]]; then
    lua_term=$(sed -n 's/^[[:space:]]*KOOLDOTS_DEFAULTS\.term[[:space:]]*=[[:space:]]*"\(.*\)"[[:space:]]*$/\1/p' "$lua_defaults_file" | tail -n1)
    lua_edit=$(sed -n 's/^[[:space:]]*KOOLDOTS_DEFAULTS\.edit[[:space:]]*=[[:space:]]*"\(.*\)"[[:space:]]*$/\1/p' "$lua_defaults_file" | tail -n1)
    [[ -n "$lua_term" ]] && term="$lua_term"
    [[ -n "$lua_edit" ]] && edit="$lua_edit"
fi
# ##################################### #

# variables
configs="$hypr_dir/configs"
UserConfigs="$hypr_dir/UserConfigs"
lua_configs="$hypr_dir/lua"
rofi_theme="$HOME/.config/rofi/config-edit.rasi"
msg=' ⁉️ Choose what to do ⁉️'
iDIR="$HOME/.config/swaync/images"
scriptsDir="$hypr_dir/scripts"
UserScripts="$hypr_dir/UserScripts"

# Function to show info notification
show_info() {
    if [[ -f "$iDIR/info.png" ]]; then
        notify-send -i "$iDIR/info.png" "Info" "$1"
    else
        notify-send "Info" "$1"
    fi
}
# Function to toggle Rainbow Borders script availability and refresh UI components
toggle_rainbow_borders() {
    local rainbow_script="$UserScripts/RainbowBorders.sh"
    local disabled_sh_bak="${rainbow_script}.bak"           # RainbowBorders.sh.bak
    local disabled_bak_sh="$UserScripts/RainbowBorders.bak.sh" # RainbowBorders.bak.sh (created by copy.sh when disabled)
    local refresh_script="$scriptsDir/Refresh.sh"
    local status=""

    # If both disabled variants exist, keep the newer one to avoid ambiguity
    if [[ -f "$disabled_sh_bak" && -f "$disabled_bak_sh" ]]; then
        if [[ "$disabled_sh_bak" -nt "$disabled_bak_sh" ]]; then
            rm -f "$disabled_bak_sh"
        else
            rm -f "$disabled_sh_bak"
        fi
    fi

    if [[ -f "$rainbow_script" ]]; then
        # Currently enabled -> disable to canonical .sh.bak
        if mv "$rainbow_script" "$disabled_sh_bak"; then
            status="disabled"
            if command -v hyprctl &>/dev/null; then
                hyprctl reload >/dev/null 2>&1 || true
            fi
        fi
    elif [[ -f "$disabled_sh_bak" ]]; then
        # Disabled (.sh.bak) -> enable
        if mv "$disabled_sh_bak" "$rainbow_script"; then
            status="enabled"
        fi
    elif [[ -f "$disabled_bak_sh" ]]; then
        # Disabled (.bak.sh) -> enable (normalize to .sh)
        if mv "$disabled_bak_sh" "$rainbow_script"; then
            status="enabled"
        fi
    else
        show_info "RainbowBorders script not found in $UserScripts (checked .sh, .sh.bak, .bak.sh)."
        return
    fi

    # Run refresh if available, otherwise apply borders directly
    if [[ -x "$refresh_script" ]]; then
        "$refresh_script" >/dev/null 2>&1 &
    elif [[ "$current" != "disabled" && -x "$rainbow_script" ]]; then
        "$rainbow_script" >/dev/null 2>&1 &
    fi

    if [[ -n "$status" ]]; then
        show_info "Rainbow Borders ${status}."
    fi
}

# Submenu to choose Rainbow Borders mode (disable, wallust_random, rainbow, gradient_flow)
rainbow_borders_menu() {
    local rainbow_script="$UserScripts/RainbowBorders.sh"
    local disabled_sh_bak="${rainbow_script}.bak"
    local disabled_bak_sh="$UserScripts/RainbowBorders.bak.sh"
    local refresh_script="$scriptsDir/Refresh.sh"

    # Determine current mode/status (internal)
    local current="disabled"
    if [[ -f "$rainbow_script" ]]; then
        current=$(grep -E '^EFFECT_TYPE=' "$rainbow_script" 2>/dev/null | sed -E 's/^EFFECT_TYPE="?([^"]*)"?/\1/')
        [[ -z "$current" ]] && current="unknown"
    fi

    # Map internal mode to friendly display
    local current_display="$current"
    case "$current" in
        wallust_random) current_display="Wallust Color" ;;
        rainbow) current_display="Original Rainbow" ;;
        gradient_flow) current_display="Gradient Flow" ;;
        disabled) current_display="Disabled" ;;
    esac


    # Build options and prompt
    local options="Disable Rainbow Borders\nWallust Color\nOriginal Rainbow\nGradient Flow"
    local choice
    choice=$(printf "%b" "$options" | rofi -i -dmenu -config "$rofi_theme" -mesg "Rainbow Borders: current = $current_display")

    [[ -z "$choice" ]] && return

    local previous="$current"

    case "$choice" in
        "Disable Rainbow Borders")
            if [[ -f "$rainbow_script" ]]; then
                mv "$rainbow_script" "$disabled_sh_bak"
            fi
            current="disabled"
            if command -v hyprctl &>/dev/null; then
                hyprctl reload >/dev/null 2>&1 || true
            fi
            ;;
        "Wallust Color"|"Original Rainbow"|"Gradient Flow")
            local mode=""
            case "$choice" in
                "Wallust Color") mode="wallust_random" ;;
                "Original Rainbow") mode="rainbow" ;;
                "Gradient Flow") mode="gradient_flow" ;;
            esac
            # Ensure script is enabled
            if [[ ! -f "$rainbow_script" ]]; then
                if   [[ -f "$disabled_sh_bak" ]]; then
                    mv "$disabled_sh_bak" "$rainbow_script"
                elif [[ -f "$disabled_bak_sh" ]]; then
                    mv "$disabled_bak_sh" "$rainbow_script"
                else
                    show_info "RainbowBorders script not found in $UserScripts."
                    return
                fi
            fi

            # Update EFFECT_TYPE in place; insert if missing
            if grep -q '^EFFECT_TYPE=' "$rainbow_script" 2>/dev/null; then
                sed -i 's/^EFFECT_TYPE=.*/EFFECT_TYPE="'"$mode"'"/' "$rainbow_script"
            else
                if head -n1 "$rainbow_script" | grep -q '^#!'; then
                    sed -i '1a EFFECT_TYPE="'"$mode"'"' "$rainbow_script"
                else
                    sed -i '1i EFFECT_TYPE="'"$mode"'"' "$rainbow_script"
                fi
            fi
            # Set current to chosen mode
            current="$mode"
            ;;
        *)
            return ;;
    esac

    # Run refresh if available
    if [[ -x "$refresh_script" ]]; then
        "$refresh_script" >/dev/null 2>&1 &
    fi

    # Apply mode immediately (in case refresh doesn't trigger it)
    if [[ "$current" != "disabled" && -x "$rainbow_script" ]]; then
        "$rainbow_script" >/dev/null 2>&1 &
    fi

    # No notifications; mode is shown in the menu
}

# Function to display the menu options without numbers
menu() {
    cat <<EOF
--- USER CUSTOMIZATIONS ---
Edit User Defaults
Edit User Keybinds
Edit User ENV variables
Edit User Startup Apps (overlay)
Edit User Window Rules (overlay)
Edit User Settings
Edit User Decorations
Edit User Animations
Edit User Laptop Settings
--- SYSTEM DEFAULTS  ---
Edit System Default Keybinds
Edit System Default Startup Apps
Edit System Default Window Rules
Edit System Default Settings
--- UTILITIES ---
Set SDDM Wallpaper
Choose Kitty Terminal Theme
Choose Ghostty Terminal Theme
Configure Monitors (nwg-displays)
Configure Workspace Rules (nwg-displays)
GTK Settings (nwg-look)
QT Apps Settings (qt6ct)
QT Apps Settings (qt5ct)
Choose Hyprland Animations
Choose Monitor Profiles
Choose Rofi Themes
Search for Keybinds
Toggle Waybar Weather units (C/F)
Toggle Game Mode
Switch Dark-Light Theme
Rainbow Borders Mode
EOF
}

# Main function to handle menu selection
main() {
    choice=$(menu | rofi -i -dmenu -config $rofi_theme -mesg "$msg")
    
    # Map choices to corresponding files
    case "$choice" in
    	"Edit User Defaults")
            if [[ "$hypr_config_mode" == "lua" ]]; then file="$lua_configs/user_defaults.lua"; else file="$UserConfigs/01-UserDefaults.conf"; fi ;;
        "Edit User ENV variables")
            if [[ "$hypr_config_mode" == "lua" ]]; then file="$UserConfigs/user_env.lua"; else file="$UserConfigs/ENVariables.conf"; fi ;;
        "Edit User Keybinds")
            if [[ "$hypr_config_mode" == "lua" ]]; then file="$UserConfigs/user_keybinds.lua"; else file="$UserConfigs/UserKeybinds.conf"; fi ;;
        "Edit User Startup Apps (overlay)")
            if [[ "$hypr_config_mode" == "lua" ]]; then file="$UserConfigs/user_startup.lua"; else file="$UserConfigs/Startup_Apps.conf"; fi ;;
        "Edit User Window Rules (overlay)")
            if [[ "$hypr_config_mode" == "lua" ]]; then file="$UserConfigs/user_window_rules.lua"; else file="$UserConfigs/WindowRules.conf"; fi ;;
        "Edit User Settings")
            if [[ "$hypr_config_mode" == "lua" ]]; then
                file="$UserConfigs/user_settings.lua"
                show_info "Lua mode detected. Edit UserConfigs/user_settings.lua for user settings."
            else
                file="$configs/SystemSettings.conf"
                show_info "Editing default settings. Copy to UserConfigs/UserSettings.conf to override."
            fi ;;
        "Edit User Decorations")
            if [[ "$hypr_config_mode" == "lua" ]]; then file="$UserConfigs/user_decorations.lua"; else file="$UserConfigs/UserDecorations.conf"; fi ;;
        "Edit User Animations")
            if [[ "$hypr_config_mode" == "lua" ]]; then file="$UserConfigs/user_animations.lua"; else file="$UserConfigs/UserAnimations.conf"; fi ;;
        "Edit User Laptop Settings")
            if [[ "$hypr_config_mode" == "lua" ]]; then file="$UserConfigs/user_laptops.lua"; else file="$UserConfigs/Laptops.conf"; fi ;;
        "Edit System Default Keybinds")
            if [[ "$hypr_config_mode" == "lua" ]]; then file="$UserConfigs/system_keybinds.lua"; else file="$configs/Keybinds.conf"; fi ;;
        "Edit System Default Startup Apps")
            if [[ "$hypr_config_mode" == "lua" ]]; then file="$UserConfigs/system_startup.lua"; else file="$configs/Startup_Apps.conf"; fi ;;
        "Edit System Default Window Rules")
            if [[ "$hypr_config_mode" == "lua" ]]; then file="$UserConfigs/system_window_rules.lua"; else file="$configs/WindowRules.conf"; fi ;;
        "Edit System Default Settings")
            if [[ "$hypr_config_mode" == "lua" ]]; then file="$UserConfigs/system_settings.lua"; else file="$configs/SystemSettings.conf"; fi ;;
        "Set SDDM Wallpaper") $scriptsDir/sddm_wallpaper.sh --normal ;;
        "Choose Kitty Terminal Theme") $scriptsDir/Kitty_themes.sh ;;
        "Choose Ghostty Terminal Theme") $scriptsDir/Ghostty_themes.sh ;;
        "Configure Monitors (nwg-displays)") 
            if ! command -v nwg-displays &>/dev/null; then
                notify-send -i "$iDIR/error.png" "E-R-R-O-R" "Install nwg-displays first"
                exit 1
            fi
            nwg-displays ;;
        "Configure Workspace Rules (nwg-displays)") 
            if ! command -v nwg-displays &>/dev/null; then
                notify-send -i "$iDIR/error.png" "E-R-R-O-R" "Install nwg-displays first"
                exit 1
            fi
            nwg-displays ;;
		"GTK Settings (nwg-look)") 
            if ! command -v nwg-look &>/dev/null; then
                notify-send -i "$iDIR/error.png" "E-R-R-O-R" "Install nwg-look first"
                exit 1
            fi
            nwg-look ;;
		"QT Apps Settings (qt6ct)") 
            if ! command -v qt6ct &>/dev/null; then
                notify-send -i "$iDIR/error.png" "E-R-R-O-R" "Install qt6ct first"
                exit 1
            fi
            qt6ct ;;
		"QT Apps Settings (qt5ct)") 
            if ! command -v qt5ct &>/dev/null; then
                notify-send -i "$iDIR/error.png" "E-R-R-O-R" "Install qt5ct first"
                exit 1
            fi
            qt5ct ;;
        "Choose Hyprland Animations") $scriptsDir/Animations.sh ;;
        "Choose Monitor Profiles") $scriptsDir/MonitorProfiles.sh ;;
        "Choose Rofi Themes") $scriptsDir/RofiThemeSelector.sh ;;
        "Search for Keybinds") $scriptsDir/KeyBinds.sh ;;
        "Toggle Waybar Weather units (C/F)") $scriptsDir/Toggle-weather-waybar-units.sh ;;
        "Toggle Game Mode") $scriptsDir/GameMode.sh ;;
        "Switch Dark-Light Theme") $scriptsDir/DarkLight.sh ;;
        "Rainbow Borders Mode") rainbow_borders_menu ;;
        *) return ;;  # Do nothing for invalid choices
    esac

    # Open the selected file in the terminal with the text editor
    if [ -n "$file" ]; then
        $term -e $edit "$file"
    fi
}

# Check if rofi is already running
if pidof rofi > /dev/null; then
  pkill rofi
fi

main
