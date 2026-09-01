#!/usr/bin/env bash
# ==================================================
#  KoolDots (2026)
#  Project URL: https://github.com/LinuxBeginnings
#  License: GNU GPLv3
#  SPDX-License-Identifier: GPL-3.0-or-later
# ==================================================
# Waybar module for Hyprland layouts

IFS=$'\n\t'

SCRIPTSDIR="${XDG_CONFIG_HOME:-$HOME/.config}/hypr/scripts"
rofi_config="${XDG_CONFIG_HOME:-$HOME/.config}/hypr/rofi/config-layout.rasi"
change_layout="${SCRIPTSDIR}/ChangeLayout.sh"
layouts=(dwindle master scrolling monocle)

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

# Fallback shortcut labels used when live Hyprland bind data is unavailable.
layout_shortcut_fallback() {
	case "$1" in
	dwindle) echo "SUPER+ALT+1" ;;
	master) echo "SUPER+ALT+2" ;;
	scrolling) echo "SUPER+ALT+3" ;;
	monocle) echo "SUPER+ALT+4" ;;
	*) echo "" ;;
	esac
}

# Resolve live shortcut label from currently loaded Hyprland binds.
# Works for both Hyprlang and Lua config modes since it reads runtime bind state.
layout_shortcut_live() {
	local target="$1"
	local shortcuts

	if ! command -v hyprctl >/dev/null 2>&1 || ! command -v jq >/dev/null 2>&1; then
		return 1
	fi

	shortcuts="$(
		hyprctl -j binds 2>/dev/null | jq -r --arg target "$target" '
			# Decode integer modmask into modifier string (SUPER+ALT+CTRL+SHIFT).
			# Bit values: SHIFT=1, CTRL=4, ALT=8, SUPER=64
			def has_bit(mask; bit): ((mask / bit) | floor) % 2 == 1;
			def modmask_str(mask):
				[
					if has_bit(mask; 64) then "SUPER" else empty end,
					if has_bit(mask; 8)  then "ALT"   else empty end,
					if has_bit(mask; 4)  then "CTRL"  else empty end,
					if has_bit(mask; 1)  then "SHIFT" else empty end
				] | join("+");
			[
				.[]?
				| select(
					(
						(.dispatcher // "") == "exec"
						and (
							(.arg // .args // .argument // "")
							| tostring
							| test("(^|[[:space:];])([^;]*ChangeLayout\\.sh[[:space:]]+" + $target + "([[:space:];]|$))")
						)
					)
					or (
						(.description // "")
						| tostring
						| ascii_downcase
						== ("layout " + $target)
					)
				)
				| (
					# Prefer display_key if present and non-empty (newer Hyprland versions).
					(.display_key | if . != null and length > 0 then . else null end)
					// (
						# Fall back to decoding modmask bitmask + key name.
						[modmask_str(.modmask // 0), (.key // "")]
						| map(select(. != null and . != ""))
						| join("+")
					)
				)
				| tostring
				| gsub("\\s*\\+\\s*"; "+")
				| select(length > 0)
			]
			| unique
			| join(" / ")
		' 2>/dev/null
	)"

	[[ -n "$shortcuts" ]] || return 1
	printf '%s\n' "$shortcuts"
}

layout_shortcut() {
	local target="$1"
	local live_value

	live_value="$(layout_shortcut_live "$target" || true)"
	if [[ -n "$live_value" ]]; then
		printf '%s\n' "$live_value"
		return
	fi

	layout_shortcut_fallback "$target"
}

get_layout() {
	local layout

	if [[ -x "$change_layout" ]]; then
		layout="$("$change_layout" --quiet current 2>/dev/null || true)"
		if [[ -n "$layout" ]]; then
			printf '%s\n' "$layout"
			return
		fi
	fi

	hyprctl -j activeworkspace 2>/dev/null | jq -r '.tiledLayout // .tiled_layout // "unknown"' 2>/dev/null
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
	tooltip="Workspace layout: ${name} (${icon})\n\nLeft click: Select layout for active workspace\nRight click: Cycle active workspace layout\n\nOptions:\n🄳  Dwindle\n🅂  Scrolling\n🄼  Monocle\nⓜ   Master"

	printf '{"text":"%s","tooltip":"%s","class":"%s"}\n' "$icon" "$tooltip" "$current"
}

show_menu() {
	local current default_row choice target i
	local options=()
	local left_width=0
	local row left_text shortcut

	current="$(get_layout)"
	default_row=0

	# First pass: collect left-column text and shortcuts, track max left width.
	for i in "${!layouts[@]}"; do
		local layout="${layouts[i]}"
		local prefix="  "

		if [[ "$layout" == "$current" ]]; then
			prefix="● "
			default_row="$i"
		fi

		shortcut="$(layout_shortcut "$layout")"
		left_text="$(printf '%s%s  %s' "$prefix" "$(layout_icon "$layout")" "$(layout_name "$layout")")"
		(( ${#left_text} > left_width )) && left_width=${#left_text}
		options+=("$left_text|$shortcut")
	done

	# Second pass: pad left column to uniform char width, then append shortcut.
	for i in "${!options[@]}"; do
		row="${options[i]}"
		left_text="${row%%|*}"
		shortcut="${row#*|}"
		options[i]="$(printf "%-${left_width}s        %s" "$left_text" "$shortcut")"
	done

	if pgrep -x rofi >/dev/null; then
		pkill rofi
		return 0
	fi

	"${XDG_CONFIG_HOME:-$HOME/.config}/hypr/scripts/RofiFocusedWallpaperLink.sh" >/dev/null 2>&1 || true
	choice="$(printf '%s\n' "${options[@]}" | rofi -i -dmenu -p "Workspace layout" -mesg "Select layout for this workspace" -selected-row "$default_row" -config "$rofi_config")"
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
