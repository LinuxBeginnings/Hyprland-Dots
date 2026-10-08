#!/usr/bin/env bash
# ==================================================
#  KoolDots (2026)
#  Project URL: https://github.com/LinuxBeginnings
#  License: GNU GPLv3
#  SPDX-License-Identifier: GPL-3.0-or-later
# ==================================================
# Purpose:
#   Watch Hyprland's socket2 event stream and hand monitor changes over to
#   DisplayProfile.sh. One watcher per session, debounced, and it reconnects by
#   itself when Hyprland replaces the socket.
#
#   It also watches for an arrangement written by nwg-displays, so running that
#   program DIRECTLY - not just through the layout menu - is what updates
#   UserConfigs/monitors.lua. See import_nwg_conf below.
#
#   Started from UserConfigs/user_startup.lua. Safe to run by hand.
set -Eeuo pipefail

pending=0
socket_warnings=0
config_home="${XDG_CONFIG_HOME:-$HOME/.config}"

MW_PROFILE_SCRIPT="${MW_PROFILE_SCRIPT:-$config_home/hypr/scripts/DisplayProfile.sh}"
MW_SOCAT="${MW_SOCAT:-socat}"
MW_DEBOUNCE="${MW_DEBOUNCE:-1.5}"
MW_RECONNECT_DELAY="${MW_RECONNECT_DELAY:-2}"
# Empty means "forever"; the tests bound it so they terminate.
MW_MAX_RECONNECTS="${MW_MAX_RECONNECTS-}"
MW_RUNTIME_DIR="${MW_RUNTIME_DIR:-${XDG_RUNTIME_DIR:-/tmp}}"
MW_LOG_FILE="${MW_LOG_FILE:-$MW_RUNTIME_DIR/kooldots-display-profiles/monitor-watcher.log}"
MW_LOCK_FILE="${MW_LOCK_FILE:-$MW_RUNTIME_DIR/kooldots-monitor-watcher.lock}"
MW_LOCK_WAIT="${MW_LOCK_WAIT:-0}"
MW_APPLY_RETRIES="${MW_APPLY_RETRIES:-3}"
MW_RETRY_DELAY="${MW_RETRY_DELAY:-2}"
MW_STATE_DIR="${MW_STATE_DIR:-$MW_RUNTIME_DIR/kooldots-display-profiles}"
# Written by DisplayProfile.sh: line 1 the fingerprint, line 2 the layout name.
MW_STATE_FILE="${MW_STATE_FILE:-$MW_STATE_DIR/current}"
# Written by the menu (and Quick Settings) around nwg-displays: holds its PID.
MW_PAUSE_FILE="${MW_PAUSE_FILE:-$MW_STATE_DIR/pause}"

# --- nwg-displays integration ----------------------------------------------
# nwg-displays writes a hyprlang monitors.conf that this Lua config never reads,
# so an arrangement made by a DIRECTLY launched nwg-displays would otherwise be
# lost: only the menu could bridge it, because only the menu owned the process.
#
# A direct run cannot be paused the way the menu pauses it, but its Apply writes
# the file and THEN reloads Hyprland, so a change on disk is the signal - which
# is what the idle poll in main() looks for.
#
# The path is nwg's own default. From 0.4.3 it also writes a Lua sibling next to
# it (~/.config/hypr/monitors.lua); lua/monitors.lua does not load that path, so
# neither file competes with the UserConfigs/monitors.lua the controller owns.
MW_NWG_CONF="${MW_NWG_CONF:-$config_home/hypr/monitors.conf}"
# Touched after every import attempt and once at startup, so only a change made
# while this watcher is running is picked up.
MW_NWG_STAMP="${MW_NWG_STAMP:-$MW_STATE_DIR/nwg-import.stamp}"
# The process name that means "the user is arranging monitors". An explicitly
# EMPTY value disables the check - which is why this uses ${V-default} and not
# ${V:-default} - and the tests rely on that so a real nwg-displays on the
# machine cannot suppress them.
MW_NWG_PROC="${MW_NWG_PROC-nwg-displays}"
MW_PGREP="${MW_PGREP:-pgrep}"
# The idle poll, in seconds. This is also the interval at which the conf above
# is checked, and it is the only clock in this script.
MW_IDLE_POLL="${MW_IDLE_POLL:-2}"

