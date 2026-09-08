#!/usr/bin/env bash
# ==================================================
#  KoolDots (2026)
#  Project URL: https://github.com/LinuxBeginnings
#  License: GNU GPLv3
#  SPDX-License-Identifier: GPL-3.0-or-later
# ==================================================
# For Dark and Light switching
# Note: Scripts are looking for keywords Light or Dark except for wallpapers as the are in a separate directories

# Paths
PICTURES_DIR="$(xdg-user-dir PICTURES 2>/dev/null || echo "$HOME/Pictures")"
wallpaper_base_path="$PICTURES_DIR/wallpapers/Dynamic-Wallpapers"
dark_wallpapers="$wallpaper_base_path/Dark"
light_wallpapers="$wallpaper_base_path/Light"
hypr_config_path="${XDG_CONFIG_HOME:-$HOME/.config}/hypr"
swaync_style="${XDG_CONFIG_HOME:-$HOME/.config}/swaync/style.css"
ags_style="${XDG_CONFIG_HOME:-$HOME/.config}/ags/user/style.css"
SCRIPTSDIR="${XDG_CONFIG_HOME:-$HOME/.config}/hypr/scripts"
# shellcheck source=/dev/null
. "$SCRIPTSDIR/WallpaperCmd.sh"

ensure_wayland_env() {
  local runtime_dir="${XDG_RUNTIME_DIR:-/run/user/$(id -u)}"
  if [ -z "${WAYLAND_DISPLAY:-}" ] || [ ! -S "$runtime_dir/$WAYLAND_DISPLAY" ]; then
    for socket in "$runtime_dir"/wayland-[0-9]*; do
      [ -S "$socket" ] || continue
      case "$(basename "$socket")" in
        *awww*) continue ;;
      esac
      export WAYLAND_DISPLAY="$(basename "$socket")"
      break
    done
  fi

  if [ -z "${HYPRLAND_INSTANCE_SIGNATURE:-}" ]; then
    for sig_dir in "$runtime_dir"/hypr/*/; do
      [ -S "${sig_dir}.socket.sock" ] || continue
      export HYPRLAND_INSTANCE_SIGNATURE="$(basename "$sig_dir")"
      break
    done
  fi
}
ensure_wayland_env
notif="${XDG_CONFIG_HOME:-$HOME/.config}/swaync/images/bell.png"
wallust_rofi="${XDG_CONFIG_HOME:-$HOME/.config}/wallust/templates/colors-rofi.rasi"
theme_state_dir="${XDG_STATE_HOME:-$HOME/.local/state}/hypr"
theme_state_file="$theme_state_dir/theme_mode"
legacy_theme_state_file="$HOME/.cache/.theme_mode"

user_kitty_conf="${XDG_CONFIG_HOME:-$HOME/.config}/hypr/UserConfigs/kitty.conf"
fallback_kitty_conf="${XDG_CONFIG_HOME:-$HOME/.config}/kitty/kitty.conf"
kitty_conf="$user_kitty_conf"

wallust_config="${XDG_CONFIG_HOME:-$HOME/.config}/wallust/wallust.toml"
pallete_dark="dark16"
pallete_light="light16"
qt5ct_dark="${XDG_CONFIG_HOME:-$HOME/.config}/qt5ct/colors/Catppuccin-Mocha.conf"
qt5ct_light="${XDG_CONFIG_HOME:-$HOME/.config}/qt5ct/colors/Catppuccin-Latte.conf"
qt6ct_dark="${XDG_CONFIG_HOME:-$HOME/.config}/qt6ct/colors/Catppuccin-Mocha.conf"
qt6ct_light="${XDG_CONFIG_HOME:-$HOME/.config}/qt6ct/colors/Catppuccin-Latte.conf"
apply_saved_mode=0
notify_enabled=1
preserve_wallpaper=0
forced_mode=""
no_restart=0

ensure_managed_kitty_conf() {
    if [[ -f "$user_kitty_conf" && -r "$user_kitty_conf" ]]; then
        kitty_conf="$user_kitty_conf"
        return 0
    fi

    if [[ -r "$fallback_kitty_conf" ]]; then
        mkdir -p "$(dirname "$user_kitty_conf")" 2>/dev/null || true
        cp -f "$fallback_kitty_conf" "$user_kitty_conf" 2>/dev/null || true
        if [[ -f "$user_kitty_conf" && -r "$user_kitty_conf" ]]; then
            kitty_conf="$user_kitty_conf"
            return 0
        fi
    fi

    kitty_conf="$fallback_kitty_conf"
}

normalize_mode() {
    case "$1" in
        Dark|Light) printf '%s' "$1" ;;
        *) printf '' ;;
    esac
}

read_saved_mode() {
    local mode=""
    if [ -f "$theme_state_file" ]; then
        mode="$(normalize_mode "$(tr -d '\r\n' < "$theme_state_file")")"
    fi
    if [ -z "$mode" ] && [ -f "$legacy_theme_state_file" ]; then
        mode="$(normalize_mode "$(tr -d '\r\n' < "$legacy_theme_state_file")")"
    fi
    [ -n "$mode" ] && printf '%s' "$mode" || printf 'Dark'
}

while [ $# -gt 0 ]; do
    case "$1" in
        --apply-current)
            apply_saved_mode=1
            ;;
        --mode)
            shift
            forced_mode="$(normalize_mode "${1:-}")"
            ;;
        --no-notify)
            notify_enabled=0
            ;;
        --preserve-wallpaper)
            preserve_wallpaper=1
            ;;
        --no-restart)
            no_restart=1
            ;;
        --help)
            cat <<'EOF'
Usage: DarkLight.sh [--apply-current] [--mode Dark|Light] [--no-notify] [--preserve-wallpaper] [--no-restart]
  (no args)            Toggle between Dark and Light and persist selection
  --apply-current      Re-apply saved mode (defaults to Dark when unset)
  --mode <mode>        Force target mode to Dark or Light
  --no-notify          Suppress notifications
  --preserve-wallpaper Keep current wallpaper instead of choosing random Dynamic-Wallpapers image
  --no-restart         Apply theme settings only; skip killing processes and running Refresh.sh
EOF
            exit 0
            ;;
    esac
    shift
done

# Signal running processes to prepare for theme change.
# Skip hiding waybar on startup (--no-restart) so it stays visible while colors regenerate.
if [ "$no_restart" -eq 0 ]; then
    for pid in waybar rofi swaync ags swaybg; do
        killall -SIGUSR1 "$pid"
    done
fi


# Initialize wallpaper daemon if needed
wallpaper_ensure_daemon

# Set swww options
swww="$WWW_CMD img"
effect="--transition-bezier .43,1.19,1,.4 --transition-fps 60 --transition-type grow --transition-pos 0.925,0.977 --transition-duration 2"

# Determine target theme mode
saved_mode="$(read_saved_mode)"
if [ -n "$forced_mode" ]; then
    next_mode="$forced_mode"
elif [ "$apply_saved_mode" -eq 1 ]; then
    next_mode="$saved_mode"
elif [ "$saved_mode" = "Light" ]; then
    next_mode="Dark"
else
    next_mode="Light"
fi
# Select Qt color scheme templates for the upcoming mode
if [ "$next_mode" = "Dark" ]; then
    wallpaper_path="$dark_wallpapers"
    qt5ct_color_scheme="$qt5ct_dark"
    qt6ct_color_scheme="$qt6ct_dark"
else
    wallpaper_path="$light_wallpapers"
    qt5ct_color_scheme="$qt5ct_light"
    qt6ct_color_scheme="$qt6ct_light"
fi

# Function to update theme mode for the next cycle
update_theme_mode() {
    mkdir -p "$theme_state_dir" "$HOME/.cache"
    echo "$next_mode" > "$theme_state_file"
    echo "$next_mode" > "$legacy_theme_state_file"
}

# Function to notify user
notify_user() {
    notify-send -u low -i "$notif" " Switching to" " $1 mode"
}

# Use sed to replace the palette setting in the wallust config files
if [ "$next_mode" = "Dark" ]; then
    sed -i 's/^palette = .*/palette = "'"$pallete_dark"'"/' "$wallust_config" 2>/dev/null || true
    [ -f "${XDG_CONFIG_HOME:-$HOME/.config}/wallust/wallust-v4.toml" ] && sed -i 's/^style = .*/style = "dark"/' "${XDG_CONFIG_HOME:-$HOME/.config}/wallust/wallust-v4.toml" 2>/dev/null || true
