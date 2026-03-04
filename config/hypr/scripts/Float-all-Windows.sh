#!/usr/bin/env bash
# ==================================================
#  KoolDots (2026)
#  Project URL: https://github.com/LinuxBeginnings
#  License: GNU GPLv3
#  SPDX-License-Identifier: GPL-3.0-or-later
# ==================================================

ws=$(hyprctl activeworkspace -j | jq -r .id)
hyprctl clients -j | jq -r --arg ws "$ws" '.[] | select(.workspace.id == ($ws|tonumber)) | .address' | xargs -r -I {} hyprctl dispatch togglefloating address:{}