log() {
  local line
  line="$(date '+%Y-%m-%d %H:%M:%S') [MonitorWatcher] $*"
  # stderr, never stdout: helpers such as generate_waybar_config return their
  # value on stdout, and a log line there would be captured into it.
  printf '%s\n' "$line" >&2
  mkdir -p -- "$(dirname -- "$MW_LOG_FILE")" 2>/dev/null || return 0
  if [[ -f $MW_LOG_FILE ]] && (( $(stat -c %s "$MW_LOG_FILE" 2>/dev/null || echo 0) > 1048576 )); then
    : > "$MW_LOG_FILE"
  fi
  printf '%s\n' "$line" >> "$MW_LOG_FILE" 2>/dev/null || true
}

die() { log "ERROR: $*"; exit 1; }

# --- Singleton -------------------------------------------------------------
# Exactly one watcher per user. A second one says so and leaves the session
# alone - it must never apply a profile behind the first watcher's back.
acquire_lock() {
  command -v flock >/dev/null 2>&1 || { log "WARN: flock not found; running without singleton protection"; return 0; }
  mkdir -p -- "$(dirname -- "$MW_LOCK_FILE")" 2>/dev/null || true
  exec 9>"$MW_LOCK_FILE" || { log "WARN: cannot open lock file $MW_LOCK_FILE"; return 0; }
  if [[ $MW_LOCK_WAIT == 0 ]]; then
    flock -n 9 || { log "another MonitorWatcher is already running; exiting"; exit 0; }
  else
    flock -w "$MW_LOCK_WAIT" 9 || { log "another MonitorWatcher is already running; exiting"; exit 0; }
  fi
}

