#!/usr/bin/env bash
# ==================================================
#  KoolDots (2026)
#  Project URL: https://github.com/LinuxBeginnings
#  License: GNU GPLv3
#  SPDX-License-Identifier: GPL-3.0-or-later
# ==================================================
# Toggle Waybar clock format between 12H and 24H

WAYBAR_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/waybar"

# Files that hold toggleable clock formats
MODULES_FILES=(
  "$WAYBAR_DIR/Modules"         # clock, clock#2, clock#3, clock#4, clock#5
  "$WAYBAR_DIR/ModulesVertical" # clock#vertical
)

# Nerd Font clock glyph (U+F017) used by the "clock" and "clock#2" formats.
# Spelled out as a codepoint on purpose: a literal glyph here is easy to
# replace with a look-alike from a different Private Use range, which would
# make the patterns below stop matching without any visible difference.
CLOCK_GLYPH=$'\uf017'
# Nerd Font calendar glyph (U+F073), used by the clock#vertical formats
CAL_GLYPH=$'\uf073'

# Clock format pairs. FORMATS_12H[n] and FORMATS_24H[n] belong to the same
# module: toggling comments out the one and uncomments the other.
#
# The strings must match the "format" values in MODULES_FILES *verbatim*,
# including the {:L...} locale prefix and every space. A format that is not
# listed here, or listed with a typo, is silently left on whatever it is
# currently set to - so keep this list in sync when adding or editing a clock
# module.
FORMATS_12H=(
  "$CLOCK_GLYPH {:%I:%M %p}"           # clock
  "$CLOCK_GLYPH {:%I:%M %p}"           # clock#2
  '{:L%I:%M %p - %d/%b}'               # clock#3
  '{:L%B | %a %d, %Y | %I:%M %p}'      # clock#4
  '{:%A, %I:%M %P}'                    # clock#5
  "$CLOCK_GLYPH\n{:%I\n%M\n%p\n\n$CAL_GLYPH \n%d\n%m\n%y}"   # clock#vertical
)

FORMATS_24H=(
  "$CLOCK_GLYPH {:%H:%M:%S}"           # clock
  "$CLOCK_GLYPH  {:%H:%M}"             # clock#2
  '{:L%H:%M - %d/%b}'                  # clock#3
  '{:L%B | %a %d, %Y | %H:%M}'         # clock#4
  '{:%a %d | %H:%M}'                   # clock#5
  "$CLOCK_GLYPH\n{:%H\n%M\n%S\n\n$CAL_GLYPH \n%d\n%m\n%y}"   # clock#vertical
)

notify_swaync() {
  command -v notify-send >/dev/null 2>&1 || return 0
  export XDG_RUNTIME_DIR="${XDG_RUNTIME_DIR:-/run/user/$(id -u)}"
  local icon="${XDG_CONFIG_HOME:-$HOME/.config}/swaync/images/note.png"
  if [ -z "${DBUS_SESSION_BUS_ADDRESS:-}" ]; then
    local bus_path="${XDG_RUNTIME_DIR}/bus"
    if [ -S "$bus_path" ]; then
      export DBUS_SESSION_BUS_ADDRESS="unix:path=$bus_path"
    fi
  fi
  DBUS_SESSION_BUS_ADDRESS="$DBUS_SESSION_BUS_ADDRESS" XDG_RUNTIME_DIR="$XDG_RUNTIME_DIR" \
    notify-send -a "Waybar Time" -u low -t 2000 -i "$icon" "$@" >/dev/null 2>&1 || true
}

# Only work on the files that are actually present
FILES=()
for f in "${MODULES_FILES[@]}"; do
  [ -f "$f" ] && FILES+=("$f")
done

if [ "${#FILES[@]}" -eq 0 ]; then
  notify_swaync "No Waybar modules file found in: $WAYBAR_DIR"
  exit 1
fi

# Escape the characters that are special inside a sed BRE, plus the '#' we use
# as the s/// delimiter. Needed because the formats contain '.', '*' and the
# literal backslashes of clock#vertical.
escape_bre() {
  printf '%s' "$1" | sed 's/[][\\.*^$#]/\\&/g'
}

