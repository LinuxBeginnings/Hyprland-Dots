#!/usr/bin/env bash
# ==================================================
#  KoolDots (2026)
#  Project URL: https://github.com/LinuxBeginnings
#  License: GNU GPLv3
#  SPDX-License-Identifier: GPL-3.0-or-later
# ==================================================
# Toggle the detected or configured touchpad device.
# Set TOUCHPAD_DEVICE or define Touchpad_Device in UserConfigs (Laptops.conf or user_laptops.lua) to override auto-detection.
# source https://github.com/hyprwm/Hyprland/discussions/4283?sort=new#discussioncomment-8648109

set -euo pipefail

notif="${XDG_CONFIG_HOME:-$HOME/.config}/swaync/images/ja.png"
laptops_conf="${XDG_CONFIG_HOME:-$HOME/.config}/hypr/UserConfigs/Laptops.conf"
user_laptops_lua="${XDG_CONFIG_HOME:-$HOME/.config}/hypr/UserConfigs/user_laptops.lua"

touchpad_device="${TOUCHPAD_DEVICE:-}"

# Check Laptops.conf for legacy override
if [[ -z "$touchpad_device" && -f "$laptops_conf" ]]; then
    touchpad_device="$(
        awk -F= '/^[[:space:]]*\$Touchpad_Device/ {
            gsub(/[[:space:]]*/, "", $1);
            gsub(/^[[:space:]]+|[[:space:]]+$/, "", $2);
            print $2;
            exit
        }' "$laptops_conf"
    )"
fi

# Check user_laptops.lua for Lua override
if [[ -z "$touchpad_device" && -f "$user_laptops_lua" ]]; then
    touchpad_device="$(
        sed -nE 's/^[[:space:]]*(TOUCHPAD_DEVICE|Touchpad_Device|touchpad_device)[[:space:]]*=[[:space:]]*["'\''"]([^"'\''"]+)["'\''"].*/\2/p' "$user_laptops_lua" | tail -n1
    )"
fi

# Auto-detect touchpad from hyprctl devices
if [[ -z "$touchpad_device" ]]; then
    touchpad_device="$(
        hyprctl devices -j 2>/dev/null |
            jq -r 'first(.mice[]?.name | select(test("touchpad|trackpad|glidepoint"; "i"))) // empty' 2>/dev/null || true
    )"
fi

if [[ -z "$touchpad_device" ]]; then
    notify-send -u low -i "$notif" " Touchpad" " No touchpad was detected" 2>/dev/null || true
    exit 1
fi

runtime_dir="${XDG_RUNTIME_DIR:-/run/user/$(id -u)}"
status_file="$runtime_dir/touchpad.status"

set_touchpad_state() {
    local state="$1"

    # Hyprland 0.55+ Lua eval path
    if hyprctl -r eval "hl.device({ name = [[$touchpad_device]], enabled = $state })" >/dev/null 2>&1; then
        return 0
    fi

    # Legacy Hyprlang keyword fallback
    if hyprctl -r -- keyword "device:${touchpad_device}:enabled" "$state" >/dev/null 2>&1; then
        return 0
    fi

    hyprctl keyword "device:${touchpad_device}:enabled" "$state" >/dev/null 2>&1 || true
}

enable_touchpad() {
    set_touchpad_state true
    printf '%s\n' "true" >"$status_file"
    notify-send -u low -i "$notif" " Touchpad" " Enabled" 2>/dev/null || true
}

disable_touchpad() {
    set_touchpad_state false
    printf '%s\n' "false" >"$status_file"
    notify-send -u low -i "$notif" " Touchpad" " Disabled" 2>/dev/null || true
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
