#!/usr/bin/env bash
# ==================================================
#  KoolDots (2026)
#  Project URL: https://github.com/LinuxBeginnings
#  License: GNU GPLv3
#  SPDX-License-Identifier: GPL-3.0-or-later
# ==================================================
# Launcher for KoolDots Control Center.
# Runs the native Quickshell GUI settings application.

set -euo pipefail

CONFIG_HOME="${XDG_CONFIG_HOME:-$HOME/.config}"
HYPR_DIR="${KOOLDOTS_HYPR_DIR:-$CONFIG_HOME/hypr}"
QS_APP_DIR="$CONFIG_HOME/quickshell/control-center"
FALLBACK_SCRIPT="$HYPR_DIR/scripts/Kool_Quick_Settings.sh"

# If Quickshell app directory is missing in ~/.config, look in repo root
if [[ ! -d "$QS_APP_DIR" && -d "$HYPR_DIR/../quickshell/control-center" ]]; then
  QS_APP_DIR="$(cd "$HYPR_DIR/../quickshell/control-center" && pwd)"
fi

# If already running, focus or toggle
if pgrep -f 'quickshell.*control-center' >/dev/null 2>&1; then
  pkill -f 'quickshell.*control-center' >/dev/null 2>&1 || true
  exit 0
fi

if command -v quickshell >/dev/null 2>&1 && [[ -d "$QS_APP_DIR" ]]; then
  quickshell -p "$QS_APP_DIR" >/dev/null 2>&1 &
elif command -v qs >/dev/null 2>&1 && [[ -d "$QS_APP_DIR" ]]; then
  qs -p "$QS_APP_DIR" >/dev/null 2>&1 &
elif [[ -x "$FALLBACK_SCRIPT" ]]; then
  "$FALLBACK_SCRIPT"
else
  echo "Error: Neither quickshell nor Kool_Quick_Settings.sh is available." >&2
  exit 1
fi
