#!/usr/bin/env bash
# ==================================================
#  KoolDots (2026)
#  Project URL: https://github.com/LinuxBeginnings
#  License: GNU GPLv3
#  SPDX-License-Identifier: GPL-3.0-or-later
# ==================================================
# Patch: kitty 0.49+ opens a new split window unless window-size memory is
# disabled. Ensure ~/.config/hypr/UserConfigs/kitty.conf sets
# `remember_window_size no`. Idempotent: leaves the file untouched when the
# setting is already active.

# shellcheck source=./lib.sh
. "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/lib.sh"

KITTY_CONF="$(patch_hypr_dir)/UserConfigs/kitty.conf"

if [ ! -f "$KITTY_CONF" ]; then
  patch_log "kitty.conf not found; skipping remember_window_size fix."
  exit 0
fi

if grep -qE '^[[:space:]]*remember_window_size([[:space:]]|$)' "$KITTY_CONF" 2>/dev/null; then
  patch_log "kitty.conf already sets remember_window_size; no change."
  exit 0
fi

patch_ensure_line_after \
  "$KITTY_CONF" \
  '^[[:space:]]*#[[:space:]]*Fix window split' \
  '^[[:space:]]*remember_window_size([[:space:]]|$)' \
  'remember_window_size no'

patch_log "Applied kitty remember_window_size no fix."
exit 0
