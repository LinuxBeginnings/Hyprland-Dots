#!/usr/bin/env bash
# ==================================================
#  KoolDots (2026)
#  Project URL: https://github.com/LinuxBeginnings
#  License: GNU GPLv3
#  SPDX-License-Identifier: GPL-3.0-or-later
# ==================================================
# Toggle active window opacity (opaque property).
# Uses flock so that if both .conf and .lua binds fire simultaneously
# (dual-config load), only the first execution runs and the second exits.

LOCK="/tmp/.hypr_toggle_opacity_${HYPRLAND_INSTANCE_SIGNATURE:-default}.lock"

(
  flock -n 200 || exit 0

  ADDR=$(hyprctl activewindow -j 2>/dev/null | jq -r '.address // empty')
  [ -z "$ADDR" ] && exit 0

  hyprctl setprop "address:${ADDR}" opaque toggle
) 200>"$LOCK"
