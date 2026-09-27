#!/usr/bin/env bash
# ==================================================
#  KoolDots (2026)
#  Project URL: https://github.com/LinuxBeginnings
#  License: GNU GPLv3
#  SPDX-License-Identifier: GPL-3.0-or-later
# ==================================================
# Validate the Ghostty theme set in the managed config and fall back to
# wallpaper (wallust) colors when it cannot be resolved.
#
# Why this exists:
# Ghostty resolves `theme = <name>` against ~/.config/ghostty/themes and the
# Ghostty resources directory (share/ghostty/themes). Several distributions
# (Gentoo here, some minimal/Flatpak builds) do not ship the built-in theme
# collection, so a theme that works elsewhere fails with a "theme not found"
# configuration error dialog at every launch.
#
# This script makes that non-fatal: an unresolvable theme is commented out and,
# when available, the wallust include is enabled instead. It is idempotent and
# safe to run on every login.
#
# Usage: GhosttyThemeGuard.sh [--notify]

set -uo pipefail

CONFIG_HOME="${XDG_CONFIG_HOME:-$HOME/.config}"
MANAGED_CONFIG="$CONFIG_HOME/hypr/UserConfigs/ghostty.conf"
RUNTIME_CONFIG="$CONFIG_HOME/ghostty/config"
USER_THEMES_DIR="$CONFIG_HOME/ghostty/themes"
WALLUST_INCLUDE="$CONFIG_HOME/ghostty/wallust.conf"
LOGFILE="${XDG_RUNTIME_DIR:-/tmp}/ghostty-theme-guard.log"

NOTIFY=0
case "${1:-}" in
  --notify) NOTIFY=1 ;;
esac
[ "${GHOSTTY_THEME_GUARD_NOTIFY:-0}" = "1" ] && NOTIFY=1

# Theme names advertised by Ghostty itself (strips the "(user)"/"(builtin)" tag).
THEME_LIST=""

log() {
  printf '%s - %s\n' "$(date '+%Y-%m-%d %H:%M:%S')" "$*" >>"$LOGFILE" 2>/dev/null || true
}

have() {
  command -v "$1" >/dev/null 2>&1
}

notify_user() {
  [ "$NOTIFY" -eq 1 ] || return 0
  have notify-send || return 0
  notify-send -u normal -a "Ghostty Theme" "$1" "$2" >/dev/null 2>&1 || true
}

load_theme_list() {
  have ghostty || return 0
  THEME_LIST="$(ghostty +list-themes 2>/dev/null | sed -E 's/[[:space:]]+\((user|builtin)\)[[:space:]]*$//')"
}

# theme_available <name> -> 0 when Ghostty can resolve the theme
theme_available() {
  local name="$1"
  [ -n "$name" ] || return 1

  # Light/dark pairs: every component must resolve.
  case "$name" in
    *light:* | *dark:*)
      local part
      local old_ifs="$IFS"
      IFS=','
      for part in $name; do
        part="${part#light:}"
        part="${part#dark:}"
        part="${part#"${part%%[![:space:]]*}"}"
        part="${part%"${part##*[![:space:]]}"}"
        theme_available "$part" || {
          IFS="$old_ifs"
          return 1
        }
      done
      IFS="$old_ifs"
      return 0
      ;;
  esac

  # Absolute path theme.
  case "$name" in
    /*)
      [ -f "$name" ] && return 0 || return 1
      ;;
  esac

  # User theme directory.
  [ -f "$USER_THEMES_DIR/$name" ] && return 0

  # Explicitly exported resources directory.
  if [ -n "${GHOSTTY_RESOURCES_DIR:-}" ] && [ -f "$GHOSTTY_RESOURCES_DIR/themes/$name" ]; then
    return 0
  fi

  # Everything Ghostty reports (covers bundled themes when installed).
  if [ -n "$THEME_LIST" ] && printf '%s\n' "$THEME_LIST" | grep -Fxq -- "$name"; then
    return 0
  fi

  return 1
}

# active_theme <file> -> prints the first uncommented theme value
active_theme() {
  awk '
    /^[[:space:]]*#/ { next }
    /^[[:space:]]*theme[[:space:]]*=/ {
      val = $0
      sub(/^[[:space:]]*theme[[:space:]]*=[[:space:]]*/, "", val)
      gsub(/^[[:space:]]+|[[:space:]]+$/, "", val)
      gsub(/^"|"$/, "", val)
      print val
      exit
    }
  ' "$1" 2>/dev/null
}

# rewrite_config <file> <wallust|plain>
# Comments the active theme and, in wallust mode, enables the wallpaper include.
rewrite_config() {
  local file="$1" mode="$2" tmp
  tmp="$(mktemp)" || return 1

  if [ "$mode" = "wallust" ]; then
    # NOTE: do not name the awk variable `include`; gawk treats that as a
    # builtin and aborts with "cannot use gawk builtin `include` as variable name".
    awk -v wallust_include_path="$WALLUST_INCLUDE" '
      {
        if ($0 ~ /^[[:space:]]*theme[[:space:]]*=/) {
          sub(/^[[:space:]]*theme[[:space:]]*=/, "#theme =")
          print
          next
        }
        if ($0 ~ /^[[:space:]]*#?[[:space:]]*config-file[[:space:]]*=/ && $0 ~ /wallust\.conf/) {
          print "config-file = " wallust_include_path
          seen = 1
          next
        }
        print
      }
      END { if (!seen) print "config-file = " wallust_include_path }
    ' "$file" >"$tmp" || {
      rm -f "$tmp"
      return 1
    }
  else
    awk '
      {
        if ($0 ~ /^[[:space:]]*theme[[:space:]]*=/) {
          sub(/^[[:space:]]*theme[[:space:]]*=/, "#theme =")
          print
          next
        }
        if ($0 ~ /^[[:space:]]*#?[[:space:]]*config-file[[:space:]]*=/ && $0 ~ /wallust\.conf/) {
          sub(/^[[:space:]]*/, "#")
          print
          next
        }
        print
      }
    ' "$file" >"$tmp" || {
      rm -f "$tmp"
      return 1
    }
  fi

  mv -f "$tmp" "$file" || {
    rm -f "$tmp"
    return 1
  }
  return 0
}

main() {
  load_theme_list

  local changed=0 file theme mode
  for file in "$MANAGED_CONFIG" "$RUNTIME_CONFIG"; do
    [ -f "$file" ] && [ -r "$file" ] || continue
    theme="$(active_theme "$file")"
    [ -n "$theme" ] || continue

    if theme_available "$theme"; then
      log "theme '$theme' resolves for $file"
      continue
    fi

    log "theme '$theme' not found for $file; applying fallback"
    if [ -s "$WALLUST_INCLUDE" ]; then
      mode="wallust"
    else
      mode="plain"
    fi

    if rewrite_config "$file" "$mode"; then
      log "rewrote $file (mode=$mode)"
      changed=1
    else
      log "failed to rewrite $file"
    fi
  done

  if [ "$changed" -eq 1 ]; then
    # Managed config is the source of truth; keep the runtime copy in sync.
    if [ -f "$MANAGED_CONFIG" ] && [ -r "$MANAGED_CONFIG" ]; then
      mkdir -p "$(dirname "$RUNTIME_CONFIG")" 2>/dev/null || true
      cp -f "$MANAGED_CONFIG" "$RUNTIME_CONFIG" 2>/dev/null || true
    fi
    have pkill && pkill -SIGUSR2 -x ghostty >/dev/null 2>&1 || true
    notify_user "Ghostty colors restored" "Configured theme was not installed; using wallpaper/default colors."
  fi

  return 0
}

main "$@"
