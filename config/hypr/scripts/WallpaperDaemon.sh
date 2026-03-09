#!/usr/bin/env bash
# ==================================================
#  KoolDots (2026)
#  Project URL: https://github.com/LinuxBeginnings
#  License: GNU GPLv3
#  SPDX-License-Identifier: GPL-3.0-or-later
# ==================================================
# Start wallpaper daemon, preferring awww with swww fallback

if command -v awww-daemon >/dev/null 2>&1 && command -v awww >/dev/null 2>&1; then
  awww-daemon --format xrgb
elif command -v swww-daemon >/dev/null 2>&1 && command -v swww >/dev/null 2>&1; then
  swww-daemon --format xrgb
fi
