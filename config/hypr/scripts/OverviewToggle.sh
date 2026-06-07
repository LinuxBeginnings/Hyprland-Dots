#!/usr/bin/env bash
# ==================================================
#  KoolDots (2026)
#  Project URL: https://github.com/LinuxBeginnings
#  License: GNU GPLv3
#  SPDX-License-Identifier: GPL-3.0-or-later
# ==================================================
# Overview toggle wrapper - tries Quickshell first, falls back to AGS

set -euo pipefail

QS_OVERVIEW_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/quickshell/overview"

# 1) Prefer Quickshell when installed and configured
if command -v qs >/dev/null 2>&1 && [ -d "$QS_OVERVIEW_DIR" ]; then
  # Try Quickshell via IPC (works if QS is running and listening)
  if pgrep -x qs >/dev/null 2>&1; then
    if qs ipc -c overview call overview toggle >/dev/null 2>&1; then
      exit 0
    fi
  fi

  # If QS isn't running, try starting it and retry once
  qs -c overview >/dev/null 2>&1 &
  sleep 0.6
  if qs ipc -c overview call overview toggle >/dev/null 2>&1; then
    exit 0
  fi
fi

# 2) Fall back to AGS template
if command -v ags >/dev/null 2>&1; then
  pkill rofi || true
  if ags -t 'overview' >/dev/null 2>&1; then
    exit 0
  fi
  # If it failed, try starting AGS daemon then call the template
  ags >/dev/null 2>&1 &
  sleep 0.6
  if ags -t 'overview' >/dev/null 2>&1; then
    exit 0
  fi
fi

# If we get here, neither worked
notify-send "Overview" "Neither Quickshell nor AGS is available" -u low 2>/dev/null || true
exit 1
