#!/usr/bin/env bash
# ==================================================
#  KoolDots (2026)
#  Project URL: https://github.com/LinuxBeginnings
#  License: GNU GPLv3
#  SPDX-License-Identifier: GPL-3.0-or-later
# ==================================================
# Start wallpaper daemon, preferring awww with swww fallback

SCRIPTSDIR="$HOME/.config/hypr/scripts"
# shellcheck source=/dev/null
. "$SCRIPTSDIR/WallpaperCmd.sh"

if command -v "$WWW_DAEMON" >/dev/null 2>&1 && command -v "$WWW_CMD" >/dev/null 2>&1; then
  "$WWW_DAEMON" --format xrgb
fi