else
    sed -i 's/^palette = .*/palette = "'"$pallete_light"'"/' "$wallust_config" 2>/dev/null || true
    [ -f "${XDG_CONFIG_HOME:-$HOME/.config}/wallust/wallust-v4.toml" ] && sed -i 's/^style = .*/style = "light"/' "${XDG_CONFIG_HOME:-$HOME/.config}/wallust/wallust-v4.toml" 2>/dev/null || true
fi

# Function to set Waybar style
set_waybar_style() {
    local theme="$1"
    local waybar_styles="${XDG_CONFIG_HOME:-$HOME/.config}/hypr/waybar/style"
    local waybar_style_link="${XDG_CONFIG_HOME:-$HOME/.config}/hypr/waybar/style.css"

    # If re-applying saved mode on startup (--apply-current), do NOT change the user's existing style.css
    if [ "$apply_saved_mode" -eq 1 ]; then
        if [ -L "$waybar_style_link" ] || [ -f "$waybar_style_link" ]; then
            return 0
        fi
    fi

    # When toggling mode (Dark <-> Light), preserve style if valid or switch to matching counterpart
    if [ -L "$waybar_style_link" ]; then
        local current_style_target current_style_base counterpart
        current_style_target="$(readlink -f "$waybar_style_link" 2>/dev/null || true)"
        current_style_base="$(basename "$current_style_target" 2>/dev/null || true)"

        # Wallust, Chroma, and universal extra styles adapt automatically via colors-waybar.css; keep them
        if [[ "$current_style_base" =~ ^(Wallust|Chroma|\[Extra\]|Colored|Colorful|Crystal|Rainbow|Retro|Transparent) ]]; then
            return 0
        fi

        # Specific theme pairs
        if [ "$theme" = "Light" ]; then
            case "$current_style_base" in
                Catppuccin-Mocha.css|Catppuccin-Frappe.css|VERTICAL-Catpuccin-Mocha.css)
                    counterpart="Catppuccin-Latte.css" ;;
                Dark-Golden-Eclipse.css|Dark-Golden-Noir.css|Dark-Wallust-Obsidian-Edge.css|Dark-Half-Moon.css|Dark-Purpl.css)
                    counterpart="Light-Obsidian-Glow.css" ;;
                Black-\&-White-Monochrome.css)
                    counterpart="Light-Monochrome-Contrast.css" ;;
                *)
                    counterpart="${current_style_base//Dark/Light}"
                    counterpart="${counterpart//dark/light}"
                    ;;
            esac
        else
            case "$current_style_base" in
                Catppuccin-Latte.css)
                    counterpart="Catppuccin-Mocha.css" ;;
                Light-Obsidian-Glow.css)
                    counterpart="Dark-Wallust-Obsidian-Edge.css" ;;
                Light-Monochrome-Contrast.css)
                    counterpart="Black-&-White-Monochrome.css" ;;
                *)
                    counterpart="${current_style_base//Light/Dark}"
                    counterpart="${counterpart//light/dark}"
                    ;;
            esac
        fi

        if [ -n "$counterpart" ] && [ -f "$waybar_styles/$counterpart" ]; then
            ln -sf "$waybar_styles/$counterpart" "$waybar_style_link"
            return 0
        fi

        # Fallback if current style had Dark/Light prefix but no exact match
        if [ "$theme" = "Light" ] && [[ "$current_style_base" =~ ^Dark- ]]; then
            local fallback_light
            fallback_light="$(find -L "$waybar_styles" -maxdepth 1 -type f -iname 'Light-*.css' | sort | head -n 1)"
            if [ -n "$fallback_light" ]; then
                ln -sf "$fallback_light" "$waybar_style_link"
                return 0
            fi
        elif [ "$theme" = "Dark" ] && [[ "$current_style_base" =~ ^Light- ]]; then
            local fallback_dark
            fallback_dark="$(find -L "$waybar_styles" -maxdepth 1 -type f -iname 'Dark-*.css' | sort | head -n 1)"
            if [ -n "$fallback_dark" ]; then
                ln -sf "$fallback_dark" "$waybar_style_link"
                return 0
            fi
        fi

        return 0
    fi

    # Initial fallback if no style is set at all
    if [ ! -e "$waybar_style_link" ]; then
        local style_file
        style_file="$(find -L "$waybar_styles" -maxdepth 1 -type f \( -iname "${theme}-*.css" -o -iname "${theme}_*.css" -o -iname "[${theme}]*.css" -o -iname "${theme}*.css" \) | sort | head -n 1)"
        if [ -n "$style_file" ]; then
            ln -sf "$style_file" "$waybar_style_link"
        fi
    fi
}

