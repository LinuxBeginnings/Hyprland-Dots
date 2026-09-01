#!/usr/bin/env bash
# ==================================================
#  KoolDots (2026)
#  Project URL: https://github.com/LinuxBeginnings
#  License: GNU GPLv3
#  SPDX-License-Identifier: GPL-3.0-or-later
# ==================================================
# Script for Oh my ZSH theme ( CTRL SHIFT O)

# preview of theme can be view here: https://github.com/ohmyzsh/ohmyzsh/wiki/Themes
# after choosing theme, TTY need to be closed and re-open

# Variables
iDIR="${XDG_CONFIG_HOME:-$HOME/.config}/swaync/images"
rofi_theme="${XDG_CONFIG_HOME:-$HOME/.config}/hypr/rofi/config-zsh-theme.rasi"

if [ -n "$(grep -i nixos < /etc/os-release)" ]; then
  notify-send -i "$iDIR/note.png" "NOT Supported" "Sorry NixOS does not support this KooL feature"
  exit 1
fi

file_extension=".zsh-theme"

# Locate the active zshrc (honoring ZDOTDIR when set)
zsh_path="${ZDOTDIR:-$HOME}/.zshrc"
if [ ! -f "$zsh_path" ] && [ -f "$HOME/.zshrc" ]; then
    zsh_path="$HOME/.zshrc"
fi

# Locate Oh My Zsh. Search order:
# 1. $ZSH env var (if exported in user environment)
# 2. Parsed `export ZSH="..."` or `ZSH="..."` line directly from .zshrc
# 3. Parsed `source .../oh-my-zsh.sh` line from .zshrc (directory containing the script)
# 4. Standard conventional paths (~/.oh-my-zsh, $ZDOTDIR/.oh-my-zsh, XDG data home, /usr/share, /opt)
omz_root=""
omz_from_zshrc=""
if [ -f "$zsh_path" ]; then
    omz_from_zshrc=$(grep -E '^[[:space:]]*(export[[:space:]]+)?ZSH=' "$zsh_path" | head -n1 | sed -E 's/^[[:space:]]*(export[[:space:]]+)?ZSH=["'"'"']?([^"'"'"'[:space:]]+)["'"'"']?.*/\2/' || true)
    # Expand $HOME / ~ if present in the parsed path
    omz_from_zshrc="${omz_from_zshrc/#\~/$HOME}"
    omz_from_zshrc="${omz_from_zshrc//\$HOME/$HOME}"
    if [ -z "$omz_from_zshrc" ]; then
        # Fall back to checking where oh-my-zsh.sh is sourced from in .zshrc
        omz_source_line=$(grep -E '^[[:space:]]*(source|\.)[[:space:]]+.*oh-my-zsh\.sh' "$zsh_path" | head -n1 || true)
        if [ -n "$omz_source_line" ]; then
            omz_from_zshrc=$(echo "$omz_source_line" | sed -E 's/^[[:space:]]*(source|\.)[[:space:]]+["'"'"']?([^"'"'"'[:space:]]+)\/oh-my-zsh\.sh["'"'"']?.*/\2/' || true)
            omz_from_zshrc="${omz_from_zshrc/#\~/$HOME}"
            omz_from_zshrc="${omz_from_zshrc//\$HOME/$HOME}"
        fi
    fi
fi

for candidate in \
    "${ZSH:-}" \
    "$omz_from_zshrc" \
    "$HOME/.oh-my-zsh" \
    "${ZDOTDIR:-$HOME}/.oh-my-zsh" \
    "${XDG_DATA_HOME:-$HOME/.local/share}/oh-my-zsh" \
    "/usr/share/oh-my-zsh" \
    "/usr/share/ohmyzsh" \
    "/opt/oh-my-zsh" \
    "/opt/ohmyzsh"; do
    if [ -n "$candidate" ] && [ -d "$candidate" ]; then
        omz_root="$candidate"
        break
    fi
done

# Collect theme files from both built-in themes/ and custom themes/ ($ZSH_CUSTOM/themes)
themes_array=()
if [ -n "$omz_root" ]; then
    # 1. Core themes directory
    if [ -d "$omz_root/themes" ]; then
        while IFS= read -r theme_file; do
            [ -n "$theme_file" ] && themes_array+=("$theme_file")
        done < <(find -L "$omz_root/themes" -maxdepth 1 -type f -name "*$file_extension" -exec basename {} \; 2>/dev/null | sed -e "s/$file_extension//" | sort -u)
    fi

    # 2. Custom themes directory ($ZSH_CUSTOM/themes or $omz_root/custom/themes)
    custom_themes_dir="${ZSH_CUSTOM:-$omz_root/custom}/themes"
    if [ -d "$custom_themes_dir" ]; then
        while IFS= read -r theme_file; do
            [ -n "$theme_file" ] && themes_array+=("$theme_file")
        done < <(find -L "$custom_themes_dir" -maxdepth 1 -type f -name "*$file_extension" -exec basename {} \; 2>/dev/null | sed -e "s/$file_extension//" | sort -u)
    fi
fi

# Sort and deduplicate all found themes
if [ "${#themes_array[@]}" -gt 0 ]; then
    mapfile -t themes_array < <(printf "%s\n" "${themes_array[@]}" | sort -u)
fi

# If no themes were found, show diagnostic info in the notification
if [ "${#themes_array[@]}" -eq 0 ]; then
    if [ -z "$omz_root" ]; then
        notify-send -i "$iDIR/error.png" "Oh My Zsh not found" "Checked ~/.oh-my-zsh, .zshrc ZSH=, and system paths. Install Oh My Zsh or set ZSH in .zshrc."
    else
        notify-send -i "$iDIR/error.png" "No themes found" "Found Oh My Zsh at $omz_root, but themes/ directory is empty or missing."
    fi
fi

# Add "Random" option to the beginning of the array
themes_array=("Random" "${themes_array[@]}")

rofi_command="rofi -i -dmenu -config $rofi_theme"

menu() {
    for theme in "${themes_array[@]}"; do
        echo "$theme"
    done
}

main() {
    "${XDG_CONFIG_HOME:-$HOME/.config}/hypr/scripts/RofiFocusedWallpaperLink.sh" >/dev/null 2>&1 || true
    choice=$(menu | ${rofi_command})

    # if nothing selected, script won't change anything
    if [ -z "$choice" ]; then
        exit 0
    fi

    zsh_path="$HOME/.zshrc"
    var_name="ZSH_THEME"

    if [[ "$choice" == "Random" ]]; then
        if [ "${#themes_array[@]}" -le 1 ]; then
            notify-send -i "$iDIR/error.png" "No themes available" "Oh My Zsh was not found; nothing to randomize."
            exit 1
        fi
        # Pick a random theme from the original themes_array (excluding "Random")
        random_theme=${themes_array[$((RANDOM % (${#themes_array[@]} - 1) + 1))]}
        theme_to_set="$random_theme"
        notify-send -i "$iDIR/ja.png" "Random theme:" "selected: $random_theme"
    else
        # Set theme to the selected choice
        theme_to_set="$choice"
        notify-send -i "$iDIR/ja.png" "Theme selected:" "$choice"
    fi

    if [ -f "$zsh_path" ]; then
        sed -i "s/^$var_name=.*/$var_name=\"$theme_to_set\"/" "$zsh_path"
        notify-send -i "$iDIR/ja.png" "OMZ theme" "applied. restart your terminal"
    else
        notify-send -i "$iDIR/error.png" "E-R-R-O-R" "~.zshrc file not found!"
    fi
}

# Check if rofi is already running
if pidof rofi > /dev/null; then
  pkill rofi
fi

main
