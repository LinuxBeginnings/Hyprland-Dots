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
# Ask the display-layout controller which Waybar config to run. With a
# per-layout bar restriction in place that is a generated file; without the
# feature installed, or if anything about it fails, this falls back to the plain
# config so this script keeps working on its own.
#
# The fallback directory is passed in rather than read from a variable: a bare
# ${waybar_dir} expands to nothing - and then to "/config" - unless the caller
# happens to have set it.
kooldots_waybar_config() {
  local fallback_dir=$1
  local dp="${XDG_CONFIG_HOME:-$HOME/.config}/hypr/scripts/DisplayProfile.sh" p=""
  if [ -x "$dp" ]; then
    p="$("$dp" waybar-config 2>/dev/null | tail -n1 || true)"
  fi
  if [ -n "$p" ] && [ -f "$p" ]; then printf '%s\n' "$p"
  else printf '%s\n' "$fallback_dir/config"; fi
}

WAYBAR_CONFIG_ARG="$(kooldots_waybar_config "$WAYBAR_DIR")"
WAYBAR_STYLE_ARG="$WAYBAR_DIR/style.css"
# How long a start holds the lock after process detection to allow GTK/socket
# initialization before external reloads are permitted.
WAYBAR_SETTLE_DELAY="${WAYBAR_SETTLE_DELAY:-0.4}"
# How long a stop waits for the bar to leave the process table, in 0.1s ticks.
# Overridable so the test suite does not have to sleep it out.
WAYBAR_EXIT_WAIT_TICKS="${WAYBAR_EXIT_WAIT_TICKS:-30}"

# Any process at all matching a waybar name, in any state. This is a question
# about the process table, not about whether the user has a bar: a process that
# is dumping core matches here and still has to be escalated against, while
# is_waybar_running() is what decides whether there is a bar on screen.
waybar_processes_present() {
    pgrep -x "waybar" >/dev/null 2>&1 || pgrep -x '\.waybar-wrapped' >/dev/null 2>&1
}

# waybar_live_pids <exact process name> -> the PIDs that are alive and usable.
#
# `pgrep` matches a process in any state, and two of those states are not a bar:
#   Z - it has already exited and is only waiting to be reaped;
#   D - uninterruptible sleep, which is what this bar looks like while it dumps
#       core after a signal. It cannot be interrupted while it finishes.
# Neither is a bar anyone can see, and taking one for a running bar is what let
# a restart skip its own launch and leave the session with no bar until the
# next attempt.
#
# `ps` ships in the same procps package as the `pgrep`/`pkill` this script
# already depends on, so it is no new requirement. A process that disappears
# between the pgrep and the state read is skipped; one whose state cannot be
# read at all is kept, because guessing "not running" there would start a
# second bar, and a duplicate is worse than a delay.
waybar_live_pids() {
    local name=$1 pid state
    for pid in $(pgrep -x "$name" 2>/dev/null); do
        kill -0 "$pid" 2>/dev/null || continue
        state="$(ps -o stat= -p "$pid" 2>/dev/null | tr -d '[:space:]')"
        case "$state" in
            Z*|D*) continue ;;
        esac
        printf '%s\n' "$pid"
    done
}

is_waybar_running() {
    [ -n "$(waybar_live_pids "waybar")" ] || [ -n "$(waybar_live_pids '\.waybar-wrapped')" ]
}

# waybar_processes_alive <exact process name> -> every PID that is still there.
#
# The same question as waybar_live_pids, asked for a different purpose.
# `dedupe_waybar_instances` has to end with exactly one bar, so a process that
# waybar_live_pids would not call a bar - one caught in state D while it reads
# its CSS and fonts, or one that is dumping core - still has to be seen. Missing
# it is how a second bar survived a start: the state is read once, waybar is
# mid-reload at that instant, and the leftover is then invisible to the clean-up
# that exists to reap it. Only Z (exited, awaiting reap) is definitely gone.
waybar_processes_alive() {
    local name=$1 pid state
    for pid in $(pgrep -x "$name" 2>/dev/null); do
        kill -0 "$pid" 2>/dev/null || continue
        state="$(ps -o stat= -p "$pid" 2>/dev/null | tr -d '[:space:]')"
        case "$state" in
            Z*) continue ;;
        esac
        printf '%s\n' "$pid"
    done
}

