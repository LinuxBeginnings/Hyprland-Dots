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

set_hypr_layout() {
  local target="$1"
  local output

  output="$(hyprctl keyword general:layout "$target" 2>&1)"
  if grep -q "keyword can't work with non-legacy parsers" <<<"$output"; then
    output="$(hyprctl eval "hl.config({ general = { layout = \"${target}\" } })" 2>&1)"
  fi

  if ! grep -q "^ok$" <<<"$output"; then
    echo "$output" >&2
    return 1
  fi
}

hypr_keyword() {
  hyprctl keyword "$@" >/dev/null 2>&1 || true
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

  if ! set_hypr_layout "$target"; then
    notify-send -e -u critical -i "$notif" " Layout switch failed: $target"
    return 1
  fi

  hypr_keyword unbind SUPER,j
  hypr_keyword unbind SUPER,k
  hypr_keyword bind SUPER,j,cyclenext
  hypr_keyword bind SUPER,k,cyclenext,prev
  hypr_keyword unbind SUPER,left
  hypr_keyword unbind SUPER,right
  hypr_keyword unbind SUPER,up
  hypr_keyword unbind SUPER,down
  hypr_keyword unbind SUPER,O

  case "$target" in
  "dwindle")
    hypr_keyword bind SUPER,left,cyclenext,prev
    hypr_keyword bind SUPER,up,cyclenext,prev
    hypr_keyword bind SUPER,right,cyclenext
    hypr_keyword bind SUPER,down,cyclenext
    hypr_keyword bind SUPER,O,layoutmsg,togglesplit
    ;;
  "scrolling")
    hypr_keyword bind SUPER,left,cyclenext,prev
    hypr_keyword bind SUPER,up,cyclenext,prev
    hypr_keyword bind SUPER,right,cyclenext
    hypr_keyword bind SUPER,down,cyclenext
    ;;
  "monocle")
    hypr_keyword bind SUPER,left,layoutmsg,cycleprev
    hypr_keyword bind SUPER,up,layoutmsg,cycleprev
    hypr_keyword bind SUPER,right,layoutmsg,cyclenext
    hypr_keyword bind SUPER,down,layoutmsg,cyclenext
    ;;
  "master")
    hypr_keyword bind SUPER,left,movefocus,l
    hypr_keyword bind SUPER,right,movefocus,r
    hypr_keyword bind SUPER,up,movefocus,u
    hypr_keyword bind SUPER,down,movefocus,d
    ;;
  *)
    hypr_keyword bind SUPER,left,movefocus,l
    hypr_keyword bind SUPER,right,movefocus,r
    hypr_keyword bind SUPER,up,movefocus,u
    hypr_keyword bind SUPER,down,movefocus,d
    echo "Unknown layout: $target" >&2
    return 1
    ;;
  esac

  local actual
  actual="$(get_layout)"
  if [[ "$actual" == "$target" ]]; then
    notify-send -e -u low -i "$notif" " ${actual^} Layout"
  else
    notify-send -e -u critical -i "$notif" " Layout switch failed: still ${actual}"
    return 1
  fi
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
