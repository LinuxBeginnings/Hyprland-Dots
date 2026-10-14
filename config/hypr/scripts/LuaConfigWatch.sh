#!/usr/bin/env bash
# ==================================================
#  KoolDots (2026)
#  Project URL: https://github.com/LinuxBeginnings
#  License: GNU GPLv3
#  SPDX-License-Identifier: GPL-3.0-or-later
# ==================================================
# Reload the Hyprland config when a file the config loads is saved.
#
# Why this exists
# ---------------
# Hyprland's built-in autoreload (`misc:disable_autoreload = false`) watches the
# one file it parsed: `~/.config/hypr/hyprland.lua`. Everything else the config
# loads is reached through `dofile`, and Hyprland never sees those reads, so it
# sets no watch on them. Measured on 0.56.2, with the `configreloaded>>` event
# on `.socket2.sock` as the detector:
#
#   touch hyprland.lua                    -> 1 reload
#   touch UserConfigs/user_keybinds.lua   -> 0 reloads
#   touch configs/system_keybinds.lua     -> 0 reloads
#   touch lua/settings.lua                -> 0 reloads
#
# So a user editing `UserConfigs/*.lua` - the files the docs tell them to edit -
# saw no effect until they ran `hyprctl reload` by hand. This script closes that
# gap: it watches the directories the config loads from and pokes the one file
# Hyprland does watch, so the compositor re-reads the config through its own
# reload path.
#
# This replaces scripts/LuaAutoReload.sh, which was retired on the assumption
# that built-in autoreload covered the whole tree. That assumption was wrong;
# LUA-008 in docs/LuaScriptsMigrationPlan.md now records the measurement.
#
# Design notes
# ------------
# * The trigger file is deliberately NOT inside the watched directories. The
#   reload therefore produces no event this script can hear, which is what stops
#   it from re-triggering itself.
# * `inotifywait -m` feeds a FIFO rather than a pipeline. In `inotifywait | while
#   read`, the shell is blocked on the pipeline and only runs a signal handler
#   once inotifywait exits - which it never does on its own. That is why the
#   retired watcher ignored SIGTERM on its polling path.
# * Saves are debounced. An editor that writes a file several times in a row, or
#   a save that arrives as create-then-rename, produces one reload.
# * No `set -e`: a transient failure (inotify limit reached, a watched directory
#   removed mid-session) must not end the watcher for the rest of the session.

set -uo pipefail

config_home="${XDG_CONFIG_HOME:-$HOME/.config}"
hypr_dir="$config_home/hypr"
entrypoint="$hypr_dir/hyprland.lua"
runtime_dir="${XDG_RUNTIME_DIR:-/tmp}"
pidfile="$runtime_dir/kooldots-lua-config-watch.pid"
fifo="$runtime_dir/kooldots-lua-config-watch.fifo"
log="$runtime_dir/kooldots-lua-config-watch.log"

# Exactly the directories lua/user_overrides.lua loads from. The config home
# itself is not watched, so the trigger file below can never feed back in.
watch_dirs=()
for rel_dir in lua configs UserConfigs; do
  [ -d "$hypr_dir/$rel_dir" ] && watch_dirs+=("$hypr_dir/$rel_dir")
done
[ "${#watch_dirs[@]}" -gt 0 ] || exit 0

# Only `.lua` files are loaded from these directories. Everything else in them
# (kitty themes, LegacyConfigs, wallust output) is not config, and reloading for
# it would be pure churn.
lua_re='\.lua$'

debounce=0.25
max_debounce_events=8
watcher_pid=""
changed_files=()

log_line() {
  printf '%s %s\n' "$(date '+%H:%M:%S')" "$*" >>"$log" 2>/dev/null || true
}

notify_problem() {
  command -v notify-send >/dev/null 2>&1 || return 0
  notify-send -e -u normal "$1" "$2" >/dev/null 2>&1 || true
}

# --- the reload itself ------------------------------------------------------

# `hyprctl getoption` prints `bool: <value>` followed by `set: <value>`.
autoreload_disabled() {
  local out
  out="$(hyprctl getoption misc:disable_autoreload 2>/dev/null || true)"
  case "$out" in
  *"bool: true"*) return 0 ;;
  *"bool: false"*) return 1 ;;
  esac
  # Unreadable: the entrypoint poke would be a silent no-op, so use the IPC call.
  return 0
}

use_entrypoint=0
if [ -f "$entrypoint" ] && ! autoreload_disabled; then
  use_entrypoint=1
fi

trigger_reload() {
  if [ "$use_entrypoint" = 1 ]; then
    # The entrypoint is the only path Hyprland watches, so saving it is what
    # makes the compositor re-read every file the config loads. No IPC involved.
    if touch "$entrypoint" 2>/dev/null; then
      return 0
    fi
  fi
  # Fallback, and the path used when built-in autoreload is switched off.
  hyprctl reload >/dev/null 2>&1 || true
}

