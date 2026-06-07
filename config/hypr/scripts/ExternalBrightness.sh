#!/usr/bin/env bash
# ==================================================
#  KoolDots (2026)
#  Project URL: https://github.com/LinuxBeginnings
#  License: GNU GPLv3
#  SPDX-License-Identifier: GPL-3.0-or-later
# ==================================================
# External monitor brightness via ddcutil with dynamic monitor detection

set -u

# Configuration
step=10
min=5
vcp_code=10  # MCCS VCP feature 0x10: Luminance (brightness)
state_file="/tmp/external_brightness_bus"
cache_file="/tmp/external_brightness_displays.cache"
cache_ttl=300 # 5 minutes

# Detect active Hyprland config mode (Lua entrypoint vs legacy .conf includes)
config_home="${XDG_CONFIG_HOME:-$HOME/.config}"
hypr_dir="$config_home/hypr"
lua_entry="$hypr_dir/hyprland.lua"
legacy_lua_entry="$config_home/hyprland.lua"

if [[ -n "${HYPR_CONFIG_MODE:-}" ]]; then
    case "${HYPR_CONFIG_MODE,,}" in
        lua) hypr_config_mode="lua" ;;
        conf|hyprlang) hypr_config_mode="conf" ;;
        auto) hypr_config_mode="" ;;
        *) hypr_config_mode="" ;;
    esac
fi

if [[ -z "${hypr_config_mode:-}" ]]; then
    if [[ -f "$lua_entry" || -f "$legacy_lua_entry" ]]; then
        hypr_config_mode="lua"
    else
        hypr_config_mode="conf"
    fi
fi

