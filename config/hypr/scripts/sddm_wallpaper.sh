#!/usr/bin/env bash
# ==================================================
#  KoolDots (2026)
#  Project URL: https://github.com/LinuxBeginnings
#  License: GNU GPLv3
#  SPDX-License-Identifier: GPL-3.0-or-later
# ==================================================
# SDDM Wallpaper and Wallust Colors Setter

# variables
terminal=kitty
PICTURES_DIR="$(xdg-user-dir PICTURES 2>/dev/null || echo "$HOME/Pictures")"
wallDIR="$PICTURES_DIR/wallpapers"
SCRIPTSDIR="$HOME/.config/hypr/scripts"
wallpaper_link="$HOME/.config/rofi/.current_wallpaper"
wallpaper_current="$HOME/.config/hypr/wallpaper_effects/.wallpaper_current"
wallpaper_modified="$HOME/.config/hypr/wallpaper_effects/.wallpaper_modified"
rofi_theme="$HOME/.config/rofi/config-wallpaper.rasi"
# Directory for swaync
iDIR="$HOME/.config/swaync/images"
iDIRi="$HOME/.config/swaync/icons"
video_preview_cache="$HOME/.cache/video_preview"
sddm_video_cache="$HOME/.cache/sddm_preview"
# shellcheck source=/dev/null
. "$SCRIPTSDIR/WallpaperCmd.sh" 2>/dev/null || true

find_notify_send() {
    local candidate=""
    if candidate="$(command -v notify-send 2>/dev/null)"; then
        if [[ -n "$candidate" && -x "$candidate" ]]; then
            printf '%s\n' "$candidate"
            return 0
        fi
    fi
    for candidate in /usr/bin/notify-send /usr/sbin/notify-send /bin/notify-send /sbin/notify-send; do
        if [[ -x "$candidate" ]]; then
            printf '%s\n' "$candidate"
            return 0
        fi
    done
    return 1
}

NOTIFY_SEND_BIN="$(find_notify_send || true)"

notify_err() {
    if [[ -n "$NOTIFY_SEND_BIN" ]]; then
        if [[ -f "$iDIR/error.png" ]]; then
            "$NOTIFY_SEND_BIN" -i "$iDIR/error.png" "SDDM" "$1"
        else
            "$NOTIFY_SEND_BIN" "SDDM" "$1"
        fi
    fi
}

notify_ok() {
    if [[ -n "$NOTIFY_SEND_BIN" ]]; then
        if [[ -f "$iDIR/ja.png" ]]; then
            "$NOTIFY_SEND_BIN" -i "$iDIR/ja.png" "SDDM" "$1"
        else
            "$NOTIFY_SEND_BIN" "SDDM" "$1"
        fi
    fi
}

read_cached_wallpaper() {
    local cache_file="$1"
    [[ -f "$cache_file" ]] || return 1
    awk 'NF && $0 !~ /^filter/ {print; exit}' "$cache_file"
}

read_wallpaper_from_query() {
    local monitor="$1"
    [[ -n "$monitor" ]] || return 1
    [[ -n "${WWW_CMD:-}" ]] || return 1
    command -v "$WWW_CMD" >/dev/null 2>&1 || return 1
    "$WWW_CMD" query 2>/dev/null | awk -v mon="$monitor" '
        {
            line=$0
            sub(/^Monitor[[:space:]]+/, "", line)
            sub(/^:[[:space:]]*/, "", line)
            mon_name=line
            sub(/:.*/, "", mon_name)
            gsub(/^[[:space:]]+|[[:space:]]+$/, "", mon_name)
            if (mon_name != mon) next
            path=line
            sub(/^.*image:[[:space:]]*/, "", path)
            gsub(/^[[:space:]]+|[[:space:]]+$/, "", path)
            if (path != line && length(path) > 0) {
                print path
                exit
            }
        }
    '
}

