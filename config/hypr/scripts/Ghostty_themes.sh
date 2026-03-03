#!/usr/bin/env bash
# ==================================================
#  KoolDots (2026)
#  Project URL: https://github.com/LinuxBeginnings
#  License: GNU GPLv3
#  SPDX-License-Identifier: GPL-3.0-or-later
# ==================================================
# Ghostty theme selector

config_file="$HOME/.config/ghostty/config"
iDIR="$HOME/.config/swaync/images"
rofi_theme_primary="$HOME/.config/rofi/config-ghostty-theme.rasi"
rofi_theme_fallback="$HOME/.config/rofi/config-edit.rasi"

notify_user() {
  local icon="$1"
  local title="$2"
  local body="$3"
  if [[ -n "$icon" && -f "$icon" ]]; then
    notify-send -u low -i "$icon" "$title" "$body"
  else
    notify-send -u low "$title" "$body"
  fi
}

if [[ ! -f "$config_file" ]]; then
  notify_user "$iDIR/error.png" "Ghostty Theme" "Config not found: $config_file"
  exit 1
fi

rofi_config_args=()
if [[ -f "$rofi_theme_primary" ]]; then
  rofi_config_args=(-config "$rofi_theme_primary")
elif [[ -f "$rofi_theme_fallback" ]]; then
  rofi_config_args=(-config "$rofi_theme_fallback")
fi

current_theme=$(
  awk -F'=' '/^[[:space:]]*theme[[:space:]]*=/ {
    val=$2
    sub(/^[[:space:]]+/, "", val)
    sub(/[[:space:]]+$/, "", val)
    gsub(/^"|"$/, "", val)
    print val
    exit
  }' "$config_file"
)

mapfile -t available_theme_names < <(
  awk -F'=' '/^[[:space:]]*#[[:space:]]*theme[[:space:]]*=/ {
    val=$2
    sub(/^[[:space:]]+/, "", val)
    sub(/[[:space:]]+$/, "", val)
    gsub(/^"|"$/, "", val)
    print val
  }' "$config_file"
)

if [[ ${#available_theme_names[@]} -eq 0 ]]; then
  notify_user "$iDIR/error.png" "Ghostty Theme" "No commented themes found in $config_file"
  exit 1
fi

menu_entries=()
if [[ -n "$current_theme" ]]; then
  menu_entries+=("Current: $current_theme")
fi
for t in "${available_theme_names[@]}"; do
  menu_entries+=("$t")
done

choice=$(
  printf "%s\n" "${menu_entries[@]}" |
    rofi -i -dmenu -p "Ghostty Theme" "${rofi_config_args[@]}" -mesg "Select a theme to apply"
)

[[ -z "$choice" ]] && exit 0

if [[ "$choice" == "Current: "* ]]; then
  exit 0
fi

selected_theme="$choice"

if [[ -n "$current_theme" && "$selected_theme" == "$current_theme" ]]; then
  exit 0
fi

format_theme_value() {
  if [[ "$1" =~ [[:space:]] ]]; then
    printf "\"%s\"" "$1"
  else
    printf "%s" "$1"
  fi
}

selected_formatted=$(format_theme_value "$selected_theme")

tmp_file=$(mktemp)
awk -v selected="$selected_theme" -v selected_formatted="$selected_formatted" '
function trim(s) { sub(/^[[:space:]]+/, "", s); sub(/[[:space:]]+$/, "", s); return s }
function strip_quotes(s) { gsub(/^"|"$/, "", s); return s }
{
  line=$0
  if ($0 ~ /^[[:space:]]*theme[[:space:]]*=/) {
    sub(/^[[:space:]]*theme[[:space:]]*=/, "#theme =", line)
    print line
    next
  }
  if ($0 ~ /^[[:space:]]*#[[:space:]]*theme[[:space:]]*=/) {
    val=$0
    sub(/^[[:space:]]*#[[:space:]]*theme[[:space:]]*=[[:space:]]*/, "", val)
    val=trim(val)
    val=strip_quotes(val)
    if (val == selected) {
      print "theme = " selected_formatted
      next
    }
  }
  print $0
}' "$config_file" > "$tmp_file"

mv "$tmp_file" "$config_file"

pkill -SIGUSR2 ghostty >/dev/null 2>&1 || true

notify_user "$iDIR/ja.png" "Ghostty Theme Applied" "$selected_theme"

exit 0