# Get list of displays: bus model index
# Format: BUS|MODEL|INDEX
get_displays() {
    if [[ -f "$cache_file" ]]; then
        local now mtime
        now=$(date +%s)
        mtime=$(stat -c %Y "$cache_file")
        if (( now - mtime < cache_ttl )); then
            cat "$cache_file"
            return
        fi
    fi

    local res
    res=$(ddcutil detect --terse 2>/dev/null | awk '
        /^Display/ { 
            if (bus) {
                count[model]++
                print bus "|" model "|" count[model]
            }
            bus=""; model="Unknown"
        }
        /I2C bus:/ { bus=$0; sub(/.*\/dev\/i2c-/, "", bus) }
        /Model:/ { model=$0; sub(/.*Model:[[:space:]]*/, "", model) }
        END { 
            if (bus) {
                count[model]++
                print bus "|" model "|" count[model]
            }
        }
    ')
    
    if [[ -n "$res" ]]; then
        echo "$res" > "$cache_file"
        echo "$res"
    fi
}

get_active_bus() {
    local displays
    displays=$(get_displays)
    if [[ -z "$displays" ]]; then
        return 1
    fi
    
    local saved
    if [[ -f "$state_file" ]]; then
        saved=$(cat "$state_file")
        # Check if saved bus still exists in current displays
        if echo "$displays" | grep -q "^$saved|"; then
            echo "$saved"
            return 0
        fi
    fi
    
    # Default to first display's bus
    echo "$displays" | head -n 1 | cut -d'|' -f1
}

set_active_bus() {
    echo "$1" > "$state_file"
}

cycle_display() {
    local displays
    displays=$(get_displays)
    [[ -z "$displays" ]] && return 1
    
    local current
    current=$(get_active_bus) || return 1
    
    local next
    next=$(echo "$displays" | awk -v current="$current" -F'|' '
        {
            a[n++] = $1
        }
        END {
            for (i=0; i<n; i++) {
                if (a[i] == current) {
                    print a[(i+1)%n]
                    exit
                }
            }
            print a[0]
        }
    ')
    set_active_bus "$next"
}

ddcutil_cmd() {
    local bus="$1"
    shift
    ddcutil --bus "$bus" ${DDCUTIL_OPTS:-} "$@"
}

get_brightness() {
    local bus="$1"
    local line
    if ! line="$(ddcutil_cmd "$bus" getvcp "$vcp_code" 2>/dev/null | tail -n 1)"; then
        return 1
    fi

    local current max
    current="$(sed -n 's/.*current value = *\([0-9]\+\).*/\1/p' <<< "$line")"
    max="$(sed -n 's/.*max value = *\([0-9]\+\).*/\1/p' <<< "$line")"

    [[ -n "$current" && -n "$max" ]] || return 1
    printf "%s %s\n" "$current" "$max"
}

set_brightness() {
    local bus="$1"
    local value="$2"
    ddcutil_cmd "$bus" setvcp "$vcp_code" "$value" >/dev/null 2>&1
}

json_output() {
    local displays
    displays=$(get_displays)
    if [[ -z "$displays" ]]; then
        printf '{"text":"󰃜 N/A","tooltip":"No DDC/CI displays detected","class":"brightness-external-off"}\n'
        return 0
    fi

    local active_bus
    active_bus=$(get_active_bus) || return 1
    
    local current max percent
    if ! read -r current max < <(get_brightness "$active_bus"); then
        current="N/A"
        percent="N/A"
    else
        percent=$(( current * 100 / max ))
    fi

    # Build tooltip
    local tooltip=""
    local active_name="Unknown"
    
    while IFS='|' read -r bus model index; do
        local name="${model}"
        [[ $index -gt 1 ]] && name="${name} #${index}"
        
        if [[ "$bus" == "$active_bus" ]]; then
            tooltip="${tooltip}[ ${name} ]\\n"
            active_name="$name"
        else
            tooltip="${tooltip}${name}\\n"
        fi
    done <<< "$displays"
    
    tooltip="${tooltip}\\nBrightness: ${percent}%\\nClick to switch display"
    
    local icon="󰃟"
    if [[ "$percent" != "N/A" ]]; then
        if (( percent >= 80 )); then icon="󰃠";
        elif (( percent >= 60 )); then icon="󰃟";
        elif (( percent >= 40 )); then icon="󰃞";
        elif (( percent >= 20 )); then icon="󰃝";
        else icon=""; fi
        printf '{"text":"%s %s%%","tooltip":"%s","class":"brightness-external"}\n' "$icon" "$percent" "$tooltip"
    else
        printf '{"text":"󰃜 %s","tooltip":"%s","class":"brightness-external-off"}\n' "$current" "$tooltip"
    fi
}

case "${1:-}" in
    --get|"")
        json_output
        ;;
    --inc|--dec)
        bus=$(get_active_bus) || exit 0
        read -r current max < <(get_brightness "$bus") || { json_output; exit 0; }
        delta=$step
        [[ "$1" == "--dec" ]] && delta=$(( -step ))
        new=$(( current + delta ))
        (( new < min )) && new=$min
        (( new > max )) && new="$max"
        set_brightness "$bus" "$new"
        json_output
        ;;
    --set)
        [[ -n "${2:-}" ]] || exit 1
        bus=$(get_active_bus) || exit 1
        set_brightness "$bus" "$2"
        json_output
        ;;
    --cycle)
        cycle_display
        json_output
        ;;
    --bus)
        [[ -n "${2:-}" ]] || exit 1
        set_active_bus "$2"
        shift 2
        "${0}" "${@:-"--get"}"
        ;;
    --display)
        # Compatibility with old --display N but now it expects a bus number
        # Or we could map display number to bus number
        [[ -n "${2:-}" ]] || exit 1
        bus_target=$(get_displays | awk -v target="$2" -F'|' 'NR==target {print $1}')
        if [[ -n "$bus_target" ]]; then
            set_active_bus "$bus_target"
        fi
        shift 2
        "${0}" "${@:-"--get"}"
        ;;
    -h|--help)
        echo "Usage: $0 [--get|--inc|--dec|--set N|--cycle|--bus N|--display N]"
        ;;
    *)
        exit 1
        ;;
esac