read_wallpaper_from_cache() {
    local monitor="$1"
    local cache_root="${WWW_CACHE_DIR:-$HOME/.cache/awww}"
    local cache_file="$cache_root/$monitor"
    local fallback_cache=""
    local path=""

    case "$cache_root" in
        "$HOME/.cache/awww")
            fallback_cache="$HOME/.cache/swww/$monitor"
            ;;
        "$HOME/.cache/swww")
            fallback_cache="$HOME/.cache/awww/$monitor"
            ;;
    esac

    path="$(read_cached_wallpaper "$cache_file" 2>/dev/null || true)"
    if [[ -z "$path" && -n "$fallback_cache" ]]; then
        path="$(read_cached_wallpaper "$fallback_cache" 2>/dev/null || true)"
    fi

    [[ -n "$path" && -f "$path" ]] || return 1
    printf '%s\n' "$path"
}

calculate_rofi_icon_size() {
    local monitor="$1"
    local scale_factor=""
    local monitor_height=""
    local icon_size=""
    local adjusted_icon_size=""

    if [[ -z "$monitor" ]]; then
        monitor="$(get_focused_monitor 2>/dev/null || true)"
    fi

    if [[ -z "$monitor" ]]; then
        printf '22\n'
        return 0
    fi

    if command -v hyprctl >/dev/null 2>&1 && command -v jq >/dev/null 2>&1 && command -v bc >/dev/null 2>&1; then
        scale_factor="$(hyprctl monitors -j 2>/dev/null | jq -r --arg mon "$monitor" '.[] | select(.name == $mon) | .scale' | head -n1)"
        monitor_height="$(hyprctl monitors -j 2>/dev/null | jq -r --arg mon "$monitor" '.[] | select(.name == $mon) | .height' | head -n1)"
        if [[ -n "$scale_factor" && -n "$monitor_height" && "$scale_factor" != "null" && "$monitor_height" =~ ^[0-9]+$ ]]; then
            icon_size="$(echo "scale=1; ($monitor_height * 3) / ($scale_factor * 150)" | bc 2>/dev/null || true)"
            adjusted_icon_size="$(echo "$icon_size" | awk '{if ($1 < 15) $1 = 20; if ($1 > 25) $1 = 25; print int($1)}')"
            if [[ "$adjusted_icon_size" =~ ^[0-9]+$ ]]; then
                printf '%s\n' "$adjusted_icon_size"
                return 0
            fi
        fi
    fi

    printf '22\n'
}

resolve_link_or_file() {
    local path="$1"
    local resolved=""
    if [[ -L "$path" ]]; then
        resolved="$(readlink -f "$path" 2>/dev/null || true)"
        if [[ -n "$resolved" && -f "$resolved" ]]; then
            printf '%s\n' "$resolved"
            return 0
        fi
    fi
    if [[ -f "$path" ]]; then
        printf '%s\n' "$path"
        return 0
    fi
    return 1
}

get_active_workspace_monitor() {
    if ! command -v hyprctl >/dev/null 2>&1; then
        return 1
    fi
    if command -v jq >/dev/null 2>&1; then
        hyprctl activeworkspace -j 2>/dev/null | jq -r '.monitor // empty' | head -n1
    else
        hyprctl monitors 2>/dev/null | awk '/^Monitor/{name=$2} /focused: yes/{print name; exit}'
    fi
}

get_focused_monitor() {
    if ! command -v hyprctl >/dev/null 2>&1; then
        return 1
    fi
    if command -v jq >/dev/null 2>&1; then
        hyprctl monitors -j 2>/dev/null | jq -r '.[] | select(.focused) | .name' | head -n1
    else
        hyprctl monitors 2>/dev/null | awk '/^Monitor/{name=$2} /focused: yes/{print name; exit}'
    fi
}

monitor_exists() {
    local monitor="$1"
    [[ -n "$monitor" ]] || return 1
    command -v hyprctl >/dev/null 2>&1 || return 1
    if command -v jq >/dev/null 2>&1; then
        hyprctl monitors -j 2>/dev/null | jq -r --arg mon "$monitor" '.[] | select(.name == $mon) | .name' | grep -qx "$monitor"
    else
        hyprctl monitors 2>/dev/null | awk '/^Monitor/{print $2}' | grep -qx "$monitor"
    fi
}

