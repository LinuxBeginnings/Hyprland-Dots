#!/usr/bin/env bash
# ==================================================
#  KoolDots (2026)
#  Project URL: https://github.com/LinuxBeginnings
#  License: GNU GPLv3
#  SPDX-License-Identifier: GPL-3.0-or-later
# ==================================================
# Re-apply saved Dark/Light mode on startup without toggling.

SCRIPTSDIR="$HOME/.config/hypr/scripts"
"$SCRIPTSDIR/DarkLight.sh" --apply-current --preserve-wallpaper --no-notify
