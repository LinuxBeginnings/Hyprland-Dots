#!/usr/bin/env bash
# ==================================================
#  KoolDots (2026)
#  Project URL: https://github.com/LinuxBeginnings
#  License: GNU GPLv3
#  SPDX-License-Identifier: GPL-3.0-or-later
# ==================================================
# Wallpaper command selector (awww preferred, swww fallback)

if command -v awww >/dev/null 2>&1; then
  WWW_CMD="awww"
  WWW_DAEMON="awww-daemon"
  WWW_CACHE_DIR="$HOME/.cache/awww/"
  WWW_DAEMON_ARGS=()
else
  WWW_CMD="swww"
  WWW_DAEMON="swww-daemon"
  WWW_CACHE_DIR="$HOME/.cache/swww/"
  WWW_DAEMON_ARGS=(--format xrgb)
fi

export WWW_CMD WWW_DAEMON WWW_CACHE_DIR WWW_DAEMON_ARGS
