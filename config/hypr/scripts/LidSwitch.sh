#!/usr/bin/env bash
# ==================================================
#  KoolDots (2026) - Laptop Lid Switch Handler
# ==================================================

ACTION="${1:-check}"
LOGFILE="/tmp/hypr_lid.log"

echo "$(date '+%Y-%m-%d %H:%M:%S') - Lid event triggered: $ACTION" >> "$LOGFILE"

if [ "$ACTION" = "close" ]; then
    hyprctl keyword monitor "eDP-1, disable" >> "$LOGFILE" 2>&1
elif [ "$ACTION" = "open" ]; then
    hyprctl keyword monitor "eDP-1, preferred, auto, 1" >> "$LOGFILE" 2>&1
fi
