#!/usr/bin/env bash
# ==================================================
#  KoolDots (2026)
#  Project URL: https://github.com/LinuxBeginnings
#  License: GNU GPLv3
#  SPDX-License-Identifier: GPL-3.0-or-later
# ==================================================
# For applying Pre-configured Monitor Profiles
#
# This is a front end for the display-layout system, not a second one. One list
# offers both:
#   * the layouts saved for the monitor set in front of you - the same store
#     SUPER+ALT+D edits - applied through DisplayProfile.sh; and
#   * the .lua files in Monitor_Profiles/, as a one-way IMPORT. Choosing one
#     applies it, then saves what is on screen as a layout under that name, so
#     from then on it restores automatically like any other layout.
#
# Rows and actions are kept in parallel arrays and rofi is asked for an INDEX
# (-format i): a layout name is the user's own text and is never re-parsed as
# shell, and is always passed to the controller after `--`.

set -uo pipefail

iDIR="${XDG_CONFIG_HOME:-$HOME/.config}/swaync/images"
SCRIPTSDIR="${XDG_CONFIG_HOME:-$HOME/.config}/hypr/scripts"
monitor_dir="${XDG_CONFIG_HOME:-$HOME/.config}/hypr/Monitor_Profiles"
target="${XDG_CONFIG_HOME:-$HOME/.config}/hypr/UserConfigs/monitors.lua"
rofi_theme="${XDG_CONFIG_HOME:-$HOME/.config}/hypr/rofi/config-Monitors.rasi"
dp="$SCRIPTSDIR/DisplayProfile.sh"
MP_HYPRCTL="${MP_HYPRCTL:-hyprctl}"
MP_STATE_DIR="${MP_STATE_DIR:-${XDG_RUNTIME_DIR:-/tmp}/kooldots-display-profiles}"
msg="❗NOTE:❗ A profile chosen here is saved as a layout for the monitors connected now"

# Check if rofi is already running
if pidof rofi > /dev/null; then
  pkill rofi
fi

if [ ! -x "$dp" ]; then
  notify-send -u low -i "$iDIR/error.png" "Monitor Profiles" \
    "DisplayProfile.sh is not installed; nothing to apply profiles with"
  exit 1
fi

rows=(); actions=()

# Layouts saved for the monitors in front of us. `list` answers for the current
# monitor set only, which is the whole point of the new model.
while IFS= read -r name; do
  [ -n "$name" ] || continue
  rows+=("$name"); actions+=("apply:$name")
done < <("$dp" list 2>/dev/null || true)

# Legacy .lua profiles, offered as an import.
while IFS= read -r name; do
  [ -n "$name" ] || continue
  rows+=("$name   (legacy profile)"); actions+=("import:$name")
done < <(find -L "$monitor_dir" -maxdepth 1 -type f -name '*.lua' -printf '%f\n' 2>/dev/null \
           | sed 's/\.lua$//' | sort -V)

if [ "${#rows[@]}" -eq 0 ]; then
  notify-send -u low -i "$iDIR/ja.png" "Monitor Profiles" \
    "No layouts saved for these monitors yet - open SUPER+ALT+D to make one"
  exit 1
fi

"$SCRIPTSDIR/RofiFocusedWallpaperLink.sh" >/dev/null 2>&1 || true
chosen="$(printf '%s\n' "${rows[@]}" | rofi -i -dmenu -format i -config "$rofi_theme" -mesg "$msg")"

# Anything that is not an in-range index means "no choice" - including Escape.
case "$chosen" in
  ''|*[!0-9]*) exit 0 ;;
esac
if [ "$chosen" -ge "${#actions[@]}" ]; then exit 0; fi
action="${actions[$chosen]}"

case "$action" in
  apply:*)
    "$dp" -- "${action#apply:}" || exit 1
    ;;
  import:*)
    name="${action#import:}"
    profile="$monitor_dir/$name.lua"
    if [ ! -f "$profile" ]; then
      notify-send -u low -i "$iDIR/error.png" "Monitor Profiles" "No such profile: $name"
      exit 1
    fi
    # A legacy profile IS a monitors.lua: put it where the Lua config reads it,
    # reload so it takes effect, then save what is on screen as a layout.
    #
    # The pause file is what makes this safe. `hyprctl reload` re-runs the Lua
    # config and emits configreloaded, and MonitorWatcher would answer that by
    # re-applying the layout that was running BEFORE this import - undoing it
    # before it can be captured. While this file holds a live PID, the watcher
    # drops those events.
    mkdir -p -- "$MP_STATE_DIR" "$(dirname -- "$target")"
    printf '%s\n' "$$" > "$MP_STATE_DIR/pause"
    rc=0
    cp -f -- "$profile" "$target" || rc=1
    if [ "$rc" -eq 0 ]; then
      "$MP_HYPRCTL" reload >/dev/null 2>&1 || true
      # Let Hyprland finish modesetting before reading the state back.
      sleep 1
      "$dp" capture -- "$name" || rc=1
    fi
    rm -f -- "$MP_STATE_DIR/pause"
    if [ "$rc" -ne 0 ]; then
      notify-send -u low -i "$iDIR/error.png" "Monitor Profiles" \
        "Could not import $name; see the display profile log"
      exit 1
    fi
    notify-send -u low -i "$iDIR/ja.png" "$name" "Imported as a layout for these monitors"
    ;;
  *)
    exit 0
    ;;
esac

sleep 1
"${SCRIPTSDIR}/RefreshNoWaybar.sh" &
