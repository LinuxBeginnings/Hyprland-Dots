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

ensure_wallust_waybar_colors() {
    local colors_file="${XDG_CONFIG_HOME:-$HOME/.config}/waybar/wallust/colors-waybar.css"
    mkdir -p "$(dirname "$colors_file")" 2>/dev/null || true
    [ -f "$colors_file" ] || touch "$colors_file" 2>/dev/null || true
    if [ ! -s "$colors_file" ] && [ -x "$SCRIPTSDIR/WallustSwww.sh" ]; then
        "$SCRIPTSDIR/WallustSwww.sh" >/dev/null 2>&1 &
    fi
}

# Use systemd to start waybar only when waybar.service is explicitly enabled.
# Returns 1 on Debian/systems with no enabled service so the caller falls
# through to start_waybar_direct.
start_waybar_via_systemd() {
    command -v systemctl >/dev/null 2>&1 || return 1
    # Service must exist
    systemctl --user cat waybar.service >/dev/null 2>&1 || return 1
    # Service must be enabled (not just installed)
    local enabled_state
    enabled_state="$(systemctl --user is-enabled waybar.service 2>/dev/null || true)"
    case "$enabled_state" in
        enabled|static) ;;
        *) return 1 ;;
    esac
    systemctl --user start waybar.service >/dev/null 2>&1 || return 1
    wait_for_waybar
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
    # Brief wait so a systemd-managed waybar.service has time to appear
    # before we check; avoids a race on distros with an enabled unit.
    sleep 0.5
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
