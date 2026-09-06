#!/usr/bin/env bash
# ==================================================
#  KoolDots (2026) - Laptop Lid Switch Handler
#  Project URL: https://github.com/LinuxBeginnings
#  License: GNU GPLv3
#  SPDX-License-Identifier: GPL-3.0-or-later
# ==================================================
# Handles lid close/open events, preserving monitor mode, position, and scale.

set -euo pipefail

ACTION="${1:-check}"
LOGFILE="${XDG_RUNTIME_DIR:-/run/user/$(id -u)}/hypr_lid.log"
STATE_FILE="${XDG_RUNTIME_DIR:-/run/user/$(id -u)}/hypr_internal_monitor.json"

log() {
    printf '%s - %s\n' "$(date '+%Y-%m-%d %H:%M:%S')" "$*" >> "$LOGFILE" 2>&1 || true
}

get_internal_monitor() {
    local mon="${LAPTOP_MONITOR:-${INTERNAL_MONITOR:-}}"
    if [ -n "$mon" ]; then
        printf '%s' "$mon"
        return 0
    fi
    if command -v jq >/dev/null 2>&1; then
        mon="$(hyprctl monitors all -j 2>/dev/null | jq -r 'first(.[] | select(.name | test("^(eDP|LVDS|DSI)-"; "i")) | .name) // empty' 2>/dev/null || true)"
    fi
    if [ -z "$mon" ]; then
        mon="$(hyprctl monitors all 2>/dev/null | awk '/^Monitor (eDP|LVDS|DSI)/ {print $2; exit}' || true)"
    fi
    if [ -z "$mon" ]; then
        mon="eDP-1"
    fi
    printf '%s' "$mon"
}

save_monitor_state() {
    local mon="$1"
    mkdir -p "$(dirname "$STATE_FILE")"
    if command -v jq >/dev/null 2>&1; then
        local json
        json="$(hyprctl monitors all -j 2>/dev/null | jq -c ".[] | select(.name == \"$mon\")" 2>/dev/null || true)"
        if [ -n "$json" ]; then
            printf '%s\n' "$json" > "$STATE_FILE"
            log "Saved monitor state for $mon: $json"
            return 0
        fi
    fi
}

handle_close() {
    local mon
    mon="$(get_internal_monitor)"
    log "Handling lid close for $mon"
    save_monitor_state "$mon"

    # Disable monitor via Lua eval path (Hyprland 0.55+)
    if hyprctl -r eval "hl.monitor({ output = [[$mon]], disabled = true })" >> "$LOGFILE" 2>&1; then
        return 0
    fi

    # Fallback to legacy Hyprlang keyword
    hyprctl keyword monitor "$mon, disable" >> "$LOGFILE" 2>&1 || true
}

handle_open() {
    local mon
    mon="$(get_internal_monitor)"
    log "Handling lid open for $mon"

    local mode="preferred"
    local pos="auto"
    local scale="1"
    local width=0 height=0 rr=0 x=0 y=0

    if [ -f "$STATE_FILE" ] && command -v jq >/dev/null 2>&1; then
        width="$(jq -r '.width // 0' "$STATE_FILE" 2>/dev/null || echo 0)"
        height="$(jq -r '.height // 0' "$STATE_FILE" 2>/dev/null || echo 0)"
        rr="$(jq -r '.refreshRate // 0' "$STATE_FILE" 2>/dev/null | cut -d. -f1)"
        x="$(jq -r '.x // 0' "$STATE_FILE" 2>/dev/null || echo 0)"
        y="$(jq -r '.y // 0' "$STATE_FILE" 2>/dev/null || echo 0)"
        scale="$(jq -r '.scale // 1' "$STATE_FILE" 2>/dev/null || echo 1)"

        if (( width > 0 && height > 0 )); then
            if (( rr > 0 )); then
                mode="${width}x${height}@${rr}"
            else
                mode="${width}x${height}"
            fi
            pos="${x}x${y}"
        fi
        log "Restoring monitor $mon with mode=$mode, pos=$pos, scale=$scale"
    else
        log "No saved state for $mon, using defaults"
    fi

    # Re-enable monitor with retry loop (display controller handshake on resume)
    for _ in 1 2 3; do
        # 1. Try Lua eval path (Hyprland 0.55+)
        local lua_applied=false
        if hyprctl -r eval "hl.monitor({ output = [[$mon]], disabled = false, mode = [[$mode]], position = [[$pos]], scale = [[$scale]] })" >> "$LOGFILE" 2>&1; then
            lua_applied=true
        elif hyprctl -r eval "hl.monitor({ output = [[$mon]], disabled = false })" >> "$LOGFILE" 2>&1; then
            lua_applied=true
        fi

        # 2. Fallback to legacy keyword
        if [ "$lua_applied" = false ]; then
            hyprctl keyword monitor "$mon, $mode, $pos, $scale" >> "$LOGFILE" 2>&1 || \
            hyprctl keyword monitor "$mon, preferred, auto, 1" >> "$LOGFILE" 2>&1 || true
        fi

        # 3. Ensure DPMS is powered on
        hyprctl dispatch dpms on "$mon" >> "$LOGFILE" 2>&1 || true

        # Check if active
        if command -v jq >/dev/null 2>&1; then
            if hyprctl monitors -j 2>/dev/null | jq -e ".[] | select(.name == \"$mon\" and .disabled == false)" >/dev/null 2>&1; then
                log "Monitor $mon is active and ready"
                break
            fi
        fi
        sleep 0.2
    done
}

case "$ACTION" in
    close) handle_close ;;
    open)  handle_open ;;
    check) log "Lid check (no-op)" ;;
    *)     log "Unknown action: $ACTION"; exit 1 ;;
esac