# A syntax error in a UserConfigs file is silent: user_overrides.lua loads those
# files through `pcall`, so the file is skipped and only a WARN reaches the
# Hyprland log. Say so out loud, rather than leaving the user to wonder why the
# edit they just saved did nothing.
check_syntax() {
  local file="$1"
  [ -n "$file" ] && [ -f "$file" ] || return 0
  command -v luac >/dev/null 2>&1 || return 0
  luac -p "$file" >/dev/null 2>&1 && return 0
  log_line "syntax error: $file"
  notify_problem "Lua syntax error" "$(basename "$file") was skipped - check the Hyprland log"
}

record_change() {
  local file="$1" existing
  [ -n "$file" ] || return 0
  for existing in ${changed_files[@]+"${changed_files[@]}"}; do
    [ "$existing" = "$file" ] && return 0
  done
  changed_files+=("$file")
}

apply_changes() {
  local file names=""
  for file in ${changed_files[@]+"${changed_files[@]}"}; do
    check_syntax "$file"
    names="${names}${names:+, }$(basename "$file")"
  done
  trigger_reload
  log_line "reload after: ${names:-change}"
}

# Coalesce a burst: keep draining until the event stream is quiet for $debounce,
# capped so a pathological stream (a build writing .lua files in a loop) still
# reloads instead of draining forever.
settle() {
  local extra drained=0
  while [ "$drained" -lt "$max_debounce_events" ]; do
    IFS= read -r -t "$debounce" extra || break
    record_change "$extra"
    drained=$((drained + 1))
  done
}

# --- watching ---------------------------------------------------------------

watch_with_inotify() {
  rm -f "$fifo"
  mkfifo "$fifo" 2>/dev/null || return 1

  # `-m` keeps one watch set up for the session. Re-arming a one-shot watch in a
  # loop leaves a gap on every iteration, and a save landing in that gap is lost.
  inotifywait -m -q -r \
    -e close_write,create,moved_to,delete \
    --format '%w%f' --include "$lua_re" \
    "${watch_dirs[@]}" >"$fifo" 2>/dev/null &
  watcher_pid=$!

  local event
  while :; do
    if IFS= read -r -t 5 event; then
      changed_files=()
      record_change "$event"
      settle
      apply_changes
      continue
    fi
    # Bounded read, so there is a chance to notice inotifywait is gone (inotify
    # limits, a watch that could not be established) and start it again.
    kill -0 "$watcher_pid" 2>/dev/null || break
  done <"$fifo"

  kill "$watcher_pid" 2>/dev/null
  wait "$watcher_pid" 2>/dev/null
  watcher_pid=""
  rm -f "$fifo"
  return 1
}

snapshot() {
  find "${watch_dirs[@]}" -type f -name '*.lua' -printf '%p:%T@\n' 2>/dev/null | LC_ALL=C sort
}

# Fallback for a system without inotify-tools. Slower and it can only report
# "something changed", but it keeps the same contract.
watch_with_polling() {
  local previous current
  previous="$(snapshot)"
  while :; do
    # `sleep & wait` rather than a bare `sleep`: bash runs the signal handler as
    # soon as the child is reaped, so a SIGTERM is not held for up to a second.
    sleep 1 & wait $! 2>/dev/null
    current="$(snapshot)"
    [ "$current" = "$previous" ] && continue
    previous="$current"
    changed_files=()
    trigger_reload
    log_line "reload after: change (polling)"
  done
}

# --- main -------------------------------------------------------------------

# Single instance, per user. Deliberately not keyed by the session signature:
# this watcher does not talk to the IPC socket, so it keeps working across a
# Hyprland restart - and a second copy would poke the entrypoint twice per save.
if [ -f "$pidfile" ]; then
  old_pid="$(cat "$pidfile" 2>/dev/null || true)"
  if [ -n "$old_pid" ] && [ "$old_pid" != "$$" ] && kill -0 "$old_pid" 2>/dev/null; then
    exit 0
  fi
fi
printf '%d' "$$" >"$pidfile"

cleanup() {
  [ -n "$watcher_pid" ] && kill "$watcher_pid" 2>/dev/null
  rm -f "$pidfile" "$fifo"
}
trap cleanup EXIT
trap 'exit 143' INT TERM

: >"$log"
if [ "$use_entrypoint" = 1 ]; then
  log_line "watching ${watch_dirs[*]} (trigger: touch $(basename "$entrypoint"))"
else
  log_line "watching ${watch_dirs[*]} (trigger: hyprctl reload)"
fi

if command -v inotifywait >/dev/null 2>&1; then
  while :; do
    watch_with_inotify || sleep 1
  done
else
  log_line "inotifywait not found - falling back to polling"
  watch_with_polling
fi
