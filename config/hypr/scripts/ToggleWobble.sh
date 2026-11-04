#!/usr/bin/env bash
# ==================================================
#  KoolDots (2026)
#  Project URL: https://github.com/LinuxBeginnings
#  License: GNU GPLv3
#  SPDX-License-Identifier: GPL-3.0-or-later
# ==================================================
# Toggle Hyprland's window wobble (0.57+) on or off, persistently.
#
# Wobble is a window transformer, not an animation style: it is driven by
# decoration:wobble:* and Hyprland ships it disabled by default.
#
# The whole wobble config is one table in UserConfigs/user_decorations.lua. This
# script finds that table by its keys and rewrites only the "enabled" value
# inside it. The match is block scoped - the table is located by its keys and its
# end is found by brace depth - so:
#   * the blur/shadow "enabled" keys in the same file can never be touched;
#   * the table's layout does not matter. One line or twenty, any indentation,
#     any line length. A Lua formatter reflowing it changes nothing.
# Renaming the keys this reads (wobble / enabled) is the only thing that breaks it.
#
# Hyprland only grew window wobble in 0.57, and not every distro has caught up
# yet, so the action paths refuse to write anything on an older compositor.
#
# Usage:
#   ToggleWobble.sh [on|off|toggle]   set or flip the value (default: toggle)
#   ToggleWobble.sh --status          print On/Off and exit, no side effects

set -uo pipefail

LOCK="/tmp/.hypr_toggle_wobble_${HYPRLAND_INSTANCE_SIGNATURE:-default}.lock"

config_home="${XDG_CONFIG_HOME:-$HOME/.config}"
hypr_dir="$config_home/hypr"
user_decorations_lua="$hypr_dir/UserConfigs/user_decorations.lua"
images_dir="$config_home/swaync/images"

# Window wobble landed in Hyprland 0.57. Older versions have no
# decoration:wobble:* keys at all, so writing them produces a config error
# rather than an effect. The toggle refuses to write below this.
WOBBLE_MIN_VERSION="0.57"
WOBBLE_MIN_MAJOR="${WOBBLE_MIN_VERSION%%.*}"
WOBBLE_MIN_MINOR="${WOBBLE_MIN_VERSION#*.}"

icon="$images_dir/ja.png"
[[ -f "$icon" ]] || icon="$images_dir/note.png"

# Prints the value of wobble.enabled, or nothing when there is no wobble table or
# the table has no enabled key.
#
# Scans top down. Once the wobble table's opening line is seen, every following
# line is checked for the key until brace depth returns to zero, which is where
# the table ends. Comment-only lines are skipped, so a commented out copy of the
# table cannot win. Depth is counted from the opening line, so a one line table
# (open and close on the same line) is handled by the same path.
wobble_state_from_file() {
  awk '
    /^[[:space:]]*--/ { next }
    {
      if (!inwob && $0 ~ /wobble[[:space:]]*=[[:space:]]*\{/) {
        inwob = 1
        a = $0; b = $0
        depth = gsub(/\{/, "{", a) - gsub(/\}/, "}", b)
      } else if (inwob) {
        a = $0; b = $0
        depth += gsub(/\{/, "{", a) - gsub(/\}/, "}", b)
      } else {
        next
      }

      if (match($0, /enabled[[:space:]]*=[[:space:]]*(true|false)/)) {
        v = substr($0, RSTART, RLENGTH)
        sub(/.*=[[:space:]]*/, "", v)
        print v
        exit
      }

      if (depth <= 0) exit
    }
  ' "$1"
}

# Rewrites wobble.enabled in place. Everything outside the table is copied through
# byte for byte. $1 = file, $2 = true|false
#
# blkStart/blkEnd rather than open/close: "close" is a built-in awk function, so
# a variable of that name is a syntax error and the whole program fails to load.
wobble_set_state() {
  awk -v new="$2" '
    /^[[:space:]]*--/ { lines[NR] = $0; next }
    {
      lines[NR] = $0
      if (!inwob && $0 ~ /wobble[[:space:]]*=[[:space:]]*\{/) {
        inwob = 1; blkStart = NR
        a = $0; b = $0
        depth = gsub(/\{/, "{", a) - gsub(/\}/, "}", b)
        if (depth <= 0) { blkEnd = NR; inwob = 0 }
      } else if (inwob) {
        a = $0; b = $0
        depth += gsub(/\{/, "{", a) - gsub(/\}/, "}", b)
        if (depth <= 0) { blkEnd = NR; inwob = 0 }
      }
    }
    END {
      if (blkStart == 0) {
        # No wobble table anywhere: append a self contained one.
        for (i = 1; i <= NR; i++) print lines[i]
        printf "\nhl.config({ decoration = { wobble = { enabled = %s } } })\n", new
        exit
      }

      target = 0
      for (i = blkStart; i <= blkEnd; i++) {
        if (lines[i] ~ /enabled[[:space:]]*=[[:space:]]*(true|false)/) { target = i; break }
      }

      if (target > 0) {
        sub(/enabled[[:space:]]*=[[:space:]]*(true|false)/, "enabled = " new, lines[target])
      } else if (blkStart == blkEnd) {
        # Single line table with no enabled key: add it inline. The & is the
        # matched text, which is the "wobble = {" prefix being kept.
        sub(/wobble[[:space:]]*=[[:space:]]*\{[[:space:]]*/, "&enabled = " new ", ", lines[blkStart])
      } else {
        # Multi line table with no enabled key: add it as the first entry.
        indent = lines[blkStart]; sub(/[^[:space:]].*$/, "", indent)
        lines[blkStart] = lines[blkStart] "\n" indent "  enabled = " new ","
      }

      for (i = 1; i <= NR; i++) print lines[i]
    }
  ' "$1"
}

# Resolves the current state: the file first, since that is what survives a
# reload, then the running compositor, then Hyprland's shipped default.
wobble_state() {
  local state=""

  if [[ -f "$user_decorations_lua" ]]; then
    state="$(wobble_state_from_file "$user_decorations_lua")"
  fi

  if [[ "$state" != "true" && "$state" != "false" ]]; then
    state="$(hyprctl getoption decoration:wobble:enabled -j 2>/dev/null | jq -r '.bool' 2>/dev/null || true)"
    if [[ "$state" != "true" && "$state" != "false" ]]; then
      state="$(hyprctl getoption decoration:wobble:enabled 2>/dev/null | awk 'NR==1{print $2}')"
    fi
    [[ "$state" == "true" || "$state" == "false" ]] || state="false"
  fi

  printf '%s' "$state"
}

# Prints the running Hyprland version, e.g. 0.57.0, or nothing when it cannot be
# determined. The JSON field is clean; the plain output's first line reads
# "Hyprland 0.57.0 built from ...", so field 2 holds the same value.
hyprland_version() {
  local raw=""

  raw="$(hyprctl -j version 2>/dev/null | jq -r '.version // empty' 2>/dev/null || true)"
  if [[ -z "$raw" ]]; then
    raw="$(hyprctl version 2>/dev/null | awk 'NR==1{print $2}')"
    # Field 2 is the version only on the real "Hyprland <ver> built from ..."
    # line. Anything else means the output was not what we expected, so report
    # unknown rather than feed nonsense to the comparison.
    [[ "$raw" =~ ^[0-9] ]] || raw=""
  fi

  printf '%s' "$raw"
}

# Returns 0 when wobble is supported, 1 when Hyprland is too old, 2 when the
# version could not be determined. Only the major.minor pair is compared, so
# 0.57, 0.57.0, 0.57.0.r12.gabc1234 and 0.58.0-1 all parse the same way.
wobble_support() {
  local v major minor rest

  v="$(hyprland_version)"
  [[ -n "$v" ]] || return 2

  v="${v#v}"
  major="${v%%.*}"
  rest="${v#*.}"
  minor="${rest%%.*}"

  [[ "$major" =~ ^[0-9]+$ && "$minor" =~ ^[0-9]+$ ]] || return 2

  (( major > WOBBLE_MIN_MAJOR )) && return 0
  (( major == WOBBLE_MIN_MAJOR && minor >= WOBBLE_MIN_MINOR )) && return 0

  return 1
}

# Read-only query, shared with the quick settings menu label so there is exactly
# one implementation of the parsing.
if [[ "${1:-}" == "--status" || "${1:-}" == "status" ]]; then
  # Deliberately no notification on this path: the menu label is drawn every time
  # the menu opens, so an old compositor would collect a stream of them.
  wobble_support
  case "$?" in
    0)
      if [[ "$(wobble_state)" == "true" ]]; then
        printf 'On\n'
      else
        printf 'Off\n'
      fi
      ;;
    1) printf 'Unsupported\n' ;;
    *) printf 'Unknown\n' ;;
  esac
  exit 0
