#!/usr/bin/env bash
# ==================================================
#  KoolDots (2026)
#  Project URL: https://github.com/LinuxBeginnings
#  License: GNU GPLv3
#  SPDX-License-Identifier: GPL-3.0-or-later
# ==================================================
# Scripts for refreshing ags, waybar, rofi, swaync, wallust

SCRIPTSDIR=${XDG_CONFIG_HOME:-$HOME/.config}/hypr/scripts
UserScripts=${XDG_CONFIG_HOME:-$HOME/.config}/hypr/UserScripts
QS_TEXTINPUT_LOG_RULE="qt.qpa.wayland.textinput.warning=false"

# Define file_exists function
file_exists() {
  if [ -e "$1" ]; then
    return 0 # File exists
  else
    return 1 # File does not exist
  fi
}

# Kill already running processes (exclude waybar to avoid double reloads)
_ps=(rofi swaync ags)
for _prs in "${_ps[@]}"; do
  if pidof "${_prs}" >/dev/null; then
    pkill "${_prs}"
  fi
done

# Clean up any Waybar-spawned cava instances (unique temp conf names)
pkill -f 'waybar-cava\..*\.conf' 2>/dev/null || true


# quit ags & relaunch ags
if command -v ags >/dev/null 2>&1; then
  ags -q >/dev/null 2>&1 || true
  ags >/dev/null 2>&1 &
fi

# quit quickshell & relaunch quickshell
pkill qs && qs --log-rules "$QS_TEXTINPUT_LOG_RULE" &

# some process to kill (exclude waybar to avoid restart loops)
for pid in $(pidof rofi swaync ags swaybg); do
  kill -SIGUSR1 "$pid"
  sleep 0.1
done

# Does a waybar.service user unit exist and should it be managed via systemd?
# Check enabled/static or active state so distros where waybar.service is installed
# but disabled/unmanaged default to direct execution.
is_waybar_systemd() {
  command -v systemctl >/dev/null 2>&1 || return 1
  systemctl --user cat waybar.service >/dev/null 2>&1 || return 1
  local enabled_state
  enabled_state="$(systemctl --user is-enabled waybar.service 2>/dev/null || true)"
  case "$enabled_state" in
    enabled|static) return 0 ;;
  esac
  systemctl --user is-active --quiet waybar.service 2>/dev/null && return 0
  return 1
}

ensure_wayland_env() {
  local runtime_dir="${XDG_RUNTIME_DIR:-/run/user/$(id -u)}"
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

# Restart waybar once, DETACHED from this script's cgroup.
# This script is typically invoked from a waybar module on-click (e.g. DarkLight.sh), so
# it runs inside waybar.service's cgroup. Killing waybar from in there makes systemd tear
# down the whole unit and every process in it - this script included - so the replacement
# waybar never gets launched and the bar stays gone. Running the restart as a transient
# systemd unit puts it outside that cgroup, where it survives the teardown.
restart_waybar() {
  ensure_wayland_env
  local restart_cmd

  if is_waybar_systemd; then
    restart_cmd='systemctl --user stop waybar.service >/dev/null 2>&1 || true; pkill -INT -x waybar >/dev/null 2>&1 || true; pkill -INT -x .waybar-wrapped >/dev/null 2>&1 || true; sleep 0.2; if pgrep -x waybar >/dev/null 2>&1 || pgrep -x .waybar-wrapped >/dev/null 2>&1; then pkill -9 -x waybar >/dev/null 2>&1 || true; pkill -9 -x .waybar-wrapped >/dev/null 2>&1 || true; fi; sleep 0.1; systemctl --user reset-failed waybar.service >/dev/null 2>&1 || true; exec systemctl --user restart waybar.service'
  else
    restart_cmd='systemctl --user stop waybar.service >/dev/null 2>&1 || true; pkill -INT -x waybar >/dev/null 2>&1 || true; pkill -INT -x .waybar-wrapped >/dev/null 2>&1 || true; sleep 0.2; if pgrep -x waybar >/dev/null 2>&1 || pgrep -x .waybar-wrapped >/dev/null 2>&1; then pkill -9 -x waybar >/dev/null 2>&1 || true; pkill -9 -x .waybar-wrapped >/dev/null 2>&1 || true; fi; sleep 0.1; if command -v .waybar-wrapped >/dev/null 2>&1; then exec .waybar-wrapped; else exec waybar; fi'
  fi

  if command -v systemd-run >/dev/null 2>&1 &&
    systemd-run --user --collect --quiet --no-block \
      --setenv=WAYLAND_DISPLAY="${WAYLAND_DISPLAY:-}" \
      --setenv=XDG_RUNTIME_DIR="${XDG_RUNTIME_DIR:-/run/user/$(id -u)}" \
      --setenv=HYPRLAND_INSTANCE_SIGNATURE="${HYPRLAND_INSTANCE_SIGNATURE:-}" \
      /bin/bash -c "$restart_cmd" >/dev/null 2>&1; then
    return 0
  fi

  # Fallback when systemd-run is unavailable: detach as far as we can.
  setsid /bin/bash -c "$restart_cmd" >/dev/null 2>&1 &
}

restart_waybar

# relaunch swaync
sleep 0.3
if ! pidof swaync >/dev/null 2>&1; then
  swaync >/dev/null 2>&1 &
fi
# reload swaync (asynchronous to prevent DBus timeout delays)
(swaync-client --reload-config >/dev/null 2>&1 &)

# reload / restart nwg-dock-hyprland if running
if pgrep -x "nwg-dock-hyprla" >/dev/null 2>&1 || pgrep -x "nwg-dock-hyprland" >/dev/null 2>&1 || pgrep -f "nwg-dock-hyprland" >/dev/null 2>&1; then
  "${SCRIPTSDIR}/Dock.sh" --restart >/dev/null 2>&1 &
fi

# Relaunching rainbow borders based on selected mode
sleep 1
rainbow_mode_file="${UserScripts}/rainbow-borders.mode"
rainbow_mode=""
if [[ -f "$rainbow_mode_file" ]]; then
  rainbow_mode="$(tr -d '[:space:]' <"$rainbow_mode_file")"
fi
if [[ "$rainbow_mode" == "low_cpu" ]]; then
  pkill -f 'RainbowBorders-low-cpu\.sh' >/dev/null 2>&1 || true
  rm -f /tmp/hypr-rainbowborders.lock >/dev/null 2>&1 || true
  if file_exists "${UserScripts}/RainbowBorders-low-cpu.sh"; then
    "${UserScripts}/RainbowBorders-low-cpu.sh" >/dev/null 2>&1 &
  fi
elif file_exists "${UserScripts}/RainbowBorders.sh"; then
  "${UserScripts}/RainbowBorders.sh" &
fi

exit 0