resolve_target_monitor() {
    local requested="$1"
    local monitor=""
    if monitor_exists "$requested"; then
        printf '%s\n' "$requested"
        return 0
    fi
    monitor="$(get_active_workspace_monitor 2>/dev/null || true)"
    if monitor_exists "$monitor"; then
        printf '%s\n' "$monitor"
        return 0
    fi
    monitor="$(get_focused_monitor 2>/dev/null || true)"
    if [[ -n "$monitor" ]]; then
        printf '%s\n' "$monitor"
        return 0
    fi
    return 1
}

resolve_normal_wallpaper() {
    local monitor="$1"
    local path=""
    local per_monitor_rofi_link=""
    local per_monitor_current=""

    if [[ -n "$monitor" ]]; then
        per_monitor_rofi_link="$HOME/.config/rofi/.current_wallpaper_${monitor}"
        per_monitor_current="$HOME/.config/hypr/wallpaper_effects/.wallpaper_current_${monitor}"

        path="$(read_wallpaper_from_query "$monitor" 2>/dev/null || true)"
        if [[ -z "$path" ]]; then
            path="$(resolve_link_or_file "$per_monitor_rofi_link" 2>/dev/null || true)"
        fi
        if [[ -z "$path" ]]; then
            path="$(resolve_link_or_file "$per_monitor_current" 2>/dev/null || true)"
        fi
        if [[ -z "$path" ]]; then
            path="$(read_wallpaper_from_cache "$monitor" 2>/dev/null || true)"
        fi
    fi

    if [[ -z "$path" ]]; then
        path="$(resolve_link_or_file "$wallpaper_current" 2>/dev/null || true)"
    fi
    if [[ -z "$path" ]]; then
        path="$(resolve_link_or_file "$wallpaper_link" 2>/dev/null || true)"
    fi

    [[ -n "$path" && -f "$path" ]] || return 1
    printf '%s\n' "$path"
}

resolve_effects_wallpaper() {
    local monitor="$1"
    local path=""
    local per_monitor_modified=""

    if [[ -n "$monitor" ]]; then
        per_monitor_modified="$HOME/.config/hypr/wallpaper_effects/.wallpaper_modified_${monitor}"
        path="$(resolve_link_or_file "$per_monitor_modified" 2>/dev/null || true)"
    fi

    if [[ -z "$path" ]]; then
        path="$(resolve_link_or_file "$wallpaper_modified" 2>/dev/null || true)"
    fi
    if [[ -z "$path" ]]; then
        path="$(resolve_normal_wallpaper "$monitor" 2>/dev/null || true)"
    fi

    [[ -n "$path" && -f "$path" ]] || return 1
    printf '%s\n' "$path"
}

resolve_current_sddm_background() {
    local sddm_simple="$1"
    local candidate=""
    for candidate in "$sddm_simple/Backgrounds/default" "$sddm_simple/Backgrounds/default.jpg" "$sddm_simple/Backgrounds/default.png"; do
        if [[ -f "$candidate" ]]; then
            printf '%s\n' "$candidate"
            return 0
        fi
    done
    return 1
}

extract_color() {
    local key="$1"
    local value
    value="$(grep -oP "$key:\\s*\\K#[A-Fa-f0-9]+" "$rofi_wallust" | head -n1)"
    printf '%s\n' "$value"
}

prepare_sddm_wallpaper() {
    local selected_file="$1"
    local target_monitor="$2"
    local prepared_path="$selected_file"

    if [[ ! -f "$selected_file" ]]; then
        notify_err "Selected file not found for ${target_monitor:-current context}."
        return 1
    fi

    if [[ "$selected_file" =~ \.(mp4|mkv|mov|webm|MP4|MKV|MOV|WEBM)$ ]]; then
        if ! command -v ffmpeg >/dev/null 2>&1; then
            notify_err "ffmpeg not found; cannot convert selected video wallpaper."
            return 1
        fi
        mkdir -p "$sddm_video_cache"
        local video_name
        video_name="$(basename "$selected_file")"
        prepared_path="$sddm_video_cache/${video_name}.png"
        if ! ffmpeg -v error -y -i "$selected_file" -ss 00:00:01.000 -vframes 1 "$prepared_path"; then
            notify_err "Could not generate preview from selected video wallpaper."
            return 1
        fi
    fi

    printf '%s\n' "$prepared_path"
}