fi

notify() {
  command -v notify-send >/dev/null 2>&1 || return 0
  [[ -n "${WAYLAND_DISPLAY:-}${DISPLAY:-}" ]] || return 0
  notify-send -e -u "${1:-low}" -i "$2" "$3" "$4"
}

(
  flock -n 200 || exit 0

  if [[ ! -f "$user_decorations_lua" ]]; then
    notify critical "$images_dir/error.png" "Window Wobble" "Not found: $user_decorations_lua"
    exit 1
  fi

  # Gate the write on the compositor actually having the option. Bailing out
  # before the write is the whole point: a config error on an older Hyprland is
  # worse than a toggle that declines to run.
  wobble_support
  case "$?" in
    0) ;;
    1)
      notify critical "$images_dir/error.png" "Window Wobble" \
        "Requires Hyprland v${WOBBLE_MIN_VERSION} or greater (running $(hyprland_version))"
      exit 1
      ;;
    *)
      notify critical "$images_dir/error.png" "Window Wobble" \
        "Could not determine the Hyprland version, so wobble was left unchanged"
      exit 1
      ;;
  esac

  current="$(wobble_state)"

  case "${1:---toggle}" in
    on | enable | --on | --enable) new="true" ;;
    off | disable | --off | --disable) new="false" ;;
    --toggle | toggle | "")
      if [[ "$current" == "true" ]]; then new="false"; else new="true"; fi
      ;;
    *)
      notify normal "$images_dir/error.png" "Window Wobble" "Unknown action: $1"
      exit 1
      ;;
  esac

  # Write to a sibling temp file first so a failure mid-write cannot truncate the
  # config. cat onto the original keeps its mode and inode.
  tmpf="$(mktemp "${user_decorations_lua}.XXXXXX")" || {
    notify critical "$images_dir/error.png" "Window Wobble" "Could not create a temp file next to $user_decorations_lua"
    exit 1
  }

  if ! wobble_set_state "$user_decorations_lua" "$new" >"$tmpf"; then
    rm -f -- "$tmpf"
    notify critical "$images_dir/error.png" "Window Wobble" "Could not rewrite $user_decorations_lua"
    exit 1
  fi

  cat "$tmpf" >"$user_decorations_lua"
  rm -f -- "$tmpf"

  # Apply it. reload re-runs hyprland.lua, which re-reads user_decorations.lua.
  hyprctl reload >/dev/null 2>&1 || true

  if [[ "$new" == "true" ]]; then
    label="On"
  else
    label="Off"
  fi
  notify low "$icon" "Window Wobble: ${label}" "decoration:wobble:enabled = ${new}"
) 200>"$LOCK"
