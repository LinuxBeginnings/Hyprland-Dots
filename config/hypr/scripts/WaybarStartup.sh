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
# Waybar itself only auto-discovers ~/.config/waybar by default; it has no
# knowledge of the hypr/-owned location, so every direct launch must pass
# explicit -c/-s flags.
WAYBAR_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/hypr/waybar"
WAYBAR_CONFIG_ARG="$WAYBAR_DIR/config"
WAYBAR_STYLE_ARG="$WAYBAR_DIR/style.css"

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
            WAYLAND_DISPLAY XDG_CURRENT_DESKTOP XDG_SESSION_DESKTOP XDG_SESSION_TYPE XDG_DATA_DIRS GSETTINGS_SCHEMA_DIR WEATHER_UNITS >/dev/null 2>&1 || true
    fi
    if command -v systemctl >/dev/null 2>&1; then
        systemctl --user import-environment \
            WAYLAND_DISPLAY XDG_CURRENT_DESKTOP XDG_SESSION_DESKTOP XDG_SESSION_TYPE XDG_DATA_DIRS GSETTINGS_SCHEMA_DIR WEATHER_UNITS >/dev/null 2>&1 || true
    fi
}

ensure_wallust_waybar_colors() {
    local colors_file="${XDG_CONFIG_HOME:-$HOME/.config}/hypr/waybar/wallust/colors-waybar.css"
    mkdir -p "$(dirname "$colors_file")" 2>/dev/null || true
    [ -f "$colors_file" ] || touch "$colors_file" 2>/dev/null || true
    if [ ! -s "$colors_file" ] && [ -x "$SCRIPTSDIR/WallustSwww.sh" ]; then
        "$SCRIPTSDIR/WallustSwww.sh" >/dev/null 2>&1 &
    fi
}

# True when waybar.service exists and is enabled/static/active, i.e. systemd
# owns the bar. Debian/Ubuntu and Gentoo commonly ship the unit disabled or
# masked, in which case we must manage waybar ourselves.
waybar_service_enabled() {
    command -v systemctl >/dev/null 2>&1 || return 1
    systemctl --user cat waybar.service >/dev/null 2>&1 || return 1
    local enabled_state
    enabled_state="$(systemctl --user is-enabled waybar.service 2>/dev/null || true)"
    case "$enabled_state" in
        enabled|static) return 0 ;;
    esac
    systemctl --user is-active --quiet waybar.service 2>/dev/null && return 0
    return 1
}

# Use systemd to start waybar only when waybar.service is explicitly enabled.
# Returns 1 when no enabled service exists so the caller falls through to
# start_waybar_direct.
start_waybar_via_systemd() {
    waybar_service_enabled || return 1
    systemctl --user start waybar.service >/dev/null 2>&1 || return 1
    wait_for_waybar
}

# Terminate every waybar instance (and Gentoo's .waybar-wrapped shim) so a
# restart cannot leave a stale bar behind. SIGINT goes first because Waybar
# handles it for a clean shutdown, whereas SIGTERM can be blocked in processes
# that inherited Hyprland's signal mask.
stop_waybar_instances() {
    pkill -INT -x waybar >/dev/null 2>&1 || true
    pkill -INT -x '.waybar-wrapped' >/dev/null 2>&1 || true
    pkill -x waybar >/dev/null 2>&1 || true
    pkill -x '.waybar-wrapped' >/dev/null 2>&1 || true
    sleep 0.2
    if is_waybar_running; then
        pkill -9 -x waybar >/dev/null 2>&1 || true
        pkill -9 -x '.waybar-wrapped' >/dev/null 2>&1 || true
        sleep 0.1
    fi
}

# Safety net: if more than one Waybar is already alive (the historical bug),
# keep the newest instance and terminate the rest.
dedupe_waybar_instances() {
    local pids keep count pid
    pids="$(pgrep -x waybar 2>/dev/null || true)"
    [ -n "$pids" ] || return 0
    count="$(printf '%s\n' "$pids" | wc -l | tr -d ' ')"
    [ "$count" -gt 1 ] || return 0
    keep="$(printf '%s\n' "$pids" | sort -n | tail -n1)"
    for pid in $pids; do
        [ "$pid" = "$keep" ] && continue
        kill -INT "$pid" >/dev/null 2>&1 || true
    done
    sleep 0.3
    for pid in $pids; do
        [ "$pid" = "$keep" ] && continue
        if kill -0 "$pid" >/dev/null 2>&1; then
            kill -9 "$pid" >/dev/null 2>&1 || true
        fi
    done
}

start_waybar_direct() {
    if is_waybar_running; then
        return 0
    fi
    if command -v waybar >/dev/null 2>&1; then
        waybar -c "$WAYBAR_CONFIG_ARG" -s "$WAYBAR_STYLE_ARG" 9>&- >/dev/null 2>&1 &
        wait_for_waybar
        return 0
    fi
    if command -v .waybar-wrapped >/dev/null 2>&1; then
        .waybar-wrapped -c "$WAYBAR_CONFIG_ARG" -s "$WAYBAR_STYLE_ARG" 9>&- >/dev/null 2>&1 &
        wait_for_waybar
        return 0
    fi
    return 1
}

main() {
    # --restart forces a clean single-instance restart; the default is
    # start-if-missing so concurrent startup callers stay idempotent.
    local mode="start"
    case "${1:-}" in
        --restart|-r) mode="restart" ;;
    esac

    local lock_file="${runtime_dir}/waybar-startup-${UID:-$(id -u)}.lock"

    # Non-blocking lock: every Waybar start/restart funnels through here so two
    # concurrent callers can never both launch a bar. The winner holds the lock
    # until Waybar is confirmed running; losers exit and leave the winner to own
    # the lifecycle.
    exec 9>"$lock_file"
    if command -v flock >/dev/null 2>&1; then
        if ! flock -n 9; then
            exec 9>&-
            exit 0
        fi
    fi

    if [ "$mode" = "restart" ]; then
        if waybar_service_enabled; then
            systemctl --user reset-failed waybar.service >/dev/null 2>&1 || true
            systemctl --user restart waybar.service >/dev/null 2>&1 || true
            if wait_for_waybar; then
                dedupe_waybar_instances
                exec 9>&-
                exit 0
            fi
        fi
        stop_waybar_instances
    elif is_waybar_running; then
        # Already up (possibly duplicated by an older release): keep one bar.
        dedupe_waybar_instances
        exec 9>&-
        exit 0
    fi

    wait_for_wayland || true
    sync_portal_env || true
    ensure_wallust_waybar_colors

    # Try systemd first if enabled, otherwise launch directly
    if start_waybar_via_systemd; then
        dedupe_waybar_instances
        exec 9>&-
        exit 0
    fi

    if start_waybar_direct; then
        dedupe_waybar_instances
        exec 9>&-
        exit 0
    fi
    exec 9>&-
    exit 1
}

main "$@"
