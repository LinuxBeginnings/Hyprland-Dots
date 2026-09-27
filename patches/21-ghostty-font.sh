#!/usr/bin/env bash
# ==================================================
#  KoolDots (2026)
#  Project URL: https://github.com/LinuxBeginnings
#  License: GNU GPLv3
#  SPDX-License-Identifier: GPL-3.0-or-later
# ==================================================
# Patch: Update Ghostty default font to JetBrainsMono Nerd Font Mono and migrate
# any non-standard "Iosevkeley Mono" references left from older templates.
# Content-idempotent: leaves files untouched if already configured.

# shellcheck source=./lib.sh
. "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/lib.sh"

migrate_font_config() {
  local file="$1"
  [ -f "$file" ] || return 0

  local modified=0

  # 1. Migrate non-standard "Iosevkeley Mono" to standard "JetBrainsMono Nerd Font Mono"
  if grep -qE '^[[:space:]]*font-family(-bold|-italic|-bold-italic)?[[:space:]]*=[[:space:]]*"?Iosevkeley Mono"?' "$file" 2>/dev/null; then
    sed -i -E 's/^[[:space:]]*font-family[[:space:]]*=[[:space:]]*"?Iosevkeley Mono"?/font-family = "JetBrainsMono Nerd Font Mono"/' "$file"
    sed -i -E '/^[[:space:]]*font-family-(bold|italic|bold-italic)[[:space:]]*=[[:space:]]*"?Iosevkeley Mono"?/d' "$file"
    modified=1
  fi

  # 2. Ensure at least one active font-family is present
  if ! grep -qE '^[[:space:]]*font-family[[:space:]]*=' "$file" 2>/dev/null; then
    patch_ensure_line_after \
      "$file" \
      '^[[:space:]]*font-size[[:space:]]*=' \
      '^[[:space:]]*font-family[[:space:]]*=' \
      'font-family = "JetBrainsMono Nerd Font Mono"'
    modified=1
  fi

  # 3. Ensure Symbols Nerd Font Mono fallback is present if JetBrainsMono is set
  if grep -qE '^[[:space:]]*font-family[[:space:]]*=[[:space:]]*"?JetBrainsMono' "$file" 2>/dev/null && \
     ! grep -qE '^[[:space:]]*font-family[[:space:]]*=[[:space:]]*"?Symbols Nerd Font Mono"?' "$file" 2>/dev/null; then
    patch_ensure_line_after \
      "$file" \
      '^[[:space:]]*font-family[[:space:]]*=[[:space:]]*"?JetBrainsMono' \
      '^[[:space:]]*font-family[[:space:]]*=[[:space:]]*"?Symbols Nerd Font Mono"?' \
      'font-family = "Symbols Nerd Font Mono"'
    modified=1
  fi

  if [ "$modified" -eq 1 ]; then
    patch_log "Updated Ghostty font configuration in ${file}"
    return 1
  fi
  return 0
}

changed=0

MANAGED_GHOSTTY="$(patch_hypr_dir)/UserConfigs/ghostty.conf"
if [ -f "$MANAGED_GHOSTTY" ]; then
  migrate_font_config "$MANAGED_GHOSTTY" || changed=1
else
  patch_log "ghostty.conf not found; skipping font fix."
fi

RUNTIME_GHOSTTY="$KOOLDOTS_CONFIG_HOME/ghostty/config"
if [ -f "$RUNTIME_GHOSTTY" ]; then
  migrate_font_config "$RUNTIME_GHOSTTY" || changed=1
fi

if [ "$changed" -eq 0 ]; then
  patch_log "Ghostty font configuration already up to date."
fi

exit 0
