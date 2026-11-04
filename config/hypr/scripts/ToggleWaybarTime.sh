#!/usr/bin/env bash
# ==================================================
#  KoolDots (2026)
#  Project URL: https://github.com/LinuxBeginnings
#  License: GNU GPLv3
#  SPDX-License-Identifier: GPL-3.0-or-later
# ==================================================
# Toggle Waybar clock format between 12H and 24H.
#
# This is the only place that knows the 12H/24H format pairs, so the Quick
# Settings toggle, the installer and the tests cannot drift apart.
#
# Usage:
#   ToggleWaybarTime.sh                flip to the other format, restart Waybar
#   ToggleWaybarTime.sh --set 12h|24h  apply that format, restart Waybar
#   ToggleWaybarTime.sh --dir <path>   edit another Waybar directory
#   ToggleWaybarTime.sh --no-restart   edit only; leave Waybar alone
#   ToggleWaybarTime.sh --status       print 12H or 24H and exit
#
# --dir is what the installer uses: it points at the dotfiles tree before the
# copy, and pairs it with --no-restart because Waybar is not up yet.

set -uo pipefail

DEFAULT_WAYBAR_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/hypr/waybar"
WAYBAR_DIR=""
ACTION="toggle"
RESTART=1

usage() {
  awk '/^# Usage:/{p=1} p && /^#$/ {exit} p {sub(/^# ?/,""); print}' "$0"
}

while [ $# -gt 0 ]; do
  case "$1" in
    --dir)
      [ $# -ge 2 ] || { printf 'Waybar Time: --dir needs a path\n' >&2; exit 2; }
      WAYBAR_DIR="$2"
      shift 2
      ;;
    --dir=*) WAYBAR_DIR="${1#*=}"; shift ;;
    --set)
      [ $# -ge 2 ] || { printf 'Waybar Time: --set needs 12h or 24h\n' >&2; exit 2; }
      ACTION="set:$2"
      shift 2
      ;;
    --set=*) ACTION="set:${1#*=}"; shift ;;
    --no-restart) RESTART=0; shift ;;
    --status) ACTION="status"; shift ;;
    -h | --help) usage; exit 0 ;;
    *)
      printf 'Waybar Time: unknown argument: %s\n' "$1" >&2
      exit 2
      ;;
  esac
done

WAYBAR_DIR="${WAYBAR_DIR:-$DEFAULT_WAYBAR_DIR}"

# Accept the spellings people actually type, so 12h/12H/12/h12 all agree.
case "$ACTION" in
  set:*)
    case "${ACTION#set:}" in
      12h | 12H | 12 | h12) ACTION="set:12h" ;;
      24h | 24H | 24 | h24) ACTION="set:24h" ;;
      *)
        printf 'Waybar Time: --set takes 12h or 24h, not %s\n' "${ACTION#set:}" >&2
        exit 2
        ;;
    esac
    ;;
esac

# Files that hold a toggleable clock format.
#
# WaybarLayout.sh offers every file in configs/, so a layout left out of this
# list is a layout whose clock ignores the toggle. That is how clock#forest and
# clock#text used to behave.
MODULES_FILES=(
  "$WAYBAR_DIR/Modules"                      # clock, clock#2, clock#3, clock#4, clock#5
  "$WAYBAR_DIR/ModulesVertical"              # clock#vertical
  "$WAYBAR_DIR/configs/TOP-Everforest"       # clock#forest
  "$WAYBAR_DIR/configs/TOP-Everforest-glass" # clock#forest
  "$WAYBAR_DIR/configs/Matt-Legacy-config"   # clock#text
)

# Nerd Font clock glyph (U+F017) used by the "clock" and "clock#2" formats.
# Spelled out as a codepoint on purpose: a literal glyph here is easy to
# replace with a look-alike from a different Private Use range, which would
# make the patterns below stop matching without any visible difference.
CLOCK_GLYPH=$'\uf017'
# Nerd Font calendar glyph (U+F073), used by the clock#vertical formats and by
# the extended "clock" display.
CAL_GLYPH=$'\uf073'

