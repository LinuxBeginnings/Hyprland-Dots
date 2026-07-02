#!/usr/bin/env bash
# ==================================================
#  KoolDots (2026)
#  Project URL: https://github.com/LinuxBeginnings
#  License: GNU GPLv3
#  SPDX-License-Identifier: GPL-3.0-or-later
# ==================================================
# Script for changing blurs on the fly

notif="${XDG_CONFIG_HOME:-$HOME/.config}/swaync/images"

STATE=$(hyprctl -j getoption decoration:blur:passes | jq ".int")

if [ "${STATE}" == "2" ]; then
	hyprctl keyword decoration:blur:size 2
	hyprctl keyword decoration:blur:passes 1
 	notify-send -e -u low -i "$notif/note.png" " Less Blur"
else
	hyprctl keyword decoration:blur:size 5
	hyprctl keyword decoration:blur:passes 2
  	notify-send -e -u low -i "$notif/ja.png" " Normal Blur"
fi
