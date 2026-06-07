#!/usr/bin/env bash
# ==================================================
#  KoolDots (2026)
#  Project URL: https://github.com/LinuxBeginnings
#  License: GNU GPLv3
#  SPDX-License-Identifier: GPL-3.0-or-later
# ==================================================
# Helper for Lua-config sessions where legacy `hyprctl dispatch fullscreen 1`
# is parsed as Lua and fails.

setsid -f sh -c 'sleep 0.2; hyprctl dispatch "hl.dsp.window.fullscreen({ mode = 1 })"' >/dev/null 2>&1
