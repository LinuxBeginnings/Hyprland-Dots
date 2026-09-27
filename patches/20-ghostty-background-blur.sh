#!/usr/bin/env bash
# ==================================================
#  KoolDots (2026)
#  Project URL: https://github.com/LinuxBeginnings
#  License: GNU GPLv3
#  SPDX-License-Identifier: GPL-3.0-or-later
# ==================================================
# Patch: Ghostty 1.3 replaced `background-blur-radius` with `background-blur`
# (an integer intensity, or true/false). An install that still carries the old
# key logs a deprecation error on every launch:
#
#   compatibility handler for background-blur-radius handled error,
#   you may be using a deprecated field: error.InvalidField
#
# This migrates the value in place, preserving the existing intensity. It is
# content-idempotent: it only touches files that still use the old key.

# shellcheck source=./lib.sh
. "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/lib.sh"

# Migrate a single file. Returns 0 whether or not a change was needed.
migrate_blur_key() {
  local file="$1" value

  [ -f "$file" ] || return 0

  # Nothing to do when the deprecated key is absent (covers fresh installs and
  # repeat runs).
  if ! grep -qE '^[[:space:]]*background-blur-radius[[:space:]]*=' "$file" 2>/dev/null; then
    return 0
  fi

  # Preserve the configured intensity ("60", "false", "true", ...).
  value="$(sed -nE 's/^[[:space:]]*background-blur-radius[[:space:]]*=[[:space:]]*([^[:space:]]+).*/\1/p' "$file" | head -n1)"
  [ -n "$value" ] || value="60"

  if grep -qE '^[[:space:]]*background-blur([[:space:]]|=)' "$file" 2>/dev/null; then
    # background-blur is already configured: just drop the stale key so the
    # user's explicit value wins and no deprecation warning is emitted.
    sed -i -E '/^[[:space:]]*background-blur-radius[[:space:]]*=/d' "$file"
  else
    sed -i -E "s|^[[:space:]]*background-blur-radius[[:space:]]*=.*$|background-blur = ${value}|" "$file"
  fi

  patch_log "Migrated background-blur-radius -> background-blur (${value}) in ${file}"
  return 0
}

changed=0

# Count the deprecated key so we can report an accurate final status.
deprecated_key_count() {
  [ -f "$1" ] || {
    printf '0'
    return 0
  }
  grep -cE '^[[:space:]]*background-blur-radius[[:space:]]*=' "$1" 2>/dev/null || true
}

MANAGED_GHOSTTY="$(patch_hypr_dir)/UserConfigs/ghostty.conf"
if [ -f "$MANAGED_GHOSTTY" ]; then
  before="$(deprecated_key_count "$MANAGED_GHOSTTY")"
  migrate_blur_key "$MANAGED_GHOSTTY"
  after="$(deprecated_key_count "$MANAGED_GHOSTTY")"
  [ "$before" != "$after" ] && changed=1
else
  patch_log "ghostty.conf not found; skipping background-blur fix."
fi

# The runtime config Ghostty actually reads is refreshed from the repo template
# by copy.sh, but migrate it too so a previously generated file is not left
# with the deprecated key.
RUNTIME_GHOSTTY="$KOOLDOTS_CONFIG_HOME/ghostty/config"
if [ -f "$RUNTIME_GHOSTTY" ]; then
  before="$(deprecated_key_count "$RUNTIME_GHOSTTY")"
  migrate_blur_key "$RUNTIME_GHOSTTY"
  after="$(deprecated_key_count "$RUNTIME_GHOSTTY")"
  [ "$before" != "$after" ] && changed=1
fi

if [ "$changed" -eq 0 ]; then
  patch_log "Ghostty background-blur setting already up to date."
fi

exit 0
