#!/usr/bin/env bash
# ==================================================
#  KoolDots (2026)
#  Project URL: https://github.com/LinuxBeginnings
#  License: GNU GPLv3
#  SPDX-License-Identifier: GPL-3.0-or-later
# ==================================================
# Initialize J/K keybinds so they always cycle windows globally (no layout-specific behavior)
# This avoids double-actions when layouts change.

set -euo pipefail

# Always reset and bind SUPER+J/K the same way on startup
hyprctl keyword unbind SUPER,J || true
hyprctl keyword unbind SUPER,K || true

# Cycle windows globally: J = next, K = previous
hyprctl keyword bind SUPER,J,layoutmsg,cyclenext
hyprctl keyword bind SUPER,K,layoutmsg,cycleprev
