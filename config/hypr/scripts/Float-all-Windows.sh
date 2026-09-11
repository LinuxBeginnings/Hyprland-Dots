#!/usr/bin/env bash
# ==================================================
#  KoolDots (2026)
#  Project URL: https://github.com/LinuxBeginnings
#  License: GNU GPLv3
#  SPDX-License-Identifier: GPL-3.0-or-later
# ==================================================

# Get current workspace ID
ws=$(hyprctl activeworkspace -j | jq -r .id)

# Process all windows on the current workspace using native Lua API
hyprctl clients -j | jq -r --arg ws "$ws" '.[] | select(.workspace.id == ($ws|tonumber)) | .address' | while read -r addr; do
    hyprctl dispatch "hl.dsp.window.float({ window = 'address:${addr}', action = 'toggle' })" >/dev/null 2>&1
done
