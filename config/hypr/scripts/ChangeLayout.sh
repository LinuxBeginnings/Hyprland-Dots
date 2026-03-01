#!/usr/bin/env bash
# ==================================================
#  KoolDots (2026)
#  Project URL: https://github.com/LinuxBeginnings
#  License: GNU GPLv3
#  SPDX-License-Identifier: GPL-3.0-or-later
# ==================================================
# for changing Hyprland Layouts (Master, Dwindle, scrolling, monocle) on the fly

notif="$HOME/.config/swaync/images/ja.png"

LAYOUT=$(hyprctl -j getoption general:layout | jq '.str' | sed 's/"//g')

# Reverse layout value to reuse toggle logic. So layouts don't get swapped initially.
if [ "$1" = "init" ]; then
  case "$LAYOUT" in
  "master") LAYOUT="scrolling" ;;
  "dwindle") LAYOUT="master" ;;
  "scrolling") LAYOUT="dwindle" ;;
  "monocle") LAYOUT="scrolling" ;;
  esac
fi

case $LAYOUT in
"master")
  hyprctl keyword general:layout dwindle
  hyprctl keyword unbind SUPER,J
  hyprctl keyword unbind SUPER,K
  hyprctl keyword unbind SUPER,O
  hyprctl keyword unbind SUPER_SHIFT,M
  hyprctl keyword bind SUPER,J,cyclenext
  hyprctl keyword bind SUPER,K,cyclenext,prev
  hyprctl keyword bind SUPER,O,layoutmsg,togglesplit
  notify-send -e -u low -i "$notif" " Dwindle Layout"
  ;;
"dwindle")
  hyprctl keyword general:layout scrolling
  hyprctl keyword unbind SUPER,J
  hyprctl keyword unbind SUPER,K
  hyprctl keyword unbind SUPER,O
  hyprctl keyword unbind SUPER_SHIFT,M
  hyprctl keyword bind SUPER,J,layoutmsg,cyclenext
  hyprctl keyword bind SUPER,K,layoutmsg,cycleprev
  notify-send -e -u low -i "$notif" " Scrolling Layout"
  ;;
"scrolling")
  hyprctl keyword general:layout monocle
  hyprctl keyword unbind SUPER,J
  hyprctl keyword unbind SUPER,K
  hyprctl keyword unbind SUPER,O
  hyprctl keyword unbind SUPER_SHIFT,M
  hyprctl keyword bind SUPER,J,layoutmsg,cyclenext
  hyprctl keyword bind SUPER,K,layoutmsg,cycleprev
  hyprctl keyword bind SUPER_SHIFT,M,layoutmsg,swapnext
  notify-send -e -u low -i "$notif" " Monocle Layout"
  ;;
"monocle")
  hyprctl keyword general:layout master
  hyprctl keyword unbind SUPER,J
  hyprctl keyword unbind SUPER,K
  hyprctl keyword unbind SUPER,O
  hyprctl keyword unbind SUPER_SHIFT,M
  hyprctl keyword bind SUPER,J,layoutmsg,focus l
  hyprctl keyword bind SUPER,K,layoutmsg,focus r
  notify-send -e -u low -i "$notif" " Master Layout"
  ;;
*) ;;

esac
