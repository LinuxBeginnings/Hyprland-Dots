#!/usr/bin/env bash
# ==================================================
#  KoolDots (2026)
#  Project URL: https://github.com/LinuxBeginnings
#  License: GNU GPLv3
#  SPDX-License-Identifier: GPL-3.0-or-later
# ==================================================
# Purpose:
#   Post-layout refresh. After the monitor set has changed - a hotplug, a lid
#   event, a login - put the wallpaper back and make Waybar match the monitors
#   that are there now:
#
#     LidSwitch.sh refresh
#
#   That is the whole script. The name is kept on purpose: user_laptops.lua
#   resolves this path, so renaming the file would break existing installs.
#
#   Lid close and lid open are NOT handled here. UserConfigs/user_laptops.lua
#   binds the lid switch, reads the lid state from sysfs, and decides whether the
#   internal panel should be on - from the same UserConfigs/monitors.lua this
#   refresh runs after, so the two agree.
#
#   The close/open handlers that used to live here were a second binding for one
#   switch, and whichever ran last won. Both were also wrong: close switched the
#   internal panel off even with no external monitor to show the session, and
#   open replayed a stored rule that omitted `disabled`, which does not switch an
#   output back on. Fixing them meant duplicating the lid logic, so they are gone
#   instead - do not add lid handling back to this file.
set -euo pipefail

ACTION="${1:-}"
LOGFILE="${XDG_RUNTIME_DIR:-/run/user/$(id -u)}/hypr_lid.log"
SCRIPTSDIR="${XDG_CONFIG_HOME:-$HOME/.config}/hypr/scripts"

log() {
    printf '%s - %s\n' "$(date '+%Y-%m-%d %H:%M:%S')" "$*" >> "$LOGFILE" 2>&1 || true
}

# A process that has already exited (state Z) or is dumping core (state D)
# still answers `pgrep`, but neither is a bar anyone can see: signalling one
# would leave the session with no bar at all. So ask the question WaybarStartup
# asks - "is there a bar?" - rather than "is a process named waybar there?"
# `ps` ships in the same procps package as the `pgrep`/`pkill` used here, and a
# process whose state cannot be read is kept, so the conservative answer wins.
is_waybar_running() {
    local name pid state
    for name in waybar '\.waybar-wrapped'; do
        for pid in $(pgrep -x "$name" 2>/dev/null || true); do
            kill -0 "$pid" 2>/dev/null || continue
            state="$(ps -o stat= -p "$pid" 2>/dev/null | tr -d '[:space:]')"
            case "$state" in
                Z*|D*) continue ;;
            esac
            return 0
        done
    done
    return 1
}

# is_waybar_running() with a moment of patience.
#
# The wallpaper step of a refresh tells Waybar to reload its CSS, so by the time
# this script asks whether a bar is there, waybar can be in state D reading that
# file - and D is deliberately not a bar, because a bar dumping core is in D as
# well. One read is therefore not enough to conclude that there is no bar: a
# busy one clears D within a tick or two, a dying one does not. The first read
# is immediate, so a bar that is plainly running costs nothing.
is_waybar_running_settled() {
    local attempt
    for attempt in 1 2 3 4 5 6; do
        is_waybar_running && return 0
        sleep 0.2
    done
    return 1
}

handle_refresh() {
    # A single monitor hotplug or lid toggle fires several events in a row
    # (monitor.added for each output, lid switch, DPMS). Coalesce them into one
    # refresh with a non-blocking lock so we never run the work concurrently.
    local lock_file="${XDG_RUNTIME_DIR:-/run/user/$(id -u)}/hypr-lid-refresh.lock"
    exec 9>"$lock_file"
    if command -v flock >/dev/null 2>&1; then
        if ! flock -n 9; then
            exec 9>&-
            return 0
        fi
    fi

    log "Handling post-layout refresh (wallpaper and waybar)"

    # Settle time for Hyprland DRM modesetting and Wayland output registration
    sleep 0.3

    # Ensure DPMS is turned on for active displays. The Lua parser rejects the
    # legacy `dispatch dpms on` form, so use the hl.dsp dispatcher.
    hyprctl dispatch hl.dsp.dpms '{ action = "on" }' >> "$LOGFILE" 2>&1 || true

    # Restore wallpaper on all active displays. 9>&- : the lock above is held on
    # fd 9, and flock keeps it until every descriptor on the open file
    # description is closed - so a child that inherits fd 9 holds the lock for
    # its whole lifetime and every later refresh is skipped as "already running".
    if [ -x "$SCRIPTSDIR/WallpaperDaemon.sh" ]; then
        "$SCRIPTSDIR/WallpaperDaemon.sh" >> "$LOGFILE" 2>&1 9>&- || true
    fi

    # Refresh Waybar so its layer surfaces match the updated monitor positions.
    # We only signal a running bar; a missing bar is (re)started through
    # WaybarStartup.sh, which serializes on the shared Waybar lock. Never call
    # Refresh.sh here: its kill+respawn path raced with concurrent monitor
    # events and produced duplicate bars.
    #
    # The check is settled rather than a single read, because the wallpaper step
    # above has just told Waybar to reload: a bar reading its CSS is in state D,
    # which is not a bar by is_waybar_running()'s definition, and deciding on
    # that one read starts a second bar beside a perfectly good one.
    if is_waybar_running_settled; then
        pkill -SIGUSR2 -x waybar >> "$LOGFILE" 2>&1 || true
        sleep 0.2
    elif [ -x "$SCRIPTSDIR/WaybarStartup.sh" ]; then
        "$SCRIPTSDIR/WaybarStartup.sh" >> "$LOGFILE" 2>&1 9>&- || true
    fi

    exec 9>&-
}

case "$ACTION" in
    refresh) handle_refresh ;;
    "" | -h | --help)
        printf 'usage: LidSwitch.sh refresh\n'
        printf 'Lid close/open is handled by UserConfigs/user_laptops.lua, not here.\n'
        ;;
    *)
        log "Unknown action: $ACTION"
        exit 1
        ;;
esac
