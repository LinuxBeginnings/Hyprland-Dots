#!/usr/bin/env bash
# ==================================================
#  KoolDots (2026)
#  Project URL: https://github.com/LinuxBeginnings
#  License: GNU GPLv3
#  SPDX-License-Identifier: GPL-3.0-or-later
# ==================================================
# Patch: hypridle delays every suspend by InhibitDelayMaxSec.
#
# hypridle holds a logind sleep "delay" inhibitor and releases it only once its
# `before_sleep_cmd` returns:
#
#   systemd-logind: Delay lock is active (UID 1000/..., PID .../hypridle)
#                   but inhibitor timeout is reached.
#
# With `before_sleep_cmd = loginctl lock-session` the command can block (it waits
# for the session to report locked), so logind waits out the full
# InhibitDelayMaxSec before suspending - 30s on Ubuntu, 5s upstream. Background
# the lock so hypridle releases the inhibitor immediately.
#
# Idempotent: only rewrites a before_sleep_cmd that is exactly the blocking
# `loginctl lock-session` form; a user's custom command is left untouched.

# shellcheck source=./lib.sh
. "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/lib.sh"

HYPRIDLE_CONF="$(patch_hypr_dir)/hypridle.conf"

if [ ! -f "$HYPRIDLE_CONF" ]; then
  patch_log "hypridle.conf not found; skipping suspend delay fix."
  exit 0
fi

# Already backgrounded?
if grep -qE '^[[:space:]]*before_sleep_cmd[[:space:]]*=.*loginctl lock-session[[:space:]]*&[[:space:]]*(#.*)?$' "$HYPRIDLE_CONF"; then
  patch_log "hypridle.conf already runs the lock in the background; no change."
  exit 0
fi

# Blocking form (with or without a trailing comment)?
if grep -qE '^[[:space:]]*before_sleep_cmd[[:space:]]*=[[:space:]]*loginctl lock-session[[:space:]]*(#.*)?$' "$HYPRIDLE_CONF"; then
  sed -i -E 's|^([[:space:]]*before_sleep_cmd[[:space:]]*=[[:space:]]*)loginctl lock-session[[:space:]]*(#.*)?$|\1loginctl lock-session \&   # lock the session without blocking suspend|' "$HYPRIDLE_CONF"
  patch_log "hypridle.conf: before_sleep_cmd now runs loginctl lock-session in the background."
  exit 0
fi

patch_log "hypridle.conf has a custom before_sleep_cmd; leaving it unchanged."
exit 0
