#!/usr/bin/env bash
# ==================================================
#  KoolDots (2026)
#  Project URL: https://github.com/LinuxBeginnings
#  License: GNU GPLv3
#  SPDX-License-Identifier: GPL-3.0-or-later
# ==================================================
# Patch: hypridle suspend handling.
#
# 1) Suspend delay
# hypridle holds a logind sleep "delay" inhibitor and releases it only once its
# `before_sleep_cmd` returns:
#
#   systemd-logind: Delay lock is active (UID 1000/..., PID .../hypridle)
#                   but inhibitor timeout is reached.
#
# With `before_sleep_cmd = loginctl lock-session` the command can block (it waits
# for the session to report locked), so logind waits out the full
# InhibitDelayMaxSec before suspending - 30s on Ubuntu, 5s upstream. Background
# the lock so hypridle releases the inhibitor immediately. Only the exact
# blocking `loginctl lock-session` form is rewritten; a custom command is left
# untouched.
#
# 2) Duplicate daemons
# hypridle.service (where present) is the canonical owner. Two daemons appeared
# on hosts where the unit was already active and startup.lua also launched a bare
# `hypridle`; each instance registers its own sleep delay inhibitor. This installs
# HypridleStartup.sh so logins start exactly one daemon, and runs it once here so
# an already-running session is cleaned up without a re-login.
#
# Both parts are content-idempotent.

# shellcheck source=./lib.sh
. "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/lib.sh"

HYPRIDLE_CONF="$(patch_hypr_dir)/hypridle.conf"

fix_before_sleep_cmd() {
  if [ ! -f "$HYPRIDLE_CONF" ]; then
    patch_log "hypridle.conf not found; skipping suspend delay fix."
    return 0
  fi

  # Already backgrounded?
  if grep -qE '^[[:space:]]*before_sleep_cmd[[:space:]]*=.*loginctl lock-session[[:space:]]*&[[:space:]]*(#.*)?$' "$HYPRIDLE_CONF"; then
    patch_log "hypridle.conf already runs the lock in the background; no change."
    return 0
  fi

  # Blocking form (with or without a trailing comment)?
  if grep -qE '^[[:space:]]*before_sleep_cmd[[:space:]]*=[[:space:]]*loginctl lock-session[[:space:]]*(#.*)?$' "$HYPRIDLE_CONF"; then
    sed -i -E 's|^([[:space:]]*before_sleep_cmd[[:space:]]*=[[:space:]]*)loginctl lock-session[[:space:]]*(#.*)?$|\1loginctl lock-session \&   # lock the session without blocking suspend|' "$HYPRIDLE_CONF"
    patch_log "hypridle.conf: before_sleep_cmd now runs loginctl lock-session in the background."
    return 0
  fi

  patch_log "hypridle.conf has a custom before_sleep_cmd; leaving it unchanged."
  return 0
}

install_startup_helper() {
  local helper_src helper_dst
  helper_src="${DOTFILES_DIR:-$KOOLDOTS_REPO_ROOT}/config/hypr/scripts/HypridleStartup.sh"
  helper_dst="$(patch_hypr_dir)/scripts/HypridleStartup.sh"

  if [ ! -f "$helper_src" ]; then
    patch_log "HypridleStartup.sh not found in repo; skipping duplicate cleanup install."
    return 0
  fi

  if cmp -s "$helper_src" "$helper_dst" 2>/dev/null; then
    patch_log "HypridleStartup.sh already up to date."
    return 0
  fi

  mkdir -p "$(dirname "$helper_dst")"
  if cp -f "$helper_src" "$helper_dst"; then
    chmod 0755 "$helper_dst" 2>/dev/null || true
    patch_log "Installed HypridleStartup.sh (starts one daemon, removes duplicates)"
  else
    patch_log "failed to install HypridleStartup.sh"
    return 1
  fi
  return 0
}

run_dedupe_once() {
  local helper_dst
  helper_dst="$(patch_hypr_dir)/scripts/HypridleStartup.sh"

  [ -x "$helper_dst" ] || return 0
  pgrep -x hypridle >/dev/null 2>&1 || return 0

  "$helper_dst" --dedupe-only >/dev/null 2>&1 || true
  patch_log "Checked for duplicate hypridle instances."
  return 0
}

fix_before_sleep_cmd
install_startup_helper
run_dedupe_once

exit 0
