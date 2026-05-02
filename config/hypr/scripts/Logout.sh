#!/usr/bin/env bash
# ==================================================
#  KoolDots (2026)
#  Project URL: https://github.com/LinuxBeginnings
#  License: GNU GPLv3
#  SPDX-License-Identifier: GPL-3.0-or-later
# ==================================================
# Logout helper for wlogout and keybind callers.

# Close wlogout if it is still visible.
pkill -x wlogout >/dev/null 2>&1 || true
# Prevent these background apps from blocking hyprshutdown confirmation.
pkill -x awww-daemon >/dev/null 2>&1 || true
pkill -x swww-daemon >/dev/null 2>&1 || true
pkill -x waybar >/dev/null 2>&1 || true

if command -v hyprshutdown >/dev/null 2>&1; then
    exec "$(command -v hyprshutdown)"
fi

if command -v hyprctl >/dev/null 2>&1; then
    exec "$(command -v hyprctl)" dispatch exit 0
fi

exit 1
