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

is_waybar_running() {
    pgrep -x "waybar" >/dev/null 2>&1 || pgrep -x '\.waybar-wrapped' >/dev/null 2>&1
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
    # If WAYLAND_DISPLAY is already valid, use it.
    if [ -n "${WAYLAND_DISPLAY:-}" ] && [ -S "$runtime_dir/$WAYLAND_DISPLAY" ]; then
        return 0
    fi

    # Otherwise wait briefly for an available Wayland socket.
    for _ in $(seq 1 120); do
        if [ -n "${WAYLAND_DISPLAY:-}" ] && [ -S "$runtime_dir/$WAYLAND_DISPLAY" ]; then
            return 0
        fi

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

start_waybar_via_systemd() {
    [ -x "$(command -v systemctl)" ] || return 1

    local load_state
    load_state="$(systemctl --user show waybar.service --property=LoadState --value 2>/dev/null || true)"
    [ -n "$load_state" ] && [ "$load_state" != "not-found" ] || return 1

    systemctl --user start waybar.service >/dev/null 2>&1 || return 1
    sleep 0.4
    is_waybar_running
}

main() {
    # Allow key startup services to settle before launching Waybar.
    sleep 1
    wait_for_wayland || true
    sync_portal_env
    start_portal_services || true

    is_waybar_running && exit 0

    if start_waybar_via_systemd; then
        exit 0
    fi

    if is_waybar_running; then
        exit 0
    fi

    start_waybar_direct || exit 1
}

main
