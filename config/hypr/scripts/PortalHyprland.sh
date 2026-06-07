#!/usr/bin/env bash
# ==================================================
#  KoolDots (2026)
#  Project URL: https://github.com/LinuxBeginnings
#  License: GNU GPLv3
#  SPDX-License-Identifier: GPL-3.0-or-later
# ==================================================
# For manually starting xdg-desktop-portal-hyprland

set -euo pipefail
is_ubuntu_family() {
  if [[ ! -r /etc/os-release ]]; then
    return 1
  fi

  # shellcheck disable=SC1091
  . /etc/os-release
  [[ "${ID:-}" == "ubuntu" \
    || "${ID:-}" == "linuxmint" \
    || "${ID:-}" == "zorin" \
    || "${ID:-}" == "rhino" \
    || "${ID_LIKE:-}" == *ubuntu* ]]
}

kill_quietly() {
  killall -q "$1" 2>/dev/null || true
}

start_portal_binary() {
  local description="$1"
  shift
  for candidate in "$@"; do
    if [[ -x "$candidate" ]]; then
      "$candidate" &
      return 0
    fi
  done
  echo "Warning: no $description binary found (checked: $*)" >&2
  return 1
}
if ! is_ubuntu_family; then
  exit 0
fi

sleep 1
kill_quietly xdg-desktop-portal-hyprland
kill_quietly xdg-desktop-portal-wlr
kill_quietly xdg-desktop-portal-gnome
kill_quietly xdg-desktop-portal-gtk
kill_quietly xdg-desktop-portal
sleep 1

start_portal_binary "xdg-desktop-portal-hyprland" \
  /usr/lib/xdg-desktop-portal-hyprland \
  /usr/libexec/xdg-desktop-portal-hyprland

sleep 2

start_portal_binary "xdg-desktop-portal-gtk" \
  /usr/lib/xdg-desktop-portal-gtk \
  /usr/libexec/xdg-desktop-portal-gtk

start_portal_binary "xdg-desktop-portal" \
  /usr/lib/xdg-desktop-portal \
  /usr/libexec/xdg-desktop-portal

