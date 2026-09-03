#!/usr/bin/env bash
# ==================================================
#  KoolDots (2026)
#  Project URL: https://github.com/LinuxBeginnings
#  License: GNU GPLv3
#  SPDX-License-Identifier: GPL-3.0-or-later
# ==================================================
# Toggle the first detected touchpad. Set TOUCHPAD_DEVICE or define
# $Touchpad_Device in UserConfigs/Laptops.conf to override auto-detection.
# source https://github.com/hyprwm/Hyprland/discussions/4283?sort=new#discussioncomment-8648109

set -euo pipefail

notif="${XDG_CONFIG_HOME:-$HOME/.config}/swaync/images/ja.png"
laptops_conf="${XDG_CONFIG_HOME:-$HOME/.config}/hypr/UserConfigs/Laptops.conf"

touchpad_device="${TOUCHPAD_DEVICE:-}"
if [[ -z "$touchpad_device" && -f "$laptops_conf" ]]; then
    touchpad_device="$(
        awk -F= '/^\$Touchpad_Device/ {
            gsub(/[[:space:]]*/, "", $1);
            gsub(/^[[:space:]]+|[[:space:]]+$/, "", $2);
            print $2;
            exit
        }' "$laptops_conf"
    )"
fi

if [[ -z "$touchpad_device" ]]; then
    touchpad_device="$(
        hyprctl devices -j 2>/dev/null |
            jq -r 'first(.mice[]?.name | select(test("touchpad"; "i"))) // empty' || true
    )"
fi

if [[ -z "$touchpad_device" ]]; then
    notify-send -u low -i "$notif" " Touchpad" " No touchpad was detected"
    exit 1
fi

runtime_dir="${XDG_RUNTIME_DIR:-/run/user/$(id -u)}"
status_file="$runtime_dir/touchpad.status"

set_touchpad_state() {
    local state="$1"

    # Hyprland 0.55+ uses Lua-style device option paths. Keep the legacy
    # keyword as a fallback for older supported releases.
    if hyprctl -r -- keyword "device[$touchpad_device].enabled" "$state" >/dev/null 2>&1; then
        return 0
    fi

    hyprctl -r -- keyword "device:${touchpad_device}:enabled" "$state" >/dev/null
}

enable_touchpad() {
    set_touchpad_state true
    printf '%s\n' "true" >"$status_file"
    notify-send -u low -i "$notif" " Touchpad" " Enabled"
}

disable_touchpad() {
    set_touchpad_state false
    printf '%s\n' "false" >"$status_file"
    notify-send -u low -i "$notif" " Touchpad" " Disabled"
}

current_state="true"
if [[ -f "$status_file" ]]; then
    current_state="$(<"$status_file")"
fi

if [[ "$current_state" == "true" ]]; then
    disable_touchpad
else
    enable_touchpad
fi
