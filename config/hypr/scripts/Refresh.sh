#!/usr/bin/env bash
# ==================================================
#  KoolDots (2026)
#  Project URL: https://github.com/LinuxBeginnings
#  License: GNU GPLv3
#  SPDX-License-Identifier: GPL-3.0-or-later
# ==================================================
# Scripts for refreshing ags, waybar, rofi, swaync, wallust

SCRIPTSDIR=${XDG_CONFIG_HOME:-$HOME/.config}/hypr/scripts
QS_TEXTINPUT_LOG_RULE="qt.qpa.wayland.textinput.warning=false"

# Kill already running processes (exclude waybar and swaync to avoid double reloads)
_ps=(rofi ags)
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

# some process to kill (exclude waybar and swaync to avoid restart loops)
for pid in $(pidof rofi ags swaybg); do
  kill -SIGUSR1 "$pid"
  sleep 0.1
done

# Same idea as the waybar systemd check, for swaync.
is_swaync_systemd() {
  command -v systemctl >/dev/null 2>&1 || return 1
  systemctl --user cat swaync.service >/dev/null 2>&1 || return 1
  local enabled_state
  enabled_state="$(systemctl --user is-enabled swaync.service 2>/dev/null || true)"
  case "$enabled_state" in
    enabled|static) return 0 ;;
  esac
  systemctl --user is-active --quiet swaync.service 2>/dev/null && return 0
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
# This script is typically invoked from a waybar module on-click or keybind, so
# it runs inside waybar.service's cgroup. Killing waybar from in there makes systemd tear
# down the whole unit and every process in it - this script included - so the replacement
# waybar never gets launched and the bar stays gone. Running the restart as a transient
# systemd unit puts it outside that cgroup, where it survives the teardown.
restart_waybar() {
  ensure_wayland_env
  local scripts_dir="${XDG_CONFIG_HOME:-$HOME/.config}/hypr/scripts"
  local waybar_dir="${XDG_CONFIG_HOME:-$HOME/.config}/hypr/waybar"
  local restart_cmd

  # WaybarStartup.sh owns the Waybar lifecycle and serializes every start and
  # restart on a shared flock (and also decides systemd-service vs direct
  # launch). Delegating here means concurrent Refresh.sh runs - for example the
  # burst of monitor.added events fired at login on laptops - can no longer
  # each launch their own bar.
  if [ -x "$scripts_dir/WaybarStartup.sh" ]; then
    restart_cmd="\"$scripts_dir/WaybarStartup.sh\" --restart"
  else
    restart_cmd="if command -v .waybar-wrapped >/dev/null 2>&1; then .waybar-wrapped -c \"$waybar_dir/config\" -s \"$waybar_dir/style.css\" >/dev/null 2>&1 & else waybar -c \"$waybar_dir/config\" -s \"$waybar_dir/style.css\" >/dev/null 2>&1 & fi"
  fi

  local unit_name="waybar-restart-$$-$RANDOM"
  if command -v systemd-run >/dev/null 2>&1; then
    systemd-run --user --collect --quiet --no-block \
      --unit="$unit_name" \
      --property=KillMode=none \
      --setenv=WAYLAND_DISPLAY="${WAYLAND_DISPLAY:-}" \
      --setenv=XDG_RUNTIME_DIR="${XDG_RUNTIME_DIR:-/run/user/$(id -u)}" \
      --setenv=HYPRLAND_INSTANCE_SIGNATURE="${HYPRLAND_INSTANCE_SIGNATURE:-}" \
      --setenv=WEATHER_UNITS="${WEATHER_UNITS:-}" \
      /bin/bash -c "$restart_cmd" >/dev/null 2>&1 || setsid /bin/bash -c "$restart_cmd" >/dev/null 2>&1 &
  else
    setsid /bin/bash -c "$restart_cmd" >/dev/null 2>&1 &
  fi
}

restart_waybar

# relaunch swaync if not running, then reload config and CSS in-place
if is_swaync_systemd; then
  if ! systemctl --user is-active --quiet swaync.service 2>/dev/null; then
    systemctl --user start swaync.service >/dev/null 2>&1 &
  fi
else
  sleep 0.3
  if ! pidof swaync >/dev/null 2>&1; then
    swaync >/dev/null 2>&1 &
  fi
fi
# reload swaync config and CSS (asynchronous to prevent DBus timeout delays)
(swaync-client -R -rs --skip-wait >/dev/null 2>&1 &)

# reload / restart nwg-dock-hyprland if running
if pgrep -x "nwg-dock-hyprla" >/dev/null 2>&1 || pgrep -x "nwg-dock-hyprland" >/dev/null 2>&1 || pgrep -f "nwg-dock-hyprland" >/dev/null 2>&1; then
  "${SCRIPTSDIR}/Dock.sh" --restart >/dev/null 2>&1 &
fi

# Re-apply the selected Rainbow Borders mode. The single implementation lives
# in RainbowBordersStartup.sh so this script, RefreshNoWaybar.sh and the
# wallpaper pass cannot drift apart.
sleep 1
if [ -x "${SCRIPTSDIR}/RainbowBordersStartup.sh" ]; then
  "${SCRIPTSDIR}/RainbowBordersStartup.sh" >/dev/null 2>&1 || true
fi

exit 0
