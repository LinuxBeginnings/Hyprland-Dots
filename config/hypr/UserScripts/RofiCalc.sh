#!/usr/bin/env bash
# ==================================================
#  KoolDots (2026)
#  Project URL: https://github.com/LinuxBeginnings
#  License: GNU GPLv3
#  SPDX-License-Identifier: GPL-3.0-or-later
# ==================================================
# /* Calculator (using qalculate) and rofi */
# /* Submitted by: https://github.com/JosephArmas */

rofi_theme="${XDG_CONFIG_HOME:-$HOME/.config}/hypr/rofi/config-calc.rasi"

# Dependency checks
for cmd in rofi qalc wl-copy; do
    if ! command -v "$cmd" >/dev/null 2>&1; then
        if command -v notify-send >/dev/null 2>&1; then
            notify-send -u critical "RofiCalc" "Missing required dependency: $cmd"
        else
            echo "Error: Missing required dependency: $cmd" >&2
        fi
        exit 1
    fi
done

CALC_LOCKFILE="/tmp/roficalc-${UID:-0}.pid"
if [[ -f "$CALC_LOCKFILE" ]]; then
    oldpid="$(cat "$CALC_LOCKFILE" 2>/dev/null || true)"
    if [[ -n "$oldpid" ]] && kill -0 "$oldpid" 2>/dev/null; then
        kill "$oldpid" 2>/dev/null || true
    fi
    rm -f "$CALC_LOCKFILE" 2>/dev/null || true
fi
printf '%d' "$$" > "$CALC_LOCKFILE" 2>/dev/null || true
trap 'rm -f "$CALC_LOCKFILE" 2>/dev/null' EXIT INT TERM

# main function
calc_result=""
result=""

while true; do
    mesg_args=()
    if [[ -n "$result" || -n "$calc_result" ]]; then
        mesg_args=(-mesg "$result      =    $calc_result")
    fi

    result=$(
        rofi -i -dmenu \
            -config "$rofi_theme" \
            "${mesg_args[@]}"
    )

    if [ $? -ne 0 ]; then
        exit 0
    fi

    if [ -n "$result" ]; then
        calc_result=$(qalc -t "$result")
        echo "$calc_result" | wl-copy
    fi
done
