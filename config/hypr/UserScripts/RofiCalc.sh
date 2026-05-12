#!/usr/bin/env bash
# ==================================================
#  KoolDots (2026)
#  Project URL: https://github.com/LinuxBeginnings
#  License: GNU GPLv3
#  SPDX-License-Identifier: GPL-3.0-or-later
# ==================================================
# Calculator (using qalculate) and rofi

# Kill Rofi if already running before execution
if pgrep -x "rofi" >/dev/null; then
    pkill rofi
fi

while true; do
    result=$(
        rofi -i -dmenu \
            -mesg "$result      =    $calc_result"
    )

    if [ $? -ne 0 ]; then
        exit
    fi

    if [ -n "$result" ]; then
        calc_result=$(qalc -t "$result")
        printf '%s' "$calc_result" | wl-copy
    fi
done
