#!/usr/bin/env bash
# ==================================================
#  KoolDots (2026)
#  Project URL: https://github.com/LinuxBeginnings
#  License: GNU GPLv3
#  SPDX-License-Identifier: GPL-3.0-or-later
# ==================================================
# Dedicated startup helper for Waybar.
# Handles both systemd user service setups and direct Waybar launch.

runtime_dir="${XDG_RUNTIME_DIR:-/run/user/$(id -u)}"
export XDG_RUNTIME_DIR="$runtime_dir"
SCRIPTSDIR="${XDG_CONFIG_HOME:-$HOME/.config}/hypr/scripts"

is_waybar_running() {
    pgrep -x "waybar" >/dev/null 2>&1 || pgrep -x '\.waybar-wrapped' >/dev/null 2>&1
}
wait_for_waybar() {
    for _ in $(seq 1 80); do
        is_waybar_running && return 0
        sleep 0.1
    done
    return 1
}
ensure_wallust_waybar_colors() {
    local colors_file="${XDG_CONFIG_HOME:-$HOME/.config}/waybar/wallust/colors-waybar.css"
    [ -s "$colors_file" ] && return 0

    if [ -x "$SCRIPTSDIR/WallustSwww.sh" ]; then
        "$SCRIPTSDIR/WallustSwww.sh" >/dev/null 2>&1 || true
    fi

    for _ in $(seq 1 40); do
        [ -s "$colors_file" ] && return 0
        sleep 0.1
    done
    return 1
}
sync_portal_env() {
    if command -v dbus-update-activation-environment >/dev/null 2>&1; then
        dbus-update-activation-environment --systemd \
            WAYLAND_DISPLAY XDG_CURRENT_DESKTOP XDG_SESSION_DESKTOP XDG_SESSION_TYPE XDG_DATA_DIRS GSETTINGS_SCHEMA_DIR >/dev/null 2>&1 || true
    fi

    if command -v systemctl >/dev/null 2>&1; then
        systemctl --user import-environment \
            WAYLAND_DISPLAY XDG_CURRENT_DESKTOP XDG_SESSION_DESKTOP XDG_SESSION_TYPE XDG_DATA_DIRS GSETTINGS_SCHEMA_DIR >/dev/null 2>&1 || true
    fi
}

start_portal_services() {
    command -v systemctl >/dev/null 2>&1 || return 0

    systemctl --user start xdg-desktop-portal-hyprland.service >/dev/null 2>&1 || true
    systemctl --user start xdg-desktop-portal.service >/dev/null 2>&1 || true

    for _ in $(seq 1 50); do
        systemctl --user is-active --quiet xdg-desktop-portal.service && return 0
        sleep 0.1
    done
    return 1
}

wait_for_wayland() {
    if [ -n "${WAYLAND_DISPLAY:-}" ] && [ -S "$runtime_dir/$WAYLAND_DISPLAY" ]; then
        return 0
    fi

    for _ in $(seq 1 30); do
        for socket in "$runtime_dir"/wayland-[0-9]*; do
            [ -S "$socket" ] || continue
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

ensure_wallust_waybar_colors() {
    local colors_file="${XDG_CONFIG_HOME:-$HOME/.config}/waybar/wallust/colors-waybar.css"
    mkdir -p "$(dirname "$colors_file")" 2>/dev/null || true
    if [ ! -f "$colors_file" ]; then
        touch "$colors_file" 2>/dev/null || true
    fi
    if [ ! -s "$colors_file" ] && [ -x "$SCRIPTSDIR/WallustSwww.sh" ]; then
        "$SCRIPTSDIR/WallustSwww.sh" >/dev/null 2>&1 &
    fi
}

start_waybar_direct() {
    if command -v waybar >/dev/null 2>&1; then
        waybar >/dev/null 2>&1 &
        return 0
    fi

    if command -v .waybar-wrapped >/dev/null 2>&1; then
        .waybar-wrapped >/dev/null 2>&1 &
        return 0
    fi

    return 1
}

main() {
    is_waybar_running && exit 0
    wait_for_wayland || true
    sync_portal_env || true
    ensure_wallust_waybar_colors

    if start_waybar_via_systemd || start_waybar_direct; then
        exit 0
    fi
    exit 1
}

main
