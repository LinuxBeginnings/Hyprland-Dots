#!/usr/bin/env bash
# ==================================================
#  KoolDots (2026)
#  Project URL: https://github.com/LinuxBeginnings
#  License: GNU GPLv3
#  SPDX-License-Identifier: GPL-3.0-or-later
# ==================================================
# Logout helper for wlogout and keybind callers.
stop_proc() {
    local name="$1"
    pkill -x -TERM "$name" >/dev/null 2>&1 || true

    # Wait up to 1 second for graceful shutdown.
    for _ in {1..10}; do
        pgrep -x "$name" >/dev/null 2>&1 || return 0
        sleep 0.1
    done

    pkill -x -KILL "$name" >/dev/null 2>&1 || true
}

# Close wlogout if it is still visible.
stop_proc "wlogout"
# Prevent these background apps from blocking hyprshutdown confirmation.
stop_proc "awww-daemon"
stop_proc "swww-daemon"
stop_proc "waybar"

if command -v hyprshutdown >/dev/null 2>&1; then
    exec "$(command -v hyprshutdown)"
fi

if command -v hyprctl >/dev/null 2>&1; then
    exec "$(command -v hyprctl)" dispatch exit 0
fi

exit 1