# Parse arguments
mode="effects" # default
requested_monitor="${SDDM_TARGET_MONITOR:-${HYPRLOCK_TARGET_MONITOR:-}}"
for arg in "$@"; do
    case "$arg" in
        --normal)
            mode="normal"
            ;;
        --effects)
            mode="effects"
            ;;
        --monitor=*)
            requested_monitor="${arg#--monitor=}"
            ;;
        --*)
            ;;
        *)
            if [[ -z "$requested_monitor" ]]; then
                requested_monitor="$arg"
            fi
            ;;
    esac
done

# Resolve SDDM themes directory (standard paths and NixOS path)
sddm_themes_dir="/usr/share/sddm/themes"
if [[ ! -d "$sddm_themes_dir" && -d "/run/current-system/sw/share/sddm/themes" ]]; then
    sddm_themes_dir="/run/current-system/sw/share/sddm/themes"
fi
sddm_simple="$sddm_themes_dir/simple_sddm_2"
sddm_theme_conf="$sddm_simple/theme.conf"

# rofi-wallust-sddm colors path
rofi_wallust="$HOME/.config/rofi/wallust/colors-rofi.rasi"
if [[ ! -f "$rofi_wallust" ]]; then
    notify_err "Wallust colors file not found ($rofi_wallust). Aborting."
    exit 1
fi
if [[ ! -d "$sddm_simple/Backgrounds" ]]; then
    notify_err "SDDM theme backgrounds not found ($sddm_simple/Backgrounds)."
    exit 1
fi
if [[ ! -f "$sddm_theme_conf" ]]; then
    notify_err "SDDM theme config not found ($sddm_theme_conf)."
    exit 1
fi
if [[ ! -d "$wallDIR" ]]; then
    notify_err "Wallpaper directory not found ($wallDIR)."
    exit 1
fi
if ! command -v rofi >/dev/null 2>&1; then
    notify_err "rofi not found."
    exit 1
fi
if ! command -v "$terminal" >/dev/null 2>&1; then
    notify_err "Terminal '$terminal' not found."
    exit 1
fi
if ! command -v sudo >/dev/null 2>&1; then
    notify_err "sudo not found."
    exit 1
fi

# Abort on NixOS where this repo doesn't manage SDDM and themes are typically read-only
if hostnamectl 2>/dev/null | grep -q 'Operating System: NixOS'; then
    notify_err "NixOS detected: skipping SDDM background change."
    exit 0
fi

# Abort if SDDM is not running (avoid errors on non-SDDM systems)
if command -v systemctl >/dev/null 2>&1; then
    if ! systemctl is-active --quiet sddm; then
        notify_err "SDDM is not running. Skipping SDDM wallpaper update."
        exit 0
    fi
elif ! pidof sddm >/dev/null 2>&1; then
    notify_err "SDDM is not running. Skipping SDDM wallpaper update."
    exit 0
fi

# Extract colors from rofi wallust config
color0="$(extract_color "color1")"
color1="$(extract_color "color0")"
color7="$(extract_color "color14")"
color10="$(extract_color "color10")"
color12="$(extract_color "color12")"
color13="$(extract_color "color13")"
foreground="$(extract_color "foreground")"

missing_colors=()
for var in color0 color1 color7 color10 color12 color13 foreground; do
    if [[ -z "${!var}" ]]; then
        missing_colors+=("$var")
    fi
done

