#!/usr/bin/env bash
# ==================================================
#  KoolDots (2026)
#  Project URL: https://github.com/LinuxBeginnings
#  License: GNU GPLv3
#  SPDX-License-Identifier: GPL-3.0-or-later
# ==================================================
# Apply the Rainbow Borders mode recorded in
#   $HOME/.config/hypr/UserScripts/rainbow-borders.mode
#
# Why this exists:
#   The mode file is user state, but nothing applied it at login. A mode chosen
#   from Quick Settings -> Rainbow Borders Mode (SUPER SHIFT + E) therefore
#   survived only until the next logout, because the wallpaper pass rewrites
#   general:col.active_border from the Wallust palette and the RainbowBorders
#   script is a one-shot.
#
#   scripts/WallustSwww.sh is the last writer of general:col.active_border on
#   every wallpaper/theme change, so it calls this script immediately after its
#   own border write. Refresh.sh and RefreshNoWaybar.sh delegate here too, and
#   the startup list calls it once for a login where no wallpaper resolves.
#   One implementation, so the callers cannot drift apart.
#
# Modes written by scripts/Kool_Quick_Settings.sh:
#   wallust_random | rainbow | gradient_flow  -> one-shot RainbowBorders.sh
#   low_cpu                                   -> animated RainbowBorders-low-cpu.sh
#   disabled                                  -> leave the Wallust border alone
set -u

UserScripts="${XDG_CONFIG_HOME:-$HOME/.config}/hypr/UserScripts"
CLASSIC="$UserScripts/RainbowBorders.sh"
LOWCPU="$UserScripts/RainbowBorders-low-cpu.sh"
MODE_FILE="$UserScripts/rainbow-borders.mode"
LOCKFILE="${RB_LOCKFILE:-/tmp/hypr-rainbowborders.lock}"

# Give hyprctl a usable environment. Matches the other startup helpers, and is
# required when this runs from a login shell that never inherited the session.
ensure_wayland_env() {
  local runtime_dir="${XDG_RUNTIME_DIR:-/run/user/$(id -u)}"
  export XDG_RUNTIME_DIR="$runtime_dir"

  if [ -z "${WAYLAND_DISPLAY:-}" ] || [ ! -S "$runtime_dir/$WAYLAND_DISPLAY" ]; then
    for socket in "$runtime_dir"/wayland-[0-9]*; do
      [ -S "$socket" ] || continue
      case "$(basename "$socket")" in
      *awww*) continue ;;
      esac
      export WAYLAND_DISPLAY="$(basename "$socket")"
      break
    done
  fi

  if [ -z "${HYPRLAND_INSTANCE_SIGNATURE:-}" ]; then
    for sig_dir in "$runtime_dir"/hypr/*/; do
      [ -S "${sig_dir}.socket.sock" ] || continue
      export HYPRLAND_INSTANCE_SIGNATURE="$(basename "$sig_dir")"
      break
    done
  fi
}

# Detach so the effect outlives whoever called us (WallustSwww.sh, Refresh.sh,
# or the Hyprland startup hook).
run_detached() {
  local script="$1"
  if command -v setsid >/dev/null 2>&1; then
    setsid "$script" >/dev/null 2>&1 &
  else
    "$script" >/dev/null 2>&1 &
  fi
}

stop_lowcpu() {
  local oldpid=""
  if [ -f "$LOCKFILE" ]; then
    oldpid="$(cat "$LOCKFILE" 2>/dev/null || true)"
    if [ -n "$oldpid" ] && kill -0 "$oldpid" 2>/dev/null; then
      kill "$oldpid" >/dev/null 2>&1 || true
      sleep 0.1
      kill -0 "$oldpid" 2>/dev/null && kill -9 "$oldpid" >/dev/null 2>&1 || true
    fi
    rm -f "$LOCKFILE" >/dev/null 2>&1 || true
  fi
  pkill -f 'RainbowBorders-low-cpu\.sh' >/dev/null 2>&1 || true
}

start_lowcpu() {
  [ -f "$LOWCPU" ] || return 1
  [ -x "$LOWCPU" ] || chmod +x "$LOWCPU" >/dev/null 2>&1 || true
  stop_lowcpu
  run_detached "$LOWCPU"
}

start_classic() {
  [ -f "$CLASSIC" ] || return 1
  [ -x "$CLASSIC" ] || chmod +x "$CLASSIC" >/dev/null 2>&1 || true
  run_detached "$CLASSIC"
}

mode=""
if [ -f "$MODE_FILE" ]; then
  mode="$(tr -d '[:space:]' <"$MODE_FILE")"
fi

ensure_wayland_env

case "$mode" in
low_cpu)
  start_lowcpu || true
  ;;
wallust_random | rainbow | gradient_flow)
  start_classic || true
  ;;
disabled)
  # Explicitly off. The Wallust border colour written by the caller stays.
  ;;
"")
  # No mode file yet: match the menu's legacy detection, where a present
  # classic script means rainbow borders were enabled before the file existed.
  if [ -f "$CLASSIC" ]; then
    start_classic || true
  fi
  ;;
*)
  # Unknown value (hand-edited file): prefer the classic script when present.
  if [ -f "$CLASSIC" ]; then
    start_classic || true
  fi
  ;;
esac

exit 0
