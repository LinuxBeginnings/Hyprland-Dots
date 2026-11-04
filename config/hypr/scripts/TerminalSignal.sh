#!/usr/bin/env bash
# ==================================================
#  KoolDots (2026)
#  Project URL: https://github.com/LinuxBeginnings
#  License: GNU GPLv3
#  SPDX-License-Identifier: GPL-3.0-or-later
# ==================================================
# Resolve the running terminal application, not its command line tools.
#
# `pidof` and `pkill` match on the process name, and a CLI invocation shares
# that name with the application:
#
#   pidof ghostty  ->  62387 25655
#     pid 62387  cmdline: ghostty +list-themes
#     pid 25655  cmdline: ghostty
#
# Signalling the application is the point; signalling a CLI invocation kills
# it. `Ghostty_themes.sh` and `GhosttyThemeGuard.sh` both run
# `ghostty +list-themes` and decide what to offer from the result, so a
# wallpaper change landing during either call used to SIGUSR2 it: the theme
# list came back empty, and the guard then commented out a theme that was
# installed and resolvable.
#
# Ghostty and kitty invocations are recognisable from the command line, so the
# PID list is filtered rather than the signal:
#   - ghostty subcommands are `+` arguments, e.g. `ghostty +list-themes`
#   - kitty has `+` for kittens and `@` for remote control, e.g.
#     `kitty +kitten themes`, `kitty @ load-config`
# An application launched with `-e <command>` keeps neither marker, so it is
# still signalled.
#
# Sourced, not executed. Callers: WallustSwww.sh, ThemeChanger.sh,
# Ghostty_themes.sh, GhosttyThemeGuard.sh, Kitty_themes.sh.

# terminal_app_pids <binary>
#
# Prints the PIDs of the running application, one per line, skipping CLI
# invocations. Returns 1 when the application is not running.
terminal_app_pids() {
  local name="$1"
  local pid arg found=0

  [ -n "$name" ] || return 1
  command -v pidof >/dev/null 2>&1 || return 1

  while IFS= read -r pid; do
    [ -n "$pid" ] || continue
    case "$pid" in
    *[!0-9]*) continue ;;
    esac
    [ -r "/proc/$pid/cmdline" ] || continue

    local is_cli=0
    # cmdline is NUL separated, so read it with a NUL delimiter.
    while IFS= read -r -d '' arg; do
      case "$arg" in
      +* | @*)
        is_cli=1
        break
        ;;
      esac
    done <"/proc/$pid/cmdline"

    [ "$is_cli" -eq 1 ] && continue

    printf '%s\n' "$pid"
    found=1
  done < <(pidof "$name" 2>/dev/null | tr ' ' '\n')

  [ "$found" -eq 1 ]
}

# signal_terminal_app <binary> <signal>
#
# Signals every running instance of the application, ignoring CLI invocations.
# <signal> is anything kill accepts, e.g. SIGUSR2 or USR1.
# Returns 0 when at least one instance was signalled.
signal_terminal_app() {
  local name="$1" sig="$2"
  local pid signalled=0

  [ -n "$name" ] || return 1
  [ -n "$sig" ] || return 1

  while IFS= read -r pid; do
    [ -n "$pid" ] || continue
    if kill -"$sig" "$pid" 2>/dev/null; then
      signalled=1
    fi
  done < <(terminal_app_pids "$name")

  [ "$signalled" -eq 1 ]
}
