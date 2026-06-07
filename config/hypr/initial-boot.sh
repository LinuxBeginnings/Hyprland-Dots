#!/usr/bin/env bash
# /* ---- 💫 https://github.com/LinuxBeginnings 💫 ---- */  #
# A bash script designed to run only once dotfiles installed

# THIS SCRIPT CAN BE DELETED ONCE SUCCESSFULLY BOOTED!! And also, edit ~/.config/hypr/configs/Settings.conf
# NOT necessary to do since this script is only designed to run only once as long as the marker exists
# marker file is located at ~/.config/hypr/.initial_startup_done
# However, I do highly suggest not to touch it since again, as long as the marker exist, script wont run

# Variables
scriptsDir=$HOME/.config/hypr/scripts
wallpaper=$HOME/.config/hypr/wallpaper_effects/.wallpaper_current
waybar_style="$HOME/.config/waybar/style/[Extra] Neon Circuit.css"
kvantum_theme="catppuccin-mocha-blue"
color_scheme="prefer-dark"
gtk_theme="Flat-Remix-GTK-Blue-Dark"
icon_theme="Flat-Remix-Blue-Dark"
cursor_theme="Bibata-Modern-Ice"
wallust_args=()
# shellcheck source=/dev/null
if [ -f "$scriptsDir/WallustConfig.sh" ]; then
    . "$scriptsDir/WallustConfig.sh"
fi

set_interface_pref_with_retry() {
    local key="$1"
    local value="$2"
    local expected="$3"
    local current=""
    local attempt=0
    local max_attempts=6

    while [ "$attempt" -lt "$max_attempts" ]; do
        gsettings set org.gnome.desktop.interface "$key" "$value" > /dev/null 2>&1 || true
        current="$(gsettings get org.gnome.desktop.interface "$key" 2>/dev/null || true)"
        if [ "$current" = "$expected" ]; then
            return 0
        fi
        attempt=$((attempt + 1))
        sleep 0.25
    done

    return 1
}

if command -v awww >/dev/null 2>&1; then
    WWW="awww"
    DAEMON="awww-daemon"
else
    WWW="swww"
    DAEMON="swww-daemon"
fi
swww="$WWW img"
effect="--transition-bezier .43,1.19,1,.4 --transition-fps 30 --transition-type grow --transition-pos 0.925,0.977 --transition-duration 2"

# Check if a marker file exists.
if [ ! -f "$HOME/.config/hypr/.initial_startup_done" ]; then
    # Apply appearance preferences early and synchronously to avoid startup races
    # where Flatpak/libadwaita apps can default to light mode.
    set_interface_pref_with_retry color-scheme "'$color_scheme'" "'$color_scheme'" || true
    set_interface_pref_with_retry gtk-theme "'$gtk_theme'" "'$gtk_theme'" || true
    set_interface_pref_with_retry icon-theme "'$icon_theme'" "'$icon_theme'" || true
    set_interface_pref_with_retry cursor-theme "'$cursor_theme'" "'$cursor_theme'" || true
    gsettings set org.gnome.desktop.interface cursor-size 24 > /dev/null 2>&1 || true
    # Initialize wallust and wallpaper
	if [ -f "$wallpaper" ]; then
		wallust "${wallust_args[@]}" run -s "$wallpaper" > /dev/null 
		$WWW query || $DAEMON && $swww $wallpaper $effect
	    "$scriptsDir/WallustSwww.sh" > /dev/null 2>&1 & 
	fi

     # NIXOS initiate GTK dark mode and apply icon and cursor theme
	if grep -qi nixos /etc/os-release; then
      dconf write /org/gnome/desktop/interface/color-scheme "'$color_scheme'" > /dev/null 2>&1 || true
      dconf write /org/gnome/desktop/interface/gtk-theme "'$gtk_theme'" > /dev/null 2>&1 || true
      dconf write /org/gnome/desktop/interface/icon-theme "'$icon_theme'" > /dev/null 2>&1 || true
      dconf write /org/gnome/desktop/interface/cursor-theme "'$cursor_theme'" > /dev/null 2>&1 || true
      dconf write /org/gnome/desktop/interface/cursor-size "24" > /dev/null 2>&1 || true
	fi
       
    # initiate kvantum theme
    kvantummanager --set "$kvantum_theme" > /dev/null 2>&1 &

	# waybar style
	#if [ -L "$HOME/.config/waybar/config" ]; then
    ##    	ln -sf "$waybar_style" "$HOME/.config/waybar/style.css"
    #   	"$scriptsDir/Refresh.sh" > /dev/null 2>&1 & 
	#fi


    # Create a marker file to indicate that the script has been executed.
    touch "$HOME/.config/hypr/.initial_startup_done"

    exit
fi