# Call the function after determining the mode
set_waybar_style "$next_mode"
[ "$notify_enabled" -eq 1 ] && notify_user "$next_mode"


# swaync color change
if [ "$next_mode" = "Dark" ]; then
    sed -i '/@define-color noti-bg/s/rgba([0-9]*,\s*[0-9]*,\s*[0-9]*,\s*[0-9.]*);/rgba(0, 0, 0, 0.8);/' "${swaync_style}"
	#sed -i '/@define-color noti-bg-alt/s/#.*;/#111111;/' "${swaync_style}"
else
    sed -i '/@define-color noti-bg/s/rgba([0-9]*,\s*[0-9]*,\s*[0-9]*,\s*[0-9.]*);/rgba(255, 255, 255, 0.9);/' "${swaync_style}"
	#sed -i '/@define-color noti-bg-alt/s/#.*;/#F0F0F0;/' "${swaync_style}"
fi

# ags color change
if command -v ags >/dev/null 2>&1; then    
    if [ "$next_mode" = "Dark" ]; then
        sed -i '/@define-color noti-bg/s/rgba([0-9]*,\s*[0-9]*,\s*[0-9]*,\s*[0-9.]*);/rgba(0, 0, 0, 0.4);/' "${ags_style}"
	    sed -i '/@define-color text-color/s/rgba([0-9]*,\s*[0-9]*,\s*[0-9]*,\s*[0-9.]*);/rgba(255, 255, 255, 0.7);/' "${ags_style}" 
	    sed -i '/@define-color noti-bg-alt/s/#.*;/#111111;/' "${ags_style}"
    else
        sed -i '/@define-color noti-bg/s/rgba([0-9]*,\s*[0-9]*,\s*[0-9]*,\s*[0-9.]*);/rgba(255, 255, 255, 0.4);/' "${ags_style}"
        sed -i '/@define-color text-color/s/rgba([0-9]*,\s*[0-9]*,\s*[0-9]*,\s*[0-9.]*);/rgba(0, 0, 0, 0.7);/' "${ags_style}"
	    sed -i '/@define-color noti-bg-alt/s/#.*;/#F0F0F0;/' "${ags_style}"
    fi