# --- Event source ----------------------------------------------------------
# socket_path: resolved on EVERY connect attempt, never cached.
#
# HYPRLAND_INSTANCE_SIGNATURE is baked into this process at start. If Hyprland
# restarts, that value names a socket that no longer exists, and retrying it
# forever would silently stop all automatic switching. So fall back to the
# newest live .socket2.sock under $XDG_RUNTIME_DIR/hypr/.
socket_path() {
  local runtime=${XDG_RUNTIME_DIR:-/run/user/$(id -u)}
  local sig=${HYPRLAND_INSTANCE_SIGNATURE:-}
  local candidate newest

  if [[ -n $sig ]]; then
    candidate="$runtime/hypr/$sig/.socket2.sock"
    if [[ -S $candidate ]]; then
      printf '%s\n' "$candidate"
      return 0
    fi
  fi

  newest=""
  for candidate in "$runtime"/hypr/*/.socket2.sock; do
    [[ -S $candidate ]] || continue
    if [[ -z $newest || $candidate -nt $newest ]]; then
      newest=$candidate
    fi
  done
  if [[ -n $newest ]]; then
    [[ -n $sig ]] && log "instance signature $sig has no socket; using $newest"
    printf '%s\n' "$newest"
    return 0
  fi

  if [[ -z $sig ]]; then
    die "cannot determine the Hyprland event socket: HYPRLAND_INSTANCE_SIGNATURE is unset and no socket2 socket exists under $runtime/hypr"
  fi
  return 1
}

# stream_events: Hyprland's socket2 stream, or a fixture file for the tests.
stream_events() {
  if [[ -n ${MW_EVENT_FILE:-} ]]; then
    cat -- "$MW_EVENT_FILE"
    # MW_EVENT_LINGER keeps this subshell alive after the fixture is drained,
    # the way a real socat stays blocked on the socket.
    [[ -n ${MW_EVENT_LINGER:-} ]] && sleep "$MW_EVENT_LINGER"
    return 0
  fi
  local socket
  if ! socket="$(socket_path)"; then
    # Once, then rarely: this can repeat every MW_RECONNECT_DELAY seconds.
    if (( socket_warnings % 30 == 0 )); then
      log "WARN: no Hyprland event socket available yet; still retrying"
    fi
    socket_warnings=$((socket_warnings + 1))
    return 1
  fi
  socket_warnings=0
  "$MW_SOCAT" -U - "UNIX-CONNECT:$socket"
}

# event_class <event-line> -> "monitor" | "config" | "" (ignored).
#
# Any monitor appearing or disappearing matters now, not one named port: the
# set of connected monitors IS the key this system looks layouts up by.
# `configreloaded` matters because a reload re-applies monitors.lua over the
# running state, which would otherwise silently undo the active layout.
event_class() {
  case $1 in
    monitoradded'>>'* | monitorremoved'>>'* \
      | monitoraddedv2'>>'* | monitorremovedv2'>>'*) printf 'monitor\n' ;;
    configreloaded'>>'* | configreloaded) printf 'config\n' ;;
    *) printf '\n' ;;
  esac
}

# nwg_running: true while nwg-displays is open.
#
# `pgrep -x` matches a console script by name: the kernel names a shebang script
# after the script, not after its interpreter, so this finds
# /usr/bin/nwg-displays even though it is really python3.
nwg_running() {
  [[ -n $MW_NWG_PROC ]] || return 1
  command -v "$MW_PGREP" >/dev/null 2>&1 || return 1
  "$MW_PGREP" -x "$MW_NWG_PROC" >/dev/null 2>&1
}

# paused: true while the drag-and-drop GUI is up. Applying a stored layout
# mid-drag would silently throw away the arrangement the user is making, so
# every event is dropped until the GUI exits.
#
# Two things can be arranging monitors: the menu's own nwg-displays, which
# records its PID in the pause file, and one the user launched themselves, which
# has no file to leave behind and is found by name. A pause file left behind by
# a crashed GUI must not disable this watcher forever, so a dead PID clears it.
paused() {
  local pid
  if nwg_running; then
    log "nwg-displays is running; ignoring display events until it exits"
    return 0
  fi
  [[ -f $MW_PAUSE_FILE ]] || return 1
  pid="$(head -n1 -- "$MW_PAUSE_FILE" 2>/dev/null || true)"
  if [[ $pid =~ ^[0-9]+$ ]] && kill -0 "$pid" 2>/dev/null; then
    log "paused by pid $pid; ignoring display events"
    return 0
  fi
  log "removing a stale pause file (pid ${pid:-unknown} is gone)"
  rm -f -- "$MW_PAUSE_FILE"
  return 1
}

# touch_nwg_stamp: start the clock. Called at startup, so an arrangement written
# before this session is ignored - it has either been applied already or is
# superseded by the stored layout - and after every import attempt.
touch_nwg_stamp() {
  mkdir -p -- "$(dirname -- "$MW_NWG_STAMP")" 2>/dev/null || true
  : >"$MW_NWG_STAMP" 2>/dev/null || true
}

# import_nwg_conf: hand an arrangement nwg-displays wrote to the controller,
# which applies it and writes UserConfigs/monitors.lua.
#
# This does not wait for the window to close: the arrangement lands as soon as
# Apply is pressed, and nwg's own Cancel/revert writes the file back, which
# imports the reverted arrangement in turn. The two agree either way.
#
# The cheap tests come first and are bash builtins, so an idle tick that finds
# nothing forks nothing; the single grep runs only when the file has changed.
import_nwg_conf() {
  [[ -f $MW_NWG_CONF ]] || return 0
  [[ $MW_NWG_CONF -nt $MW_NWG_STAMP ]] || return 0
  if ! grep -q '^[[:space:]]*monitor=' "$MW_NWG_CONF" 2>/dev/null; then
    # nwg-displays creates this file empty at startup, so there is usually
    # nothing in it yet. Stamping stops us re-reading it until it changes.
    touch_nwg_stamp
    return 0
  fi
  log "nwg-displays wrote a new arrangement; importing it"
  if "$MW_PROFILE_SCRIPT" import-nwg "$MW_NWG_CONF" 9>&-; then
    log "imported the arrangement from $MW_NWG_CONF"
  else
    log "WARN: could not import $MW_NWG_CONF; see the display profile log"
  fi
  # Stamp whatever happened. A refusal (a mirrored arrangement, say) is
  # deterministic for this content, so retrying it on every poll would only fill
  # the log; pressing Apply again in nwg-displays retries with a new file.
  touch_nwg_stamp
  return 0
}

apply_auto() {
  log "applying automatic profile selection"
  # 9>&- : never hand the watcher's own lock descriptor to the controller. The
  # waybar it starts would inherit it and hold this watcher's lock forever,
  # so no watcher could start again until that waybar died.
  local rc=0
  "$MW_PROFILE_SCRIPT" auto 9>&- || rc=$?
  (( rc == 0 )) && return 0
  log "WARN: DisplayProfile.sh auto failed (exit $rc)"
  return 1
}

# apply_current: re-apply the layout that is running. Used after a config
# reload, so a layout the user picked by hand survives SUPER+ALT+R instead of
# jumping back to the monitor set's default.
#
# `(auto)` covers a generated layout AND an arrangement dragged in nwg-displays
# and not yet saved under a name. Both are on screen and recorded in
# active-layout.json, so the controller is asked to REPLAY that file rather than
# to re-resolve: re-resolving would silently replace the arrangement the user
# just made. The controller re-checks the fingerprint itself and falls back to
# `auto` when the recorded layout is not for the monitors now connected.
apply_current() {
  local name="" recorded="" layout_fp=""
  if [[ -f $MW_STATE_FILE ]]; then
    recorded="$(sed -n '1p' -- "$MW_STATE_FILE" 2>/dev/null || true)"
    name="$(sed -n '2p' -- "$MW_STATE_FILE" 2>/dev/null || true)"
  fi
  if [[ -n $name && $name != "(auto)" ]]; then
    log "config reloaded; re-applying $name"
    if "$MW_PROFILE_SCRIPT" -- "$name" 9>&-; then return 0; fi
    log "WARN: re-applying $name failed; falling back to auto"
  elif [[ $name == "(auto)" && -n $recorded && -f $MW_STATE_DIR/active-layout.json ]]; then
    layout_fp="$(head -n1 -- "$MW_STATE_DIR/active-layout.fingerprint" 2>/dev/null || true)"
    if [[ -n $layout_fp && $layout_fp == "$recorded" ]]; then
      log "config reloaded; re-applying the recorded layout"
      if "$MW_PROFILE_SCRIPT" reapply 9>&-; then return 0; fi
      log "WARN: replaying the recorded layout failed; falling back to auto"
    fi
  fi
  apply_auto
}

# flush_pending: the controller refuses while another change holds its lock,
# which is exactly what happens when a monitor is unplugged mid-switch.
# Dropping the event there would leave the displays wrong until the user
# pressed a key, so retry a bounded number of times.
flush_pending() {
  local attempt=0
  while (( pending )); do
    if paused; then
      log "dropping the pending change while paused"
      pending=0
      return 0
    fi
    if { [[ $pending_class == config ]] && apply_current; } \
       || { [[ $pending_class != config ]] && apply_auto; }; then
      pending=0
      return 0
    fi
    attempt=$((attempt + 1))
    if (( attempt >= MW_APPLY_RETRIES )); then
      log "WARN: giving up on this monitor event after $attempt attempts"
      pending=0
      return 1
    fi
    log "apply failed; retry $attempt of $MW_APPLY_RETRIES in ${MW_RETRY_DELAY}s"
    sleep "$MW_RETRY_DELAY"
  done
  return 0
}

# --- Main ------------------------------------------------------------------
main() {
  if [[ ${1:-} == "--print-socket" ]]; then
    # Debug helper: show which socket this process would connect to.
    socket_path || die "no Hyprland event socket found"
    return 0
  fi

  acquire_lock

  [[ -x $MW_PROFILE_SCRIPT ]] || die "controller not found or not executable: $MW_PROFILE_SCRIPT"
  if [[ -z ${MW_EVENT_FILE:-} ]]; then
    # The reader is a hard dependency; the socket is not. Hyprland may still be
    # starting, and socket_path() dies by itself when there is no way at all to
    # identify a session.
    command -v "$MW_SOCAT" >/dev/null 2>&1 || die "required command not found: $MW_SOCAT"
    socket_path >/dev/null || log "WARN: no event socket yet; will keep retrying"
  fi

  # Startup reconciliation: a monitor may have been connected before Hyprland
  # started, so no event is coming for it.
  if paused; then
    log "paused at startup; skipping reconciliation"
  else
    apply_auto
  fi

  # Start the clock for nwg-displays: an arrangement written before this session
  # has either been applied already or is superseded by the stored layout.
  touch_nwg_stamp

  local reconnects=0 line rc cls
  pending=0
  pending_class=monitor
  while true; do
    log "listening for display events"
    pending=0
    pending_class=monitor
    while true; do
      # `read` returning non-zero is normal control flow here (timeout or end
      # of stream), so it must never trip `set -e`.
      rc=0
      line=""
      if (( pending )); then
        IFS= read -r -t "$MW_DEBOUNCE" line || rc=$?
      else
        # The idle read times out on purpose: that timeout is the only clock
        # this script has, and it is what lets a directly launched
        # nwg-displays be noticed without a second process.
        IFS= read -r -t "$MW_IDLE_POLL" line || rc=$?
      fi
      if (( rc == 0 )); then
        cls="$(event_class "$line")"
        if [[ -n $cls ]]; then
          log "relevant event ($cls): $line"
          # A monitor change outranks a config reload: the set of monitors
          # decided which layout applies in the first place.
          [[ $cls == monitor || $pending -eq 0 ]] && pending_class=$cls
          pending=1
        fi
        continue
      fi
      if (( rc > 128 )); then
        # read timed out: the burst has settled
        flush_pending
        # ...and with nothing pending, this was the idle tick. Two builtin tests
        # per tick; the import only runs if nwg-displays wrote the file.
        import_nwg_conf
        continue
      fi
      # end of stream: `read` may still have handed us a final unterminated line
      if [[ -n $line ]]; then
        cls="$(event_class "$line")"
        if [[ -n $cls ]]; then
          log "relevant event ($cls): $line"
          [[ $cls == monitor || $pending -eq 0 ]] && pending_class=$cls
          pending=1
        fi
      fi
      flush_pending
      break
    # `exec 9>&-` in the subshell, NOT `stream_events 9>&-` on the call: bash
    # saves and restores the descriptor around a redirected command, and the
    # saved copy keeps the lock held by this subshell for as long as it lives.
    # The stream outlives the watcher by design - it is blocked on the socket -
    # so that leftover would strand the lock and no watcher could ever start
    # again after this one was killed.
    done < <(exec 9>&-; stream_events)

    if [[ -n $MW_MAX_RECONNECTS ]] && (( reconnects >= MW_MAX_RECONNECTS )); then
      log "event stream closed; reconnect limit reached, exiting"
      return 0
    fi
    reconnects=$((reconnects + 1))
    log "event stream closed; reconnect attempt $reconnects in ${MW_RECONNECT_DELAY}s"
    sleep "$MW_RECONNECT_DELAY"
  done
}

main "$@"