# Comment out / re-enable the "format" line carrying the given format string
comment_out() {
  local file="$1" esc
  esc=$(escape_bre "$2")
  sed -i "s#^\([[:space:]]*\)\(\"format\":[[:space:]]*\"${esc}\".*\)#\1//\2#" "$file"
}

uncomment() {
  local file="$1" esc
  esc=$(escape_bre "$2")
  sed -i "s#^\([[:space:]]*\)//[[:space:]]*\(\"format\":[[:space:]]*\"${esc}\".*\)#\1\2#" "$file"
}

# $1: 12h | 24h
apply_format() {
  local target="$1" file i
  for file in "${FILES[@]}"; do
    for i in "${!FORMATS_12H[@]}"; do
      if [ "$target" = "24h" ]; then
        comment_out "$file" "${FORMATS_12H[$i]}"
        uncomment "$file" "${FORMATS_24H[$i]}"
      else
        comment_out "$file" "${FORMATS_24H[$i]}"
        uncomment "$file" "${FORMATS_12H[$i]}"
      fi
    done
  done
}

# True when any clock module is currently on a 12H format. %I is the 12-hour
# hour and appears in every 12H format; the anchor skips commented lines.
is_12h_active() {
  grep -qE '^[[:space:]]*"format":.*%I' "${FILES[@]}"
}

snapshot() {
  cat "${FILES[@]}" | cksum
}

# Report formats that are not present in any modules file at all. Catches the
# case where a format above drifts away from the modules files, which would
# otherwise leave that one clock module silently stuck on its old setting.
warn_unknown_formats() {
  local i missing=0
  for i in "${!FORMATS_12H[@]}"; do
    grep -qF "\"${FORMATS_12H[$i]}\"" "${FILES[@]}" ||
      { printf 'Waybar Time: 12H format not found in any modules file: %s\n' "${FORMATS_12H[$i]}" >&2; missing=1; }
    grep -qF "\"${FORMATS_24H[$i]}\"" "${FILES[@]}" ||
      { printf 'Waybar Time: 24H format not found in any modules file: %s\n' "${FORMATS_24H[$i]}" >&2; missing=1; }
  done
  return $missing
}

restart_waybar() {
  local manage_with_systemd=0

  if command -v systemctl >/dev/null 2>&1; then
    if systemctl --user --quiet is-active graphical-session.target 2>/dev/null || systemctl --user --quiet is-active wayland-session@*.target 2>/dev/null; then
      if systemctl --user --quiet is-active waybar.service 2>/dev/null || systemctl --user --quiet is-enabled waybar.service 2>/dev/null; then
        manage_with_systemd=1
      fi
    fi
  fi

  if [ "$manage_with_systemd" -eq 1 ]; then
    systemctl --user stop waybar.service >/dev/null 2>&1 || true
  fi

  pkill -INT -x waybar >/dev/null 2>&1 || true
  pkill -INT -x '.waybar-wrapped' >/dev/null 2>&1 || true
  sleep 0.2
  if pgrep -x waybar >/dev/null 2>&1 || pgrep -x '.waybar-wrapped' >/dev/null 2>&1; then
    pkill -9 -x waybar >/dev/null 2>&1 || true
    pkill -9 -x '.waybar-wrapped' >/dev/null 2>&1 || true
  fi
  sleep 0.2

  if [ "$manage_with_systemd" -eq 1 ]; then
    if ! systemctl --user start waybar.service >/dev/null 2>&1; then
      waybar >/dev/null 2>&1 &
    fi
  else
    waybar >/dev/null 2>&1 &
  fi
}

warn_unknown_formats || true

before=$(snapshot)

if is_12h_active; then
  apply_format 24h
  mode="24H"
else
  apply_format 12h
  mode="12H"
fi

# Nothing replaced means the formats above drifted away from the modules files
if [ "$before" = "$(snapshot)" ]; then
  notify_swaync "Clock format unchanged - no known format matched"
  printf 'Waybar Time: no clock format matched, nothing changed\n' >&2
  exit 1
fi

restart_waybar
sleep 0.3

notify_swaync "Switched to ${mode} format"
printf 'Waybar Time: switched to %s format\n' "$mode"