if [[ ${#missing_colors[@]} -gt 0 ]]; then
    notify_err "Missing color(s): ${missing_colors[*]}. Run Wallust first."
    exit 1
fi

target_monitor="$(resolve_target_monitor "$requested_monitor" 2>/dev/null || true)"
current_monitor_path=""
if [[ "$mode" == "normal" ]]; then
    current_monitor_path="$(resolve_normal_wallpaper "$target_monitor" 2>/dev/null || true)"
else
    current_monitor_path="$(resolve_effects_wallpaper "$target_monitor" 2>/dev/null || true)"
fi
current_sddm_path="$(resolve_current_sddm_background "$sddm_simple" 2>/dev/null || true)"

current_monitor_label=""
if [[ -n "$current_monitor_path" && -f "$current_monitor_path" ]]; then
    if [[ -n "$target_monitor" ]]; then
        current_monitor_label="Current monitor ($target_monitor): $(basename "$current_monitor_path")"
    else
        current_monitor_label="Current monitor wallpaper: $(basename "$current_monitor_path")"
    fi
fi

current_sddm_label=""
if [[ -n "$current_sddm_path" && -f "$current_sddm_path" ]]; then
    current_sddm_label="Current SDDM background: $(basename "$current_sddm_path")"
fi

mapfile -d '' WALLPAPERS < <(find -L "$wallDIR" -type f \( \
    -iname "*.jpg" -o -iname "*.jpeg" -o -iname "*.png" -o -iname "*.gif" -o \
    -iname "*.bmp" -o -iname "*.tiff" -o -iname "*.webp" -o \
    -iname "*.mp4" -o -iname "*.mkv" -o -iname "*.mov" -o -iname "*.webm" \
\) -print0)

if [[ ${#WALLPAPERS[@]} -eq 0 ]]; then
    notify_err "No wallpapers found in $wallDIR."
    exit 1
fi

random_wallpaper="${WALLPAPERS[$((RANDOM % ${#WALLPAPERS[@]}))]}"
random_label="Random: $(basename "$random_wallpaper")"

has_ffmpeg=0
if command -v ffmpeg >/dev/null 2>&1; then
    has_ffmpeg=1
fi

menu_message="Select SDDM wallpaper"
if [[ -n "$target_monitor" ]]; then
    menu_message="Select SDDM wallpaper for $target_monitor"
fi
rofi_icon_size="$(calculate_rofi_icon_size "$target_monitor")"
rofi_override="element-icon{size:${rofi_icon_size}%;}"

menu() {
    local -a sorted_options=()
    local pic_path pic_name cache_preview_image

    mapfile -t sorted_options < <(printf '%s\n' "${WALLPAPERS[@]}" | sort)

    printf "%s\x00icon\x1f%s\n" "$random_label" "$random_wallpaper"
    if [[ -n "$current_monitor_label" && -n "$current_monitor_path" ]]; then
        printf "%s\x00icon\x1f%s\n" "$current_monitor_label" "$current_monitor_path"
    fi
    if [[ -n "$current_sddm_label" && -n "$current_sddm_path" ]]; then
        printf "%s\x00icon\x1f%s\n" "$current_sddm_label" "$current_sddm_path"
    fi

    for pic_path in "${sorted_options[@]}"; do
        pic_name="$(basename "$pic_path")"
        if [[ "$pic_name" =~ \.(mp4|mkv|mov|webm|MP4|MKV|MOV|WEBM)$ ]]; then
            cache_preview_image="$video_preview_cache/${pic_name}.png"
            if [[ ! -f "$cache_preview_image" && "$has_ffmpeg" -eq 1 ]]; then
                mkdir -p "$video_preview_cache"
                ffmpeg -v error -y -i "$pic_path" -ss 00:00:01.000 -vframes 1 "$cache_preview_image" >/dev/null 2>&1 || true
            fi
            if [[ -f "$cache_preview_image" ]]; then
                printf "%s\x00icon\x1f%s\n" "$pic_name" "$cache_preview_image"
            else
                printf "%s\n" "$pic_name"
            fi
        else
            printf "%s\x00icon\x1f%s\n" "$pic_name" "$pic_path"
        fi
    done
}

rofi_cmd=(rofi -i -show -dmenu -mesg "$menu_message" -theme-str "$rofi_override")
if [[ -f "$rofi_theme" ]]; then
    rofi_cmd+=(-config "$rofi_theme")
fi

choice="$(menu | "${rofi_cmd[@]}")"
choice="${choice#"${choice%%[![:space:]]*}"}"
choice="${choice%"${choice##*[![:space:]]}"}"

if [[ -z "$choice" ]]; then
    exit 0
fi

selected_file=""
if [[ "$choice" == "$random_label" ]]; then
    selected_file="$random_wallpaper"
elif [[ -n "$current_monitor_label" && "$choice" == "$current_monitor_label" ]]; then
    selected_file="$current_monitor_path"
elif [[ -n "$current_sddm_label" && "$choice" == "$current_sddm_label" ]]; then
    selected_file="$current_sddm_path"
elif [[ -f "$choice" ]]; then
    selected_file="$choice"
else
    choice_basename="$(basename "$choice" | sed 's/\(.*\)\.[^.]*$/\1/')"
    selected_file="$(find -L "$wallDIR" -type f -iname "$choice_basename.*" -print -quit)"
fi

if [[ -z "$selected_file" || ! -f "$selected_file" ]]; then
    notify_err "Selected wallpaper not found: $choice"
    exit 1
fi

wallpaper_path="$(prepare_sddm_wallpaper "$selected_file" "$target_monitor" 2>/dev/null || true)"
if [[ -z "$wallpaper_path" || ! -f "$wallpaper_path" ]]; then
    notify_err "Could not prepare selected wallpaper for SDDM."
    exit 1
fi

# Launch terminal and apply changes
if ! "$terminal" -e bash -c '
set -e
theme_conf="$1"
wallpaper_path="$2"
sddm_simple="$3"
color13="$4"
color12="$5"
color1="$6"
color10="$7"
color7="$8"

echo "Enter your password to update SDDM wallpapers and colors"

# Update the colors in the SDDM config
sudo sed -i "s/HeaderTextColor=\"#.*\"/HeaderTextColor=\"$color13\"/" "$theme_conf"
sudo sed -i "s/DateTextColor=\"#.*\"/DateTextColor=\"$color13\"/" "$theme_conf"
sudo sed -i "s/TimeTextColor=\"#.*\"/TimeTextColor=\"$color13\"/" "$theme_conf"
sudo sed -i "s/DropdownSelectedBackgroundColor=\"#.*\"/DropdownSelectedBackgroundColor=\"$color13\"/" "$theme_conf"
sudo sed -i "s/SystemButtonsIconsColor=\"#.*\"/SystemButtonsIconsColor=\"$color13\"/" "$theme_conf"
sudo sed -i "s/SessionButtonTextColor=\"#.*\"/SessionButtonTextColor=\"$color13\"/" "$theme_conf"
sudo sed -i "s/VirtualKeyboardButtonTextColor=\"#.*\"/VirtualKeyboardButtonTextColor=\"$color13\"/" "$theme_conf"
sudo sed -i "s/HighlightBackgroundColor=\"#.*\"/HighlightBackgroundColor=\"$color12\"/" "$theme_conf"
sudo sed -i "s/LoginFieldTextColor=\"#.*\"/LoginFieldTextColor=\"$color12\"/" "$theme_conf"
sudo sed -i "s/PasswordFieldTextColor=\"#.*\"/PasswordFieldTextColor=\"$color12\"/" "$theme_conf"
sudo sed -i "s/DropdownBackgroundColor=\"#.*\"/DropdownBackgroundColor=\"$color1\"/" "$theme_conf"
sudo sed -i "s/HighlightTextColor=\"#.*\"/HighlightTextColor=\"$color10\"/" "$theme_conf"
sudo sed -i "s/PlaceholderTextColor=\"#.*\"/PlaceholderTextColor=\"$color7\"/" "$theme_conf"
sudo sed -i "s/UserIconColor=\"#.*\"/UserIconColor=\"$color7\"/" "$theme_conf"
sudo sed -i "s/PasswordIconColor=\"#.*\"/PasswordIconColor=\"$color7\"/" "$theme_conf"

# Copy wallpaper to SDDM theme
sudo cp -f "$wallpaper_path" "$sddm_simple/Backgrounds/default"
if [ -e "$sddm_simple/Backgrounds/default.jpg" ]; then
    sudo cp -f "$wallpaper_path" "$sddm_simple/Backgrounds/default.jpg"
fi
if [ -e "$sddm_simple/Backgrounds/default.png" ]; then
    sudo cp -f "$wallpaper_path" "$sddm_simple/Backgrounds/default.png"
fi
' _ "$sddm_theme_conf" "$wallpaper_path" "$sddm_simple" "$color13" "$color12" "$color1" "$color10" "$color7"; then
    notify_err "Failed to update SDDM for ${target_monitor:-current context}: $(basename "$wallpaper_path")."
    exit 1
fi

notify_ok "Set for ${target_monitor:-current context}: $(basename "$wallpaper_path")."
