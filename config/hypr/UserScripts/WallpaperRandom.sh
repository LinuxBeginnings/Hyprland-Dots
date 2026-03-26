#!/usr/bin/env bash
# ==================================================
#  KoolDots (2026)
#  Project URL: https://github.com/LinuxBeginnings
#  License: GNU GPLv3
#  SPDX-License-Identifier: GPL-3.0-or-later
# ==================================================
# Script for Random Wallpaper ( CTRL ALT W)

PICTURES_DIR="$(xdg-user-dir PICTURES 2>/dev/null || echo "$HOME/Pictures")"
wallDIR="$PICTURES_DIR/wallpapers"
SCRIPTSDIR="$HOME/.config/hypr/scripts"
# shellcheck source=/dev/null
. "$SCRIPTSDIR/WallpaperCmd.sh"

focused_monitor=$(hyprctl monitors -j | jq -r '.[] | select(.focused) | .name')

PICS=($(find -L "${wallDIR}" -type f \( -name "*.jpg" -o -name "*.jpeg" -o -name "*.png" -o -name "*.pnm" -o -name "*.tga" -o -name "*.tiff" -o -name "*.webp" -o -name "*.bmp" -o -name "*.farbfeld" -o -name "*.gif" \)))
RANDOMPICS=${PICS[ $RANDOM % ${#PICS[@]} ]}


# Transition config (only when using swww)
FPS=30
TYPE="random"
DURATION=1
BEZIER=".43,1.19,1,.4"
if [[ "$WWW_CMD" == "swww" ]]; then
  SWWW_PARAMS="--transition-fps $FPS --transition-type $TYPE --transition-duration $DURATION --transition-bezier $BEZIER"
else
  SWWW_PARAMS=""
fi
if ! "$WWW_CMD" query >/dev/null 2>&1; then
  "$WWW_DAEMON" "${WWW_DAEMON_ARGS[@]}" &
fi

"$WWW_CMD" img -o "$focused_monitor" "$RANDOMPICS" $SWWW_PARAMS

wait $!
"$SCRIPTSDIR/WallustSwww.sh" "$RANDOMPICS" &&

wait $!
sleep 2
"$SCRIPTSDIR/Refresh.sh"

