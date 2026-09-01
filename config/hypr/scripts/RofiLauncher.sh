#!/usr/bin/env bash
# ==================================================
#  KoolDots (2026)
#  Project URL: https://github.com/LinuxBeginnings
#  License: GNU GPLv3
#  SPDX-License-Identifier: GPL-3.0-or-later
# ==================================================
# Rofi application launcher toggle script

if pidof rofi >/dev/null 2>&1; then
  pkill -x rofi 2>/dev/null || pkill rofi 2>/dev/null || true
  exit 0
fi

SCRIPTSDIR="${XDG_CONFIG_HOME:-$HOME/.config}/hypr/scripts"
if [ -x "$SCRIPTSDIR/RofiFocusedWallpaperLink.sh" ]; then
  "$SCRIPTSDIR/RofiFocusedWallpaperLink.sh" >/dev/null 2>&1 || true
fi

exec rofi -show drun -modi drun,filebrowser,run,window -config "${XDG_CONFIG_HOME:-$HOME/.config}/hypr/rofi/config.rasi"