# Clock format pairs. FORMATS_12H[n] and FORMATS_24H[n] belong to the same
# module, and KEYS[n] names the key they sit under: "format" or "format-alt".
#
# format-alt is toggled too. An alt left on the other format is the mismatch
# this list exists to prevent: the primary clock read 24H while the extended
# display behind it still read 12H, or the reverse.
#
# The strings must match the values in MODULES_FILES *verbatim*, including the
# {:L...} locale prefix and every space. A format that is not listed here, or
# listed with a typo, is silently left on whatever it is currently set to - so
# keep this list in sync when adding or editing a clock module. The
# warn_unknown_formats check below reports a pair that matches nothing.
KEYS=(
  "format"     # clock
  "format"     # clock#2
  "format"     # clock#3
  "format"     # clock#4
  "format"     # clock#5
  "format"     # clock#vertical
  "format"     # clock#forest
  "format"     # clock#text
  "format-alt" # clock
  "format-alt" # clock#2
  "format-alt" # clock#5
)

FORMATS_12H=(
  "$CLOCK_GLYPH {:%I:%M %p}"                                  # clock
  "$CLOCK_GLYPH {:%I:%M %p}"                                  # clock#2
  '{:L%I:%M %p - %d/%b}'                                      # clock#3
  '{:L%B | %a %d, %Y | %I:%M %p}'                             # clock#4
  '{:%A, %I:%M %P}'                                           # clock#5
  "$CLOCK_GLYPH\n{:%I\n%M\n%p\n\n$CAL_GLYPH \n%d\n%m\n%y}"     # clock#vertical
  '{:L%A %d.%m.%Y - %I:%M %p}'                                # clock#forest
  '{:%I:%M %p}'                                               # clock#text
  "$CLOCK_GLYPH {:L%I:%M %p  $CAL_GLYPH %Y, %d %B, %A}"        # clock format-alt
  '{:L%A  |  %I:%M %p  |  %e %B}'                             # clock#2 format-alt
  '{:L%A, %d %B, %Y (%I:%M %p)}'                              # clock#5 format-alt
)

