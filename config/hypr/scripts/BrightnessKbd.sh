#!/usr/bin/env bash
# ==================================================
#  KoolDots (2026)
#  Project URL: https://github.com/LinuxBeginnings
#  License: GNU GPLv3
#  SPDX-License-Identifier: GPL-3.0-or-later
# ==================================================
# Keyboard backlight controls using the device's native brightness steps.

set -euo pipefail

iDIR="${XDG_CONFIG_HOME:-$HOME/.config}/swaync/icons"
device="${KBD_BACKLIGHT_DEVICE:-}"

if [[ -z "$device" ]]; then
    device="$(
        brightnessctl --list 2>/dev/null |
            awk -F"'" '/^Device .*kbd_backlight/ && !device { device = $2 } END { print device }'
    )"
fi

if [[ -z "$device" ]] && command -v asusctl >/dev/null 2>&1; then
    if asusctl leds get >/dev/null 2>&1; then
        device="asus::kbd_backlight"
    fi
fi

if [[ -z "$device" ]]; then
    notify-send -u normal "Keyboard backlight" "No keyboard backlight was detected" >/dev/null 2>&1 || true
    exit 1
fi

read_asus_state() {
    asusctl leds get 2>/dev/null |
        awk -F': ' '/Current keyboard led brightness/ { val = tolower($2); gsub(/^[[:space:]]+|[[:space:]]+$/, "", val); print val; exit }'
}

backend=brightnessctl
if [[ "$device" == "asus::kbd_backlight" ]] && command -v asusctl >/dev/null 2>&1; then
    case "$(read_asus_state || true)" in
        off|low|med|high) backend=asusctl ;;
    esac
fi

read_state() {
    if [[ "$backend" == "asusctl" ]]; then
        level_name="$(read_asus_state)"
        case "$level_name" in
            off) current=0 ;;
            low) current=1 ;;
            med) current=2 ;;
            high) current=3 ;;
            *) return 1 ;;
        esac
        maximum=3
    else
        current="$(brightnessctl -d "$device" get 2>/dev/null || echo 0)"
        maximum="$(brightnessctl -d "$device" max 2>/dev/null || echo 1)"
        [[ "$current" =~ ^[0-9]+$ && "$maximum" =~ ^[1-9][0-9]*$ ]]
    fi

    (( maximum < 1 )) && maximum=1
    percent=$(( (current * 100 + maximum / 2) / maximum ))
}

select_icon() {
    if (( percent <= 20 )); then
        icon="$iDIR/brightness-20.png"
    elif (( percent <= 40 )); then
        icon="$iDIR/brightness-40.png"
    elif (( percent <= 60 )); then
        icon="$iDIR/brightness-60.png"
    elif (( percent <= 80 )); then
        icon="$iDIR/brightness-80.png"
    else
        icon="$iDIR/brightness-100.png"
    fi
}

notify_state() {
    local message
    select_icon

    if [[ "$backend" == "asusctl" ]]; then
        message="${level_name^}"
        notify-send -e -u low -i "$icon" \
            -h string:x-canonical-private-synchronous:keyboard_backlight \
            -h boolean:SWAYNC_BYPASS_DND:true \
            "Keyboard backlight" "$message" >/dev/null 2>&1 || true
    else
        message="Level $current of $maximum ($percent%)"
        notify-send -e -u low -i "$icon" \
            -h string:x-canonical-private-synchronous:keyboard_backlight \
            -h "int:value:$percent" \
            -h boolean:SWAYNC_BYPASS_DND:true \
            "Keyboard backlight" "$message" >/dev/null 2>&1 || true
    fi
}

change_level() {
    local action="$1"
    local previous previous_name step target

    read_state
    previous="$current"

    if [[ "$backend" == "asusctl" ]]; then
        previous_name="$level_name"
        if [[ "$action" == "dec" ]]; then
            asusctl leds prev >/dev/null 2>&1
        else
            asusctl leds next >/dev/null 2>&1
        fi
        read_state

        # next/prev wrap. Brightness keys should stop at the boundaries;
        # only the dedicated cycle action is allowed to wrap.
        if [[ "$action" == "inc" ]] && (( current <= previous )); then
            asusctl leds set "$previous_name" >/dev/null 2>&1
            read_state
        elif [[ "$action" == "dec" ]] && (( current >= previous )); then
            asusctl leds set "$previous_name" >/dev/null 2>&1
            read_state
        fi
    else
        step=$(( maximum <= 10 ? 1 : (maximum + 9) / 10 ))
        case "$action" in
            inc)
                target=$((current + step))
                (( target > maximum )) && target="$maximum"
                ;;
            dec)
                target=$((current - step))
                (( target < 0 )) && target=0
                ;;
            cycle)
                if (( current >= maximum )); then
                    target=0
                else
                    target=$((current + step))
                    (( target > maximum )) && target="$maximum"
                fi
                ;;
        esac
        if (( target != current )); then
            brightnessctl -q -d "$device" set "$target" >/dev/null 2>&1 || true
            read_state
        fi
    fi

    notify_state
}

case "${1:---get}" in
    --get)
        read_state
        printf '%s%%\n' "$percent"
        ;;
    --inc) change_level inc ;;
    --dec) change_level dec ;;
    --cycle|--toggle) change_level cycle ;;
    *)
        printf 'Usage: %s {--get|--inc|--dec|--cycle}\n' "${0##*/}" >&2
        exit 2
        ;;
esac
