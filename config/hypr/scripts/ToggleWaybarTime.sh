#!/usr/bin/env bash
# ==================================================
#  KoolDots (2026)
#  Project URL: https://github.com/LinuxBeginnings
#  License: GNU GPLv3
#  SPDX-License-Identifier: GPL-3.0-or-later
# ==================================================
# Toggle Waybar clock format between 12H and 24H

MODULES_FILE="${XDG_CONFIG_HOME:-$HOME/.config}/waybar/Modules"
notify_swaync() {
  command -v notify-send >/dev/null 2>&1 || return 0
  local icon="${XDG_CONFIG_HOME:-$HOME/.config}/swaync/images/note.png"
  notify-send -a "Waybar Time" -u low -t 2000 -i "$icon" "$@" >/dev/null 2>&1 || true
}

if [ ! -f "$MODULES_FILE" ]; then
  notify_swaync "Modules file not found: $MODULES_FILE"
  exit 1
fi

is_12h_active() {
  grep -qE '^[[:space:]]*"format":[[:space:]]*" {:%I:%M %p}"' "$MODULES_FILE"
}

apply_12h() {
  sed -i 's#^\([[:space:]]*\)//\("format": " {:%I:%M %p}".*\)#\1\2#' "$MODULES_FILE"
  sed -i 's#^\([[:space:]]*\)\("format": " {:%H:%M:%S}".*\)#\1//\2#' "$MODULES_FILE"
  sed -i 's#^\([[:space:]]*\)\("format": "  {:%H:%M}".*\)#\1//\2#' "$MODULES_FILE"
  sed -i 's#^\([[:space:]]*\)//\("format": "{:%I:%M %p - %d/%b}".*\)#\1\2#' "$MODULES_FILE"
  sed -i 's#^\([[:space:]]*\)\("format": "{:%H:%M - %d/%b}".*\)#\1//\2#' "$MODULES_FILE"
  sed -i 's#^\([[:space:]]*\)//\("format": "{:%B | %a %d, %Y | %I:%M %p}".*\)#\1\2#' "$MODULES_FILE"
  sed -i 's#^\([[:space:]]*\)\("format": "{:%B | %a %d, %Y | %H:%M}".*\)#\1//\2#' "$MODULES_FILE"
  sed -i 's#^\([[:space:]]*\)//\("format": "{:%A, %I:%M %P}".*\)#\1\2#' "$MODULES_FILE"
  sed -i 's#^\([[:space:]]*\)\("format": "{:%a %d | %H:%M}".*\)#\1//\2#' "$MODULES_FILE"
}

apply_24h() {
  sed -i 's#^\([[:space:]]*\)\("format": " {:%I:%M %p}".*\)#\1//\2#' "$MODULES_FILE"
  sed -i 's#^\([[:space:]]*\)//\("format": " {:%H:%M:%S}".*\)#\1\2#' "$MODULES_FILE"
  sed -i 's#^\([[:space:]]*\)//\("format": "  {:%H:%M}".*\)#\1\2#' "$MODULES_FILE"
  sed -i 's#^\([[:space:]]*\)\("format": "{:%I:%M %p - %d/%b}".*\)#\1//\2#' "$MODULES_FILE"
  sed -i 's#^\([[:space:]]*\)//\("format": "{:%H:%M - %d/%b}".*\)#\1\2#' "$MODULES_FILE"
  sed -i 's#^\([[:space:]]*\)\("format": "{:%B | %a %d, %Y | %I:%M %p}".*\)#\1//\2#' "$MODULES_FILE"
  sed -i 's#^\([[:space:]]*\)//\("format": "{:%B | %a %d, %Y | %H:%M}".*\)#\1\2#' "$MODULES_FILE"
  sed -i 's#^\([[:space:]]*\)\("format": "{:%A, %I:%M %P}".*\)#\1//\2#' "$MODULES_FILE"
  sed -i 's#^\([[:space:]]*\)//\("format": "{:%a %d | %H:%M}".*\)#\1\2#' "$MODULES_FILE"
}

restart_waybar() {
  local manage_with_systemd=0

  if command -v systemctl >/dev/null 2>&1; then
    if systemctl --user --quiet is-active waybar.service 2>/dev/null || systemctl --user --quiet is-enabled waybar.service 2>/dev/null; then
      manage_with_systemd=1
    fi
  fi

  if [ "$manage_with_systemd" -eq 1 ]; then
    systemctl --user stop waybar.service >/dev/null 2>&1 || true
  fi

  pkill -x waybar >/dev/null 2>&1 || true
  pkill -x '.waybar-wrapped' >/dev/null 2>&1 || true
  sleep 0.2
  if pgrep -x waybar >/dev/null 2>&1 || pgrep -x '.waybar-wrapped' >/dev/null 2>&1; then
    pkill -9 -x waybar >/dev/null 2>&1 || true
    pkill -9 -x '.waybar-wrapped' >/dev/null 2>&1 || true
  fi
  sleep 0.2

  if [ "$manage_with_systemd" -eq 1 ]; then
    if ! systemctl --user start waybar.service >/dev/null 2>&1; then
      waybar >/dev/null 2>&1 &
    fi
  else
    waybar >/dev/null 2>&1 &
  fi
}

if is_12h_active; then
  apply_24h
  mode="24H"
else
  apply_12h
  mode="12H"
fi

if [ -x "${XDG_CONFIG_HOME:-$HOME/.config}/hypr/scripts/Refresh.sh" ]; then
  "${XDG_CONFIG_HOME:-$HOME/.config}/hypr/scripts/Refresh.sh" >/dev/null 2>&1 &
else
  restart_waybar
fi
sleep 0.3

notify_swaync "Switched to ${mode} format"
printf 'Waybar Time: switched to %s format\n' "$mode"