wait_for_waybar() {
    for _ in $(seq 1 80); do
        if is_waybar_running; then
            if [ "$(printf '%s' "$WAYBAR_SETTLE_DELAY" | tr -d '0.')" != "" ]; then
                sleep "$WAYBAR_SETTLE_DELAY"
            fi
            return 0
        fi
        sleep 0.1
    done
    return 1
}

# Wait for the last usable bar to leave, up to ~3s. A bar that was just
# signalled does not always go at once: its exit path can take a moment, and
# while it is still in the process table a relaunch would see it and skip
# itself. A process that is already dumping core is not waited for - it is not a
# bar, and it cannot be hurried.
wait_for_waybar_exit() {
    for _ in $(seq 1 "$WAYBAR_EXIT_WAIT_TICKS"); do
        is_waybar_running || return 0
        sleep 0.1
    done
    return 1
}

wait_for_wayland() {
    if [ -z "${WAYLAND_DISPLAY:-}" ] || [ ! -S "$runtime_dir/$WAYLAND_DISPLAY" ]; then
        for _ in $(seq 1 30); do
            for socket in "$runtime_dir"/wayland-[0-9]*; do
                [ -S "$socket" ] || continue
                case "$(basename "$socket")" in
                    *awww*) continue ;;
                esac
                export WAYLAND_DISPLAY="$(basename "$socket")"
                break 2
            done
            sleep 0.1
        done
    fi

    if [ -z "${HYPRLAND_INSTANCE_SIGNATURE:-}" ]; then
        for sig_dir in "$runtime_dir"/hypr/*/; do
            [ -S "${sig_dir}.socket.sock" ] || continue
            export HYPRLAND_INSTANCE_SIGNATURE="$(basename "$sig_dir")"
            break
        done
    fi
}

sync_portal_env() {
    if command -v dbus-update-activation-environment >/dev/null 2>&1; then
        dbus-update-activation-environment --systemd \
            WAYLAND_DISPLAY HYPRLAND_INSTANCE_SIGNATURE XDG_CURRENT_DESKTOP XDG_SESSION_DESKTOP XDG_SESSION_TYPE XDG_DATA_DIRS GSETTINGS_SCHEMA_DIR WEATHER_UNITS >/dev/null 2>&1 || true
    fi
    if command -v systemctl >/dev/null 2>&1; then
        systemctl --user import-environment \
            WAYLAND_DISPLAY HYPRLAND_INSTANCE_SIGNATURE XDG_CURRENT_DESKTOP XDG_SESSION_DESKTOP XDG_SESSION_TYPE XDG_DATA_DIRS GSETTINGS_SCHEMA_DIR WEATHER_UNITS >/dev/null 2>&1 || true
    fi
}

ensure_wallust_waybar_colors() {
    local colors_file="${XDG_CONFIG_HOME:-$HOME/.config}/hypr/waybar/wallust/colors-waybar.css"
    mkdir -p "$(dirname "$colors_file")" 2>/dev/null || true
    [ -f "$colors_file" ] || touch "$colors_file" 2>/dev/null || true
    if [ ! -s "$colors_file" ] && [ -x "$SCRIPTSDIR/WallustSwww.sh" ]; then
        # 9>&- : this runs while the shared Waybar lock is held on fd 9, and
        # flock keeps the lock until every descriptor on it is closed. A child
        # that inherits it strands the lock for its whole run, after which the
        # next WaybarStartup.sh exits without starting a bar.
        "$SCRIPTSDIR/WallustSwww.sh" >/dev/null 2>&1 9>&- &
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
#
# It then waits for the bar to actually leave. Returning while the old bar was
# still in the process table is what let the relaunch decide a bar was already
# up and skip itself. Returns non-zero if a usable bar is still there, which
# means it outlived SIGKILL as well.
stop_waybar_instances() {
    pkill -INT -x waybar >/dev/null 2>&1 || true
    pkill -INT -x '.waybar-wrapped' >/dev/null 2>&1 || true
    pkill -x waybar >/dev/null 2>&1 || true
    pkill -x '.waybar-wrapped' >/dev/null 2>&1 || true
    sleep 0.2
    # Escalate on the raw matches, not on is_waybar_running(): a process that is
    # dumping core is not a bar, but -9 is what reaps it as soon as it becomes
    # interruptible.
    if waybar_processes_present; then
        pkill -9 -x waybar >/dev/null 2>&1 || true
        pkill -9 -x '.waybar-wrapped' >/dev/null 2>&1 || true
    fi
    pkill -x waybar-weather >/dev/null 2>&1 || true
    wait_for_waybar_exit
}

# Safety net: if more than one Waybar is already alive (the historical bug),
# keep the newest instance and terminate the rest.
#
# This is the last thing standing between a race and a second bar, so it asks
# the wider question: every process that has not exited, not only the ones that
# look usable. A bar in state D is still a bar holding a surface, and leaving it
# out is exactly how a duplicate outlived the clean-up meant to reap it.
#
# The one to keep is the newest, and a process that is dumping core can never be
# it: it is older than the bar that replaced it.
dedupe_waybar_instances() {
    local pids keep count pid
    pids="$(waybar_processes_alive "waybar")"
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
    # "force" skips the already-running guard. A restart passes it: a process it
    # could not kill is not a usable bar, and a restart has to end with a bar on
    # screen rather than with nothing.
    if [ "${1:-}" != "force" ] && is_waybar_running; then
        return 0
    fi
    local log_target="${WAYBAR_LOG:-/dev/null}"
    if command -v waybar >/dev/null 2>&1; then
        waybar -c "$WAYBAR_CONFIG_ARG" -s "$WAYBAR_STYLE_ARG" 9>&- >"$log_target" 2>&1 &
        wait_for_waybar
        return 0
    fi
    if command -v .waybar-wrapped >/dev/null 2>&1; then
        .waybar-wrapped -c "$WAYBAR_CONFIG_ARG" -s "$WAYBAR_STYLE_ARG" 9>&- >"$log_target" 2>&1 &
        wait_for_waybar
        return 0
    fi
    return 1
}

main() {
    # --restart forces a clean single-instance restart; the default is
    # start-if-missing so concurrent startup callers stay idempotent.
    local mode="start" force=""
    case "${1:-}" in
        --restart|-r) mode="restart" ;;
    esac

    local lock_file="${runtime_dir}/waybar-startup-${UID:-$(id -u)}.lock"

    # Bounded lock: every Waybar start/restart funnels through here so two
    # concurrent callers can never both launch a bar. The winner holds the lock
    # until Waybar is confirmed running. Wait briefly so restart/start requests
    # in flight are serialized rather than dropped mid-kill.
    exec 9>"$lock_file"
    if command -v flock >/dev/null 2>&1; then
        local lock_timeout=3
        [ "$mode" = "restart" ] && lock_timeout=5
        if ! flock -w "$lock_timeout" 9; then
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
        # A bar that outlives the stop and the wait has outlived SIGKILL as
        # well, so it cannot be a usable bar any more. It must not veto the
        # relaunch: a restart has to end with a bar on screen.
        stop_waybar_instances || force="force"
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

    if start_waybar_direct "$force"; then
        dedupe_waybar_instances
        exec 9>&-
        exit 0
    fi
    exec 9>&-
    exit 1
}

main "$@"