FORMATS_24H=(
  "$CLOCK_GLYPH {:%H:%M:%S}"                                  # clock
  "$CLOCK_GLYPH  {:%H:%M}"                                    # clock#2
  '{:L%H:%M - %d/%b}'                                         # clock#3
  '{:L%B | %a %d, %Y | %H:%M}'                                # clock#4
  '{:%a %d | %H:%M}'                                          # clock#5
  "$CLOCK_GLYPH\n{:%H\n%M\n%S\n\n$CAL_GLYPH \n%d\n%m\n%y}"     # clock#vertical
  '{:L%A %d.%m.%Y - %H:%M}'                                   # clock#forest
  '{:%H:%M}'                                                  # clock#text
  "$CLOCK_GLYPH {:L%H:%M  $CAL_GLYPH %Y, %d %B, %A}"           # clock format-alt
  '{:L%A  |  %H:%M  |  %e %B}'                                # clock#2 format-alt
  '{:L%A, %d %B, %Y (%R)}'                                    # clock#5 format-alt
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
  printf 'Waybar Time: no Waybar modules file found in: %s\n' "$WAYBAR_DIR" >&2
  [ "$ACTION" = "status" ] || notify_swaync "No Waybar modules file found in: $WAYBAR_DIR"
  exit 1
fi

# Escape the characters that are special inside a sed BRE, plus the '#' we use
# as the s/// delimiter. Needed because the formats contain '.', '*' and the
# literal backslashes of clock#vertical.
#
# Parens are deliberately not in the class. This is a BRE, where a bare '(' is
# literal while '\(' opens a group, so escaping one would break clock#5's
# "(%R)" pair. Under -E it is the other way round and '\(' opens a group, which
# is why apply_hyprlock_clock_format in lib_prompts.sh writes '[(]' instead.
escape_bre() {
  printf '%s' "$1" | sed 's/[][\\.*^$#]/\\&/g'
}

# Comment out / re-enable the "<key>" line carrying the given format string.
# An already-commented line is left alone by comment_out, and an already-live
# line by uncomment, so applying the same format twice changes nothing.
comment_out() {
  local file="$1" key="$2" esc
  esc=$(escape_bre "$3")
  sed -i "s#^\([[:space:]]*\)\(\"${key}\":[[:space:]]*\"${esc}\".*\)#\1//\2#" "$file"
}

uncomment() {
  local file="$1" key="$2" esc
  esc=$(escape_bre "$3")
  sed -i "s#^\([[:space:]]*\)//[[:space:]]*\(\"${key}\":[[:space:]]*\"${esc}\".*\)#\1\2#" "$file"
}

# $1: 12h | 24h
apply_format() {
  local target="$1" file i
  for file in "${FILES[@]}"; do
    for i in "${!FORMATS_12H[@]}"; do
      if [ "$target" = "24h" ]; then
        comment_out "$file" "${KEYS[$i]}" "${FORMATS_12H[$i]}"
        uncomment "$file" "${KEYS[$i]}" "${FORMATS_24H[$i]}"
      else
        comment_out "$file" "${KEYS[$i]}" "${FORMATS_24H[$i]}"
        uncomment "$file" "${KEYS[$i]}" "${FORMATS_12H[$i]}"
      fi
    done
  done
}

# True when any clock module is currently on a 12H format. %I is the 12-hour
# hour and appears in every 12H format, primary and alt alike; the anchor skips
# commented lines.
is_12h_active() {
  grep -qE '^[[:space:]]*"format(-alt)?":.*%I' "${FILES[@]}"
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
  # Waybar only auto-discovers ~/.config/waybar by default; it has no
  # knowledge of the hypr/-owned location, so direct launches must pass
  # explicit -c/-s flags. Systemd-managed restarts rely on the packaged
  # waybar.service unit, which is overridden separately (see
  # config/systemd/user/waybar.service.d/override.conf) to add the same flags.
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
      waybar -c "$WAYBAR_DIR/config" -s "$WAYBAR_DIR/style.css" >/dev/null 2>&1 &
    fi
  else
    waybar -c "$WAYBAR_DIR/config" -s "$WAYBAR_DIR/style.css" >/dev/null 2>&1 &
  fi
}

# Read-only query, shared with the installer and the tests so there is exactly
# one implementation of "which format is active". No notification on this path.
if [ "$ACTION" = "status" ]; then
  if is_12h_active; then
    printf '12H\n'
  else
    printf '24H\n'
  fi
  exit 0
fi

missing=0
warn_unknown_formats || missing=1

before=$(snapshot)

if [ "$ACTION" = "toggle" ]; then
  if is_12h_active; then target="24h"; else target="12h"; fi
else
  target="${ACTION#set:}"
fi

apply_format "$target"
if [ "$target" = "24h" ]; then mode="24H"; else mode="12H"; fi

# Nothing replaced. Either the requested format was already applied, or the
# pairs above have drifted away from the modules files.
if [ "$before" = "$(snapshot)" ]; then
  if [ "$missing" -eq 1 ]; then
    notify_swaync "Clock format unchanged - no known format matched"
    printf 'Waybar Time: no clock format matched, nothing changed\n' >&2
    exit 1
  fi
  printf 'Waybar Time: already on %s format\n' "$mode"
  [ "$RESTART" -eq 1 ] && notify_swaync "Already on ${mode} format"
  exit 0
fi

if [ "$RESTART" -eq 1 ]; then
  restart_waybar
  sleep 0.3
  notify_swaync "Switched to ${mode} format"
fi

printf 'Waybar Time: switched to %s format\n' "$mode"
