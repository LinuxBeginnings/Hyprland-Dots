#!/usr/bin/env bash
# ==================================================
#  KoolDots (2026)
#  Project URL: https://github.com/LinuxBeginnings
#  License: GNU GPLv3
#  SPDX-License-Identifier: GPL-3.0-or-later
# ==================================================
# Waybar module for Hyprland layouts

IFS=$'\n\t'

SCRIPTSDIR="$HOME/.config/hypr/scripts"
rofi_config="$HOME/.config/rofi/config-waybar-layout.rasi"
change_layout="${SCRIPTSDIR}/ChangeLayout.sh"
layouts=(dwindle scrolling monocle master)

layout_icon() {
	case "$1" in
	dwindle) echo "🄳" ;;
	scrolling) echo "🅂" ;;
	monocle) echo "🄼" ;;
	master) echo "ⓜ" ;;
	*) echo "󰹑" ;;
	esac
}

layout_name() {
	case "$1" in
	dwindle) echo "Dwindle" ;;
	scrolling) echo "Scrolling" ;;
	monocle) echo "Monocle" ;;
	master) echo "Master" ;;
	*) echo "Unknown" ;;
	esac
}

get_layout() {
	hyprctl -j getoption general:layout 2>/dev/null | jq -r '.str // "unknown"' 2>/dev/null
}

next_layout() {
	local current="$1"
	local i

	for i in "${!layouts[@]}"; do
		if [[ "${layouts[i]}" == "$current" ]]; then
			echo "${layouts[((i + 1) % ${#layouts[@]})]}"
			return
		fi
	done

	echo "${layouts[0]}"
}

refresh_waybar() {
	pkill -RTMIN+8 waybar 2>/dev/null || true
}

set_layout() {
	local target="$1"

	"$change_layout" "$target" && refresh_waybar
}

show_status() {
	local current icon name tooltip

	current="$(get_layout)"
	icon="$(layout_icon "$current")"
	name="$(layout_name "$current")"
	tooltip="Hyprland layout: ${name} (${icon})\n\nLeft click: Select layout\nRight click: Cycle layout\n\nOptions:\n🄳  Dwindle\n🅂  Scrolling\n🄼  Monocle\nⓜ   Master"

	printf '{"text":"%s","tooltip":"%s","class":"%s"}\n' "$icon" "$tooltip" "$current"
}

show_menu() {
	local current default_row choice target i
	local options=()

	current="$(get_layout)"
	default_row=0

	for i in "${!layouts[@]}"; do
		local layout="${layouts[i]}"
		local prefix="  "

		if [[ "$layout" == "$current" ]]; then
			prefix="● "
			default_row="$i"
		fi

		options+=("${prefix}$(layout_icon "$layout")  $(layout_name "$layout")")
	done

	if pgrep -x rofi >/dev/null; then
		pkill rofi
		return 0
	fi

	choice="$(printf '%s\n' "${options[@]}" | rofi -i -dmenu -p "Layout" -mesg "Left click selects • Right click cycles" -selected-row "$default_row" -config "$rofi_config")"
	[[ -z "$choice" ]] && exit 0

	case "$choice" in
	*Dwindle*) target="dwindle" ;;
	*Scrolling*) target="scrolling" ;;
	*Monocle*) target="monocle" ;;
	*Master*) target="master" ;;
	*) exit 1 ;;
	esac

	set_layout "$target"
}

case "${1:-status}" in
status)
	show_status
	;;
menu)
	show_menu
	;;
next|toggle)
	set_layout "$(next_layout "$(get_layout)")"
	;;
dwindle|scrolling|monocle|master)
	set_layout "$1"
	;;
*)
	echo "Usage: $(basename "$0") [status|menu|next|dwindle|scrolling|monocle|master]" >&2
	exit 1
	;;
esac
