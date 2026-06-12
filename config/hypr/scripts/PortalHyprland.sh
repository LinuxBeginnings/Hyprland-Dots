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
wait_for_wayland() {
  local runtime_dir="${XDG_RUNTIME_DIR:-/run/user/$(id -u)}"
  export XDG_RUNTIME_DIR="$runtime_dir"

  if [[ -n "${WAYLAND_DISPLAY:-}" && -S "$runtime_dir/$WAYLAND_DISPLAY" ]]; then
    return 0
  fi

  for _ in $(seq 1 120); do
    if [[ -n "${WAYLAND_DISPLAY:-}" && -S "$runtime_dir/$WAYLAND_DISPLAY" ]]; then
      return 0
    fi

    for socket in "$runtime_dir"/wayland-[0-9]*; do
      [[ -S "$socket" ]] || continue
      case "$(basename "$socket")" in
      *awww*) continue ;;
      esac
      export WAYLAND_DISPLAY="$(basename "$socket")"
      return 0
    done
    sleep 0.1
  done

  return 1
}

ensure_portal_env() {
  export XDG_CURRENT_DESKTOP="${XDG_CURRENT_DESKTOP:-Hyprland}"
  export XDG_SESSION_DESKTOP="${XDG_SESSION_DESKTOP:-Hyprland}"
  export XDG_SESSION_TYPE="${XDG_SESSION_TYPE:-wayland}"
  if [[ -f "/usr/share/glib-2.0/schemas/gschemas.compiled" ]]; then
    export GSETTINGS_SCHEMA_DIR="/usr/share/glib-2.0/schemas"
  fi

  local data_dirs="${XDG_DATA_DIRS:-}"
  if [[ -z "$data_dirs" ]]; then
    data_dirs="/usr/local/share:/usr/share"
  else
    if [[ ":$data_dirs:" != *":/usr/local/share:"* ]]; then
      data_dirs="/usr/local/share:$data_dirs"
    fi
    if [[ ":$data_dirs:" != *":/usr/share:"* ]]; then
      data_dirs="$data_dirs:/usr/share"
    fi
  fi
  export XDG_DATA_DIRS="$data_dirs"
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
stop_portal_processes() {
  kill_quietly xdg-desktop-portal-hyprland
  kill_quietly xdg-desktop-portal-wlr
  kill_quietly xdg-desktop-portal-gnome
  kill_quietly xdg-desktop-portal-gtk
  kill_quietly xdg-desktop-portal
}

restart_portal_via_systemd() {
  command -v systemctl >/dev/null 2>&1 || return 1
  ensure_portal_env
  if command -v dbus-update-activation-environment >/dev/null 2>&1; then
    dbus-update-activation-environment --systemd WAYLAND_DISPLAY XDG_CURRENT_DESKTOP XDG_SESSION_DESKTOP XDG_SESSION_TYPE XDG_DATA_DIRS GSETTINGS_SCHEMA_DIR >/dev/null 2>&1 || true
  fi

  systemctl --user import-environment WAYLAND_DISPLAY XDG_CURRENT_DESKTOP XDG_SESSION_DESKTOP XDG_SESSION_TYPE XDG_DATA_DIRS GSETTINGS_SCHEMA_DIR >/dev/null 2>&1 || true
  systemctl --user stop xdg-desktop-portal.service xdg-desktop-portal-hyprland.service xdg-desktop-portal-gtk.service >/dev/null 2>&1 || true
  stop_portal_processes
  sleep 0.5
  systemctl --user reset-failed xdg-desktop-portal-hyprland.service xdg-desktop-portal.service xdg-desktop-portal-gtk.service >/dev/null 2>&1 || true
  systemctl --user start graphical-session.target >/dev/null 2>&1 || true

  for _ in $(seq 1 30); do
    if systemctl --user is-active --quiet graphical-session.target; then
      break
    fi
    sleep 0.1
  done

  systemctl --user start xdg-desktop-portal-hyprland.service >/dev/null 2>&1 || true
  if is_ubuntu_family; then
    systemctl --user start xdg-desktop-portal-gtk.service >/dev/null 2>&1 || true
  fi
  systemctl --user start xdg-desktop-portal.service >/dev/null 2>&1 || true

  for _ in $(seq 1 60); do
    if systemctl --user is-active --quiet xdg-desktop-portal-hyprland.service &&
      systemctl --user is-active --quiet xdg-desktop-portal.service; then
      return 0
    fi
    sleep 0.1
  done
  return 1
}

restart_portal_manually() {
  sleep 1
  stop_portal_processes
  sleep 1

  start_portal_binary "xdg-desktop-portal-hyprland" \
    /usr/lib/xdg-desktop-portal-hyprland \
    /usr/libexec/xdg-desktop-portal-hyprland

  sleep 2

  if is_ubuntu_family; then
    start_portal_binary "xdg-desktop-portal-gtk" \
      /usr/lib/xdg-desktop-portal-gtk \
      /usr/libexec/xdg-desktop-portal-gtk || true
  fi

  start_portal_binary "xdg-desktop-portal" \
    /usr/lib/xdg-desktop-portal \
    /usr/libexec/xdg-desktop-portal
}

wait_for_wayland || true
if command -v systemctl >/dev/null 2>&1; then
  restart_portal_via_systemd || true
else
  restart_portal_manually
fi

