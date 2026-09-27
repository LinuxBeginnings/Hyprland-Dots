#!/usr/bin/env bash
# ==================================================
#  KoolDots (2026)
#  Project URL: https://github.com/LinuxBeginnings
#  License: GNU GPLv3
#  SPDX-License-Identifier: GPL-3.0-or-later
# ==================================================
# Patch: waybar moved from ~/.config/waybar to ~/.config/hypr/waybar, so the
# wallust colors file swaync imports now lives at
# ~/.config/hypr/waybar/wallust/colors-waybar.css.
#
# swaync's style.css is a user-owned file: copy.sh only replaces it when the
# user explicitly answers "yes", and the in-place repo update only runs
# patches. So installs carried over from before the migration keep importing
# the old ~/.config/waybar path, and swaync silently falls back to its default
# colors (the missing semicolon variants also logged GTK CSS parse errors).
#
# This patch rewrites only the wallust @import line to the canonical relative
# form. Idempotent: leaves the file untouched when the import is already
# correct, and does nothing when swaync has no colors-waybar import at all.

# shellcheck source=./lib.sh
. "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/lib.sh"

SWAYNC_CSS="${KOOLDOTS_CONFIG_HOME:-${XDG_CONFIG_HOME:-$HOME/.config}}/swaync/style.css"

if [ ! -f "$SWAYNC_CSS" ]; then
  patch_log "swaync style.css not found; skipping wallust colors import fix."
  exit 0
fi

CANONICAL_IMPORT="@import '../../.config/hypr/waybar/wallust/colors-waybar.css';"
IMPORT_RE='^[[:space:]]*@import[[:space:]].*colors-waybar\.css'
CANONICAL_RE='^[[:space:]]*@import[[:space:]]+["'\'']\.\./\.\./\.config/hypr/waybar/wallust/colors-waybar\.css["'\''][[:space:]]*;'

if ! grep -qE "$IMPORT_RE" "$SWAYNC_CSS" 2>/dev/null; then
  patch_log "swaync style.css has no colors-waybar import; no change."
  exit 0
fi

stale=0
while IFS= read -r line || [ -n "$line" ]; do
  printf '%s\n' "$line" | grep -qE "$IMPORT_RE" 2>/dev/null || continue
  printf '%s\n' "$line" | grep -qE "$CANONICAL_RE" 2>/dev/null || stale=1
done <"$SWAYNC_CSS"

if [ "$stale" -eq 0 ]; then
  patch_log "swaync style.css already imports the wallust colors from the new waybar path; no change."
  exit 0
fi

tmp="$(mktemp "${TMPDIR:-/tmp}/kooldots-patch.XXXXXX")" || {
  patch_log "could not create a temporary file; skipping swaync import fix."
  exit 0
}

if awk -v canonical="$CANONICAL_IMPORT" '
    $0 ~ /^[[:space:]]*@import[[:space:]].*colors-waybar\.css/ { print canonical; next }
    { print }
  ' "$SWAYNC_CSS" >"$tmp"; then
  cat "$tmp" >"$SWAYNC_CSS"
  patch_log "Rewrote swaync wallust colors import to ../../.config/hypr/waybar/wallust/colors-waybar.css"
else
  patch_log "failed to rewrite swaync style.css; leaving it unchanged."
fi
rm -f "$tmp"

if [ ! -f "${KOOLDOTS_CONFIG_HOME:-${XDG_CONFIG_HOME:-$HOME/.config}}/hypr/waybar/wallust/colors-waybar.css" ]; then
  patch_log "note: waybar wallust colors not found yet; re-apply a wallpaper to (re)generate them."
fi

exit 0