fi

# kitty background color change
ensure_managed_kitty_conf
if [ "$next_mode" = "Dark" ]; then
    if [[ -w "$kitty_conf" ]]; then
        sed -i '/^foreground /s/^foreground .*/foreground #dddddd/' "${kitty_conf}"
	    sed -i '/^background /s/^background .*/background #000000/' "${kitty_conf}"
	    sed -i '/^cursor /s/^cursor .*/cursor #dddddd/' "${kitty_conf}"
    fi
else
    if [[ -w "$kitty_conf" ]]; then
	    sed -i '/^foreground /s/^foreground .*/foreground #000000/' "${kitty_conf}"
	    sed -i '/^background /s/^background .*/background #dddddd/' "${kitty_conf}"
	    sed -i '/^cursor /s/^cursor .*/cursor #000000/' "${kitty_conf}"
    fi
fi

for pid_kitty in $(pidof kitty); do
    kill -SIGUSR1 "$pid_kitty"
done

# Set Dynamic Wallpaper for Dark or Light Mode
if [ "$preserve_wallpaper" -eq 0 ]; then
    if [ "$next_mode" = "Dark" ]; then
        next_wallpaper="$(find -L "${dark_wallpapers}" -type f \( -iname "*.jpg" -o -iname "*.png" \) -print0 | shuf -n1 -z | xargs -0)"
    else
        next_wallpaper="$(find -L "${light_wallpapers}" -type f \( -iname "*.jpg" -o -iname "*.png" \) -print0 | shuf -n1 -z | xargs -0)"
    fi

    # Update wallpaper using swww command
    $swww "${next_wallpaper}" $effect
