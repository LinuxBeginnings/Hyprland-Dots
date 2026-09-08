#!/usr/bin/env bash
# ==================================================
#  KoolDots (2026)
#  Project URL: https://github.com/LinuxBeginnings
#  License: GNU GPLv3
#  SPDX-License-Identifier: GPL-3.0-or-later
# ==================================================
# Adjust cursor zoom factor for magnifier effect

mode="${1:-in}"

current=$(hyprctl getoption cursor:zoom_factor 2>/dev/null | awk 'NR==1 {factor = $2; if (factor < 1) {factor = 1}; print factor}')
if [[ -z "$current" ]]; then
  current="1.0"
fi

if [[ "$mode" == "in" ]]; then
  new_factor=$(awk -v f="$current" 'BEGIN { printf "%.2f", f * 2.0 }')
  if awk -v f="$new_factor" 'BEGIN { exit !(f > 16.0) }'; then
    new_factor="16.0"
  fi
else
  new_factor=$(awk -v f="$current" 'BEGIN { printf "%.2f", f / 2.0 }')
  if awk -v f="$new_factor" 'BEGIN { exit !(f < 1.0) }'; then
    new_factor="1.0"
  fi
fi

# Try eval first for Lua parser mode, fallback to keyword for legacy parser
output="$(hyprctl eval "hl.config({ cursor = { zoom_factor = ${new_factor} } })" 2>&1 || true)"
if [[ "$output" != "ok" ]]; then
  hyprctl keyword cursor:zoom_factor "$new_factor" >/dev/null 2>&1 || true
fi
