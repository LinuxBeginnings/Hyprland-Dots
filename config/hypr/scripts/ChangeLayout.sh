#!/usr/bin/env bash
# ==================================================
#  KoolDots (2026)
#  Project URL: https://github.com/LinuxBeginnings
#  License: GNU GPLv3
#  SPDX-License-Identifier: GPL-3.0-or-later
# ==================================================
# for changing Hyprland Layouts (master, dwindle, scrolling, monocle) on the fly

notif="$HOME/.config/swaync/images/ja.png"

layouts=(master dwindle scrolling monocle)

get_layout() {
  hyprctl -j getoption general:layout | jq -r '.str'
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

set_layout() {
  local target="$1"

  hyprctl keyword general:layout "$target"
  hyprctl keyword unbind SUPER,j
  hyprctl keyword unbind SUPER,k
  hyprctl keyword unbind SUPER,left
  hyprctl keyword unbind SUPER,right
  hyprctl keyword unbind SUPER,up
  hyprctl keyword unbind SUPER,down
  hyprctl keyword unbind SUPER,O
  hyprctl keyword unbind SUPER_SHIFT,M

  case "$target" in
  "dwindle")
    hyprctl keyword bind SUPER,j,cyclenext
    hyprctl keyword bind SUPER,k,cyclenext,prev
    hyprctl keyword bind SUPER,left,cyclenext,prev
    hyprctl keyword bind SUPER,up,cyclenext,prev
    hyprctl keyword bind SUPER,right,cyclenext
    hyprctl keyword bind SUPER,down,cyclenext
    hyprctl keyword bind SUPER,O,layoutmsg,togglesplit
    notify-send -e -u low -i "$notif" " Dwindle Layout"
    ;;
  "scrolling")
    hyprctl keyword bind SUPER,j,cyclenext
    hyprctl keyword bind SUPER,k,cyclenext,prev
    hyprctl keyword bind SUPER,left,cyclenext,prev
    hyprctl keyword bind SUPER,up,cyclenext,prev
    hyprctl keyword bind SUPER,right,cyclenext
    hyprctl keyword bind SUPER,down,cyclenext
    notify-send -e -u low -i "$notif" " Scrolling Layout"
    ;;
  "monocle")
    hyprctl keyword bind SUPER,j,layoutmsg,cyclenext
    hyprctl keyword bind SUPER,k,layoutmsg,cycleprev
    hyprctl keyword bind SUPER,left,layoutmsg,cycleprev
    hyprctl keyword bind SUPER,up,layoutmsg,cycleprev
    hyprctl keyword bind SUPER,right,layoutmsg,cyclenext
    hyprctl keyword bind SUPER,down,layoutmsg,cyclenext
    hyprctl keyword bind SUPER_SHIFT,M,layoutmsg,swapnext
    notify-send -e -u low -i "$notif" " Monocle Layout"
    ;;
  "master")
    hyprctl keyword bind SUPER,j,layoutmsg,cyclenext
    hyprctl keyword bind SUPER,k,layoutmsg,cycleprev
    hyprctl keyword bind SUPER,left,movefocus,l
    hyprctl keyword bind SUPER,right,movefocus,r
    hyprctl keyword bind SUPER,up,movefocus,u
    hyprctl keyword bind SUPER,down,movefocus,d
    notify-send -e -u low -i "$notif" " Master Layout"
    ;;
  *)
    hyprctl keyword bind SUPER,j,layoutmsg,cyclenext
    hyprctl keyword bind SUPER,k,layoutmsg,cycleprev
    hyprctl keyword bind SUPER,left,movefocus,l
    hyprctl keyword bind SUPER,right,movefocus,r
    hyprctl keyword bind SUPER,up,movefocus,u
    hyprctl keyword bind SUPER,down,movefocus,d
    echo "Unknown layout: $target" >&2
    return 1
    ;;
  esac
}

current="$(get_layout)"
arg="${1:-toggle}"

case "$arg" in
init)
  set_layout "$current"
  ;;
toggle|next)
  set_layout "$(next_layout "$current")"
  ;;
master|dwindle|scrolling|monocle)
  set_layout "$arg"
  ;;
*)
  echo "Usage: $(basename "$0") [toggle|next|init|master|dwindle|scrolling|monocle]" >&2
  exit 1
  ;;
esac