fi


# Set Kvantum Manager theme & QT5/QT6 settings
if [ "$next_mode" = "Dark" ]; then
    kvantum_theme="catppuccin-mocha-blue"
    #qt5ct_color_scheme="${XDG_CONFIG_HOME:-$HOME/.config}/qt5ct/colors/Catppuccin-Mocha.conf"
    #qt6ct_color_scheme="${XDG_CONFIG_HOME:-$HOME/.config}/qt6ct/colors/Catppuccin-Mocha.conf"
else
    kvantum_theme="catppuccin-latte-blue"
    #qt5ct_color_scheme="${XDG_CONFIG_HOME:-$HOME/.config}/qt5ct/colors/Catppuccin-Latte.conf"
    #qt6ct_color_scheme="${XDG_CONFIG_HOME:-$HOME/.config}/qt6ct/colors/Catppuccin-Latte.conf"
fi

sed -i "s|^color_scheme_path=.*$|color_scheme_path=$qt5ct_color_scheme|" "${XDG_CONFIG_HOME:-$HOME/.config}/qt5ct/qt5ct.conf"
sed -i "s|^color_scheme_path=.*$|color_scheme_path=$qt6ct_color_scheme|" "${XDG_CONFIG_HOME:-$HOME/.config}/qt6ct/qt6ct.conf"
kvantummanager --set "$kvantum_theme"


# set the rofi color for background
if [ "$next_mode" = "Dark" ]; then
    sed -i '/^background:/s/.*/background: rgba(0,0,0,0.7);/' $wallust_rofi
else
    sed -i '/^background:/s/.*/background: rgba(255,255,255,0.9);/' $wallust_rofi
fi


read_user_env_var() {
    local var_name="$1"
    local val=""
    local user_env_lua="${XDG_CONFIG_HOME:-$HOME/.config}/hypr/UserConfigs/user_env.lua"
    local user_env_conf="${XDG_CONFIG_HOME:-$HOME/.config}/hypr/UserConfigs/ENVariables.conf"

    if [ -f "$user_env_lua" ]; then
        val=$(sed -nE 's/^[[:space:]]*hl\.env\([[:space:]]*["'"'"']'"$var_name"'["'"'"'][[:space:]]*,[[:space:]]*["'"'"']([^"'"'"']+)["'"'"'].*/\1/p' "$user_env_lua" | tail -n1)
    fi
    if [ -z "$val" ] && [ -f "$user_env_conf" ]; then
        val=$(sed -nE 's/^[[:space:]]*env[[:space:]]*=[[:space:]]*'"$var_name"'[[:space:]]*,[[:space:]]*([^#[:space:]]+).*/\1/p' "$user_env_conf" | tail -n1)
    fi
    if [ -z "$val" ]; then
        val="${!var_name:-}"
    fi
    printf '%s' "$val"
}

