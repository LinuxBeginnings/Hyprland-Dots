#!/usr/bin/env bash
# ==================================================
#  KoolDots (2026)
#  Project URL: https://github.com/LinuxBeginnings
#  License: GNU GPLv3
#  SPDX-License-Identifier: GPL-3.0-or-later
# ==================================================
#
# Launch Thunar reliably from Hyprland keybinds.

runtime="${XDG_RUNTIME_DIR:-/run/user/$(id -u)}"

if [ -z "${WAYLAND_DISPLAY:-}" ]; then
  for sock in "$runtime"/wayland-[0-9]*; do
    [ -S "$sock" ] || continue
    case "$(basename "$sock")" in
      *awww*) continue ;;
    esac
    export WAYLAND_DISPLAY="$(basename "$sock")"
    break
  done
fi

if [ -z "${DISPLAY:-}" ] && [ -n "${WAYLAND_DISPLAY:-}" ]; then
  export DISPLAY=:1
fi

# If a stale daemon exists with no visible windows, restart it.
if pgrep -x thunar >/dev/null 2>&1; then
  if command -v hyprctl >/dev/null 2>&1; then
    if ! python3 - <<'PY'
import json
import subprocess
import sys

try:
    clients = json.loads(subprocess.check_output(["hyprctl", "clients", "-j"], text=True))
except Exception:
    sys.exit(0)

sys.exit(0 if any((c.get("class") or "").lower() == "thunar" for c in clients) else 1)
PY
    then
      thunar --quit >/dev/null 2>&1 || pkill -x thunar >/dev/null 2>&1 || true
      sleep 0.2
    fi
  fi
fi

exec thunar "$HOME"
