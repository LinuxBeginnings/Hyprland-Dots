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
        --help)
            cat <<'EOF'
Usage: DarkLight.sh [--apply-current] [--mode Dark|Light] [--no-notify] [--preserve-wallpaper]
  (no args)            Toggle between Dark and Light and persist selection
  --apply-current      Re-apply saved mode (defaults to Dark when unset)
  --mode <mode>        Force target mode to Dark or Light
  --no-notify          Suppress notifications
  --preserve-wallpaper Keep current wallpaper instead of choosing random Dynamic-Wallpapers image
EOF
            exit 0
            ;;
    esac
    shift
done

# intial kill process
for pid in waybar rofi swaync ags swaybg; do
    killall -SIGUSR1 "$pid"
done


# Initialize wallpaper daemon if needed
"$WWW_CMD" query || "$WWW_DAEMON" "${WWW_DAEMON_ARGS[@]}"

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

# Use sed to replace the palette setting in the wallust config file
if [ "$next_mode" = "Dark" ]; then
    sed -i 's/^palette = .*/palette = "'"$pallete_dark"'"/' "$wallust_config" 
else
    sed -i 's/^palette = .*/palette = "'"$pallete_light"'"/' "$wallust_config" 
fi

# Function to set Waybar style
set_waybar_style() {
    theme="$1"
    waybar_styles="${XDG_CONFIG_HOME:-$HOME/.config}/waybar/style"
    waybar_style_link="${XDG_CONFIG_HOME:-$HOME/.config}/waybar/style.css"
    style_prefix="\\[${theme}\\].*\\.css$"

    style_file=$(find -L "$waybar_styles" -maxdepth 1 -type f -regex ".*$style_prefix" | shuf -n 1)

    if [ -n "$style_file" ]; then
        ln -sf "$style_file" "$waybar_style_link"
    else
        echo "Style file not found for $theme theme."
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


# GTK themes and icons switching
set_custom_gtk_theme() {
    mode=$1
    gtk_themes_directory="$HOME/.themes"
    icon_directory="$HOME/.icons"
    color_setting="org.gnome.desktop.interface color-scheme"
    theme_setting="org.gnome.desktop.interface gtk-theme"
    icon_setting="org.gnome.desktop.interface icon-theme"

    if [ "$mode" == "Light" ]; then
        search_keywords="*Light*"
        gsettings set $color_setting 'prefer-light'
    elif [ "$mode" == "Dark" ]; then
        search_keywords="*Dark*"
        gsettings set $color_setting 'prefer-dark'
    else
        echo "Invalid mode provided."
        return 1
    fi

    themes=()
    icons=()

    while IFS= read -r -d '' theme_search; do
        themes+=("$(basename "$theme_search")")
    done < <(find "$gtk_themes_directory" -maxdepth 1 -type d -iname "$search_keywords" -print0)

    while IFS= read -r -d '' icon_search; do
        icons+=("$(basename "$icon_search")")
    done < <(find "$icon_directory" -maxdepth 1 -type d -iname "$search_keywords" -print0)

    if [ ${#themes[@]} -gt 0 ]; then
        if [ "$mode" == "Dark" ]; then
            selected_theme=${themes[RANDOM % ${#themes[@]}]}
        else
            selected_theme=${themes[$RANDOM % ${#themes[@]}]}
        fi
        echo "Selected GTK theme for $mode mode: $selected_theme"
        gsettings set $theme_setting "$selected_theme"

        # Flatpak GTK apps (themes)
        if command -v flatpak &> /dev/null; then
            flatpak --user override --filesystem=$HOME/.themes
            sleep 0.5
            flatpak --user override --env=GTK_THEME="$selected_theme"
        fi
    else
        echo "No $mode GTK theme found"
    fi

    if [ ${#icons[@]} -gt 0 ]; then
        if [ "$mode" == "Dark" ]; then
            selected_icon=${icons[RANDOM % ${#icons[@]}]}
        else
            selected_icon=${icons[$RANDOM % ${#icons[@]}]}
        fi
        echo "Selected icon theme for $mode mode: $selected_icon"
        gsettings set $icon_setting "$selected_icon"
        
        ## QT5ct icon_theme
        sed -i "s|^icon_theme=.*$|icon_theme=$selected_icon|" "${XDG_CONFIG_HOME:-$HOME/.config}/qt5ct/qt5ct.conf"
        sed -i "s|^icon_theme=.*$|icon_theme=$selected_icon|" "${XDG_CONFIG_HOME:-$HOME/.config}/qt6ct/qt6ct.conf"

        # Flatpak GTK apps (icons)
        if command -v flatpak &> /dev/null; then
            flatpak --user override --filesystem=$HOME/.icons
            sleep 0.5
            flatpak --user override --env=ICON_THEME="$selected_icon"
        fi
    else
        echo "No $mode icon theme found"
    fi
}

# Call the function to set GTK theme and icon theme based on mode
set_custom_gtk_theme "$next_mode"

# Update theme mode for the next cycle
update_theme_mode


${SCRIPTSDIR}/WallustSwww.sh &&

sleep 2
# kill process
for pid1 in waybar rofi swaync ags swaybg; do
    killall "$pid1"
done

sleep 1
${SCRIPTSDIR}/Refresh.sh 

sleep 0.5
# Display notifications for theme and icon changes 
[ "$notify_enabled" -eq 1 ] && notify-send -u low -i "$notif" " Themes switched to:" " $next_mode Mode"

exit 0

