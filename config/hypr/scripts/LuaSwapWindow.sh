#!/usr/bin/env bash
# ==================================================
#  KoolDots (2026)
#  Project URL: https://github.com/LinuxBeginnings
#  License: GNU GPLv3
#  SPDX-License-Identifier: GPL-3.0-or-later
# ==================================================
# Safely swap the active window in a direction from Lua keybinds.

arg="${1:-}"
arg="${arg//\'/}"
arg="${arg//\"/}"

case "$arg" in
left|l) direction="left" ;;
right|r) direction="right" ;;
up|u) direction="up" ;;
down|d) direction="down" ;;
*) exit 0 ;;
esac

active="$(hyprctl -j activewindow 2>/dev/null)"
clients="$(hyprctl -j clients 2>/dev/null)"

has_target="$(
	jq -en --argjson active "$active" --argjson clients "$clients" --arg direction "$direction" '
		def overlaps(a1; a2; b1; b2): (a1 < b2 and b1 < a2);
		($active.address // "") as $active_address
		| ($active.workspace.id // null) as $workspace_id
		| ($active.at[0] // 0) as $ax
		| ($active.at[1] // 0) as $ay
		| ($active.size[0] // 0) as $aw
		| ($active.size[1] // 0) as $ah
		| any($clients[];
			(.address != $active_address)
			and ((.workspace.id // null) == $workspace_id)
			and (
				if $direction == "left" then
					((.at[0] + .size[0]) <= $ax) and overlaps(.at[1]; (.at[1] + .size[1]); $ay; ($ay + $ah))
				elif $direction == "right" then
					(.at[0] >= ($ax + $aw)) and overlaps(.at[1]; (.at[1] + .size[1]); $ay; ($ay + $ah))
				elif $direction == "up" then
					((.at[1] + .size[1]) <= $ay) and overlaps(.at[0]; (.at[0] + .size[0]); $ax; ($ax + $aw))
				elif $direction == "down" then
					(.at[1] >= ($ay + $ah)) and overlaps(.at[0]; (.at[0] + .size[0]); $ax; ($ax + $aw))
				else
					false
				end
			)
		)
	' 2>/dev/null
)"

[[ "$has_target" == "true" ]] || exit 0

hyprctl dispatch "hl.dsp.window.swap({ direction = \"${direction}\" })" >/dev/null 2>&1 || true