# GTK themes and icons switching
set_custom_gtk_theme() {
    local mode=$1
    local color_setting="org.gnome.desktop.interface color-scheme"
    local theme_setting="org.gnome.desktop.interface gtk-theme"
    local icon_setting="org.gnome.desktop.interface icon-theme"

    local prefer_dark=1
    if [ "$mode" == "Light" ]; then
        prefer_dark=0
        gsettings set $color_setting 'prefer-light' 2>/dev/null || true
    elif [ "$mode" == "Dark" ]; then
        prefer_dark=1
        gsettings set $color_setting 'prefer-dark' 2>/dev/null || true
    fi

    # 1. Check for explicit user environment overrides from user_env.lua / ENVariables.conf / environment
    local override_theme override_icon
    override_theme="$(read_user_env_var "GTK_THEME")"
    override_icon="$(read_user_env_var "ICON_THEME")"
    [ -z "$override_icon" ] && override_icon="$(read_user_env_var "GTK_ICON_THEME")"

    local selected_theme=""
    local selected_icon=""

    [ -n "$override_theme" ] && selected_theme="$override_theme"
    [ -n "$override_icon" ] && selected_icon="$override_icon"

    # 2. Read current theme/icon configured in GSettings, settings.ini, or xsettingsd (e.g. set by nwg-look)
    local current_gtk_theme=""
    current_gtk_theme="$(gsettings get $theme_setting 2>/dev/null | tr -d \"\'\" || true)"
    if [ -z "$current_gtk_theme" ] && [ -f "${XDG_CONFIG_HOME:-$HOME/.config}/gtk-3.0/settings.ini" ]; then
        current_gtk_theme="$(sed -n 's/^[[:space:]]*gtk-theme-name[[:space:]]*=[[:space:]]*//p' "${XDG_CONFIG_HOME:-$HOME/.config}/gtk-3.0/settings.ini" | head -n1)"
    fi
    if [ -z "$current_gtk_theme" ] && [ -f "${XDG_CONFIG_HOME:-$HOME/.config}/xsettingsd/xsettingsd.conf" ]; then
        current_gtk_theme="$(sed -n 's/^[[:space:]]*Net\/ThemeName[[:space:]]*"\(.*\)"/\1/p' "${XDG_CONFIG_HOME:-$HOME/.config}/xsettingsd/xsettingsd.conf" | head -n1)"
    fi

    local current_icon_theme=""
    current_icon_theme="$(gsettings get $icon_setting 2>/dev/null | tr -d \"\'\" || true)"
    if [ -z "$current_icon_theme" ] && [ -f "${XDG_CONFIG_HOME:-$HOME/.config}/gtk-3.0/settings.ini" ]; then
        current_icon_theme="$(sed -n 's/^[[:space:]]*gtk-icon-theme-name[[:space:]]*=[[:space:]]*//p' "${XDG_CONFIG_HOME:-$HOME/.config}/gtk-3.0/settings.ini" | head -n1)"
    fi
    if [ -z "$current_icon_theme" ] && [ -f "${XDG_CONFIG_HOME:-$HOME/.config}/xsettingsd/xsettingsd.conf" ]; then
        current_icon_theme="$(sed -n 's/^[[:space:]]*Net\/IconThemeName[[:space:]]*"\(.*\)"/\1/p' "${XDG_CONFIG_HOME:-$HOME/.config}/xsettingsd/xsettingsd.conf" | head -n1)"
    fi

    # 3. If applying saved mode on startup (--apply-current), PRESERVE existing themes from nwg-look/settings.ini
    if [ "$apply_saved_mode" -eq 1 ]; then
        [ -z "$selected_theme" ] && selected_theme="$current_gtk_theme"
        [ -z "$selected_icon" ] && selected_icon="$current_icon_theme"
    fi

    # 4. When toggling Dark <-> Light, find matching counterpart if one exists
    if [ -z "$selected_theme" ] && [ -n "$current_gtk_theme" ]; then
        local counterpart=""
        if [ "$mode" == "Light" ]; then
            case "$current_gtk_theme" in
                *Dark|*dark|*-dark|*-Dark)
                    counterpart="${current_gtk_theme//-dark/-light}"
                    counterpart="${counterpart//-Dark/-Light}"
                    counterpart="${counterpart//dark/light}"
                    counterpart="${counterpart//Dark/Light}"
                    ;;
                Catppuccin-Mocha*|Catppuccin-Frappe*)
                    counterpart="${current_gtk_theme//Catppuccin-Mocha/Catppuccin-Latte}"
                    counterpart="${counterpart//Catppuccin-Frappe/Catppuccin-Latte}"
                    ;;
            esac
        else
            case "$current_gtk_theme" in
                *Light|*light|*-light|*-Light)
                    counterpart="${current_gtk_theme//-light/-dark}"
                    counterpart="${counterpart//-Light/-Dark}"
                    counterpart="${counterpart//light/dark}"
                    counterpart="${counterpart//Light/Dark}"
                    ;;
                Catppuccin-Latte*)
                    counterpart="${current_gtk_theme//Catppuccin-Latte/Catppuccin-Mocha}"
                    ;;
            esac
        fi

        if [ -n "$counterpart" ]; then
            for tdir in "$HOME/.themes" "$HOME/.local/share/themes" "/usr/share/themes"; do
                if [ -d "$tdir/$counterpart" ]; then
                    selected_theme="$counterpart"
                    break
                fi
            done
        fi
        # If no counterpart exists (e.g. Nordic, Dracula), keep current theme
        [ -z "$selected_theme" ] && selected_theme="$current_gtk_theme"
    fi

    # 5. Initial fallback if still empty
    if [ -z "$selected_theme" ]; then
        local search_keywords="*Dark*"
        [ "$mode" == "Light" ] && search_keywords="*Light*"
        local -a theme_search_dirs=("$HOME/.themes" "$HOME/.local/share/themes" "/usr/share/themes")
        local -a themes=()
        for dir in "${theme_search_dirs[@]}"; do
            if [ -d "$dir" ]; then
                while IFS= read -r -d '' theme_search; do
                    if [ -d "$theme_search/gtk-3.0" ] || [ -d "$theme_search/gtk-4.0" ]; then
                        local t_name
                        t_name="$(basename "$theme_search")"
                        [[ " ${themes[*]} " =~ " ${t_name} " ]] || themes+=("$t_name")
                    fi
                done < <(find "$dir" -maxdepth 1 -type d -iname "$search_keywords" -print0 2>/dev/null)
            fi
        done
        if [ ${#themes[@]} -gt 0 ]; then
            selected_theme="${themes[0]}"
        else
            [ "$mode" == "Dark" ] && selected_theme="Adwaita-dark" || selected_theme="Adwaita"
        fi
    fi

    # 6. Icon theme: keep current or fallback
    if [ -z "$selected_icon" ]; then
        [ -n "$current_icon_theme" ] && selected_icon="$current_icon_theme"
    fi
    if [ -z "$selected_icon" ]; then
        local -a icon_search_dirs=("$HOME/.icons" "$HOME/.local/share/icons" "/usr/share/icons")
        local -a icons=()
        for dir in "${icon_search_dirs[@]}"; do
            if [ -d "$dir" ]; then
                while IFS= read -r -d '' icon_search; do
                    local i_name
                    i_name="$(basename "$icon_search")"
                    [[ " ${icons[*]} " =~ " ${i_name} " ]] || icons+=("$i_name")
                done < <(find "$dir" -maxdepth 1 -type d -iname "*Dark*" -print0 2>/dev/null)
            fi
        done
        if [ ${#icons[@]} -gt 0 ]; then
            selected_icon="${icons[0]}"
        fi
    fi

    echo "Selected GTK theme for $mode mode: $selected_theme"
    [ -n "$selected_theme" ] && gsettings set $theme_setting "$selected_theme" 2>/dev/null || true

    # Flatpak GTK apps (themes)
    if command -v flatpak &> /dev/null; then
        flatpak --user override --filesystem=$HOME/.themes 2>/dev/null || true
        [ -n "$selected_theme" ] && flatpak --user override --env=GTK_THEME="$selected_theme" 2>/dev/null || true
    fi

    if [ -n "$selected_icon" ]; then
        echo "Selected icon theme for $mode mode: $selected_icon"
        gsettings set $icon_setting "$selected_icon" 2>/dev/null || true

        ## QT5ct / QT6ct icon_theme
        sed -i "s|^icon_theme=.*$|icon_theme=$selected_icon|" "${XDG_CONFIG_HOME:-$HOME/.config}/qt5ct/qt5ct.conf" 2>/dev/null || true
        sed -i "s|^icon_theme=.*$|icon_theme=$selected_icon|" "${XDG_CONFIG_HOME:-$HOME/.config}/qt6ct/qt6ct.conf" 2>/dev/null || true

        # Flatpak GTK apps (icons)
        if command -v flatpak &> /dev/null; then
            flatpak --user override --filesystem=$HOME/.icons 2>/dev/null || true
            flatpak --user override --env=ICON_THEME="$selected_icon" 2>/dev/null || true
        fi
    fi

    # Sync GTK 3.0 & 4.0 settings.ini for non-GNOME / standalone GTK apps (e.g. Thunar)
    for gtk_dir in "${XDG_CONFIG_HOME:-$HOME/.config}/gtk-3.0" "${XDG_CONFIG_HOME:-$HOME/.config}/gtk-4.0"; do
        mkdir -p "$gtk_dir"
        local ini_file="$gtk_dir/settings.ini"
        if [ ! -f "$ini_file" ]; then
            printf '[Settings]\ngtk-theme-name=%s\ngtk-icon-theme-name=%s\ngtk-application-prefer-dark-theme=%d\n' "$selected_theme" "$selected_icon" "$prefer_dark" > "$ini_file"
        else
            grep -q '^\\[Settings\\]' "$ini_file" || sed -i '1i\\[Settings\\]' "$ini_file"
            if [ -n "$selected_theme" ]; then
                if grep -q '^gtk-theme-name=' "$ini_file"; then
                    sed -i "s|^gtk-theme-name=.*$|gtk-theme-name=$selected_theme|" "$ini_file"
                else
                    echo "gtk-theme-name=$selected_theme" >> "$ini_file"
                fi
            fi
            if [ -n "$selected_icon" ]; then
                if grep -q '^gtk-icon-theme-name=' "$ini_file"; then
                    sed -i "s|^gtk-icon-theme-name=.*$|gtk-icon-theme-name=$selected_icon|" "$ini_file"
                else
                    echo "gtk-icon-theme-name=$selected_icon" >> "$ini_file"
                fi
            fi
            if grep -q '^gtk-application-prefer-dark-theme=' "$ini_file"; then
                sed -i "s|^gtk-application-prefer-dark-theme=.*$|gtk-application-prefer-dark-theme=$prefer_dark|" "$ini_file"
            else
                echo "gtk-application-prefer-dark-theme=$prefer_dark" >> "$ini_file"
            fi
        fi
    done

    # Sync xsettingsd if present
    if [ -f "${XDG_CONFIG_HOME:-$HOME/.config}/xsettingsd/xsettingsd.conf" ]; then
        [ -n "$selected_theme" ] && sed -i "s|^Net/ThemeName .*$|Net/ThemeName \"$selected_theme\"|" "${XDG_CONFIG_HOME:-$HOME/.config}/xsettingsd/xsettingsd.conf" 2>/dev/null || true
        [ -n "$selected_icon" ] && sed -i "s|^Net/IconThemeName .*$|Net/IconThemeName \"$selected_icon\"|" "${XDG_CONFIG_HOME:-$HOME/.config}/xsettingsd/xsettingsd.conf" 2>/dev/null || true
        touch "${XDG_CONFIG_HOME:-$HOME/.config}/gtk-3.0/gtk.css" 2>/dev/null || true
        killall -HUP xsettingsd 2>/dev/null || true
    fi
}

# Call the function to set GTK theme and icon theme based on mode
set_custom_gtk_theme "$next_mode"

# Update theme mode for the next cycle
update_theme_mode


${SCRIPTSDIR}/WallustSwww.sh "${next_wallpaper:-$wallpaper_current}"

if [ "$no_restart" -eq 0 ]; then
    sleep 2
    # kill process
    # NOTE: waybar is deliberately excluded here. This script is usually launched from a
    # waybar module on-click, so it lives in waybar.service's cgroup. Killing waybar makes
    # systemd tear down the whole unit, taking this script with it before Refresh.sh runs.
    # Refresh.sh restarts waybar detached from that cgroup instead.
    for pid1 in rofi swaync ags swaybg; do
        killall "$pid1"
    done
    sleep 1
    ${SCRIPTSDIR}/Refresh.sh
    sleep 0.5
else
    # Reload waybar in-place so it picks up the newly generated wallust colors.
    # SIGUSR2 = reload config/CSS without restarting the process.
    systemctl --user reload waybar.service 2>/dev/null || killall -SIGUSR2 waybar 2>/dev/null || true
fi

# Display notifications for theme and icon changes
[ "$notify_enabled" -eq 1 ] && notify-send -u low -i "$notif" " Themes switched to:" " $next_mode Mode"

exit 0

