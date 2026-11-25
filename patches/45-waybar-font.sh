#!/usr/bin/env bash
# ==================================================
#  KoolDots (2026)
#  Project URL: https://github.com/LinuxBeginnings
#  License: GNU GPLv3
#  SPDX-License-Identifier: GPL-3.0-or-later
# ==================================================
# Patch: Synchronize custom Waybar font and font size from user_env.lua to
# installed Waybar stylesheets after copy.sh update.
# Content-idempotent: does nothing if no overrides are defined.

# shellcheck source=./lib.sh
. "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/lib.sh"

USER_ENV_LUA="$KOOLDOTS_CONFIG_HOME/hypr/UserConfigs/user_env.lua"

if [[ ! -f "$USER_ENV_LUA" ]]; then
  patch_log "user_env.lua not found; skipping waybar font patch."
  exit 0
fi

# Parse active overrides
font=$(sed -n 's/^[[:space:]]*hl\.env([[:space:]]*["'\''"]WAYBAR_FONT["'\''"][[:space:]]*,[[:space:]]*["'\''"]\([^"'\''"]*\)["'\''"].*$/\1/p' "$USER_ENV_LUA" | tail -n1)
size=$(sed -n 's/^[[:space:]]*hl\.env([[:space:]]*["'\''"]WAYBAR_FONT_SIZE["'\''"][[:space:]]*,[[:space:]]*["'\''"]\([^"'\''"]*\)["'\''"].*$/\1/p' "$USER_ENV_LUA" | tail -n1)
size=$(printf '%s' "$size" | tr -cd '0-9')

if [[ -z "$font" && -z "$size" ]]; then
  patch_log "No custom Waybar font or size defined in user_env.lua; keeping defaults."
  exit 0
fi

WAYBAR_DIR="$KOOLDOTS_CONFIG_HOME/hypr/waybar"
STYLES_DIR="$WAYBAR_DIR/style"
SCRIPTS_DIR="$KOOLDOTS_CONFIG_HOME/hypr/scripts"

# Locate WaybarFont.sh helper (in installed scripts, or fallback to repo root)
ENGINE=""
if [[ -x "$SCRIPTS_DIR/WaybarFont.sh" ]]; then
  ENGINE="$SCRIPTS_DIR/WaybarFont.sh"
elif [[ -n "${KOOLDOTS_REPO_ROOT:-}" && -x "$KOOLDOTS_REPO_ROOT/config/hypr/scripts/WaybarFont.sh" ]]; then
  ENGINE="$KOOLDOTS_REPO_ROOT/config/hypr/scripts/WaybarFont.sh"
fi

if [[ -n "$ENGINE" ]]; then
  KOOLDOTS_USER_ENV_LUA="$USER_ENV_LUA" \
  KOOLDOTS_WAYBAR_DIR="$WAYBAR_DIR" \
  KOOLDOTS_STYLES_DIR="$STYLES_DIR" \
  KOOLDOTS_SCRIPTS_DIR="$SCRIPTS_DIR" \
  "$ENGINE" sync
  patch_log "Synchronized Waybar font overrides from user_env.lua (font='${font:-default}', size='${size:-default}')"
else
  patch_log "WaybarFont.sh helper not found; skipping stylesheet sync."
fi

exit 0
