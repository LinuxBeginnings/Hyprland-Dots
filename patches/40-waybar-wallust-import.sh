#!/usr/bin/env bash
# ==================================================
#  KoolDots (2026)
#  Project URL: https://github.com/LinuxBeginnings
#  License: GNU GPLv3
#  SPDX-License-Identifier: GPL-3.0-or-later
# ==================================================
# Patch: repairs Wallust colors imports in the installed Waybar styles.
#
# Same class of problem as patches/30-swaync-wallust-import.sh, but for the
# style files that inject the Wallust palette into Waybar. After Waybar moved
# from ~/.config/waybar to ~/.config/hypr/waybar, any style still importing
# "....config/waybar/wallust/colors-waybar.css" points at a file that no longer
# exists, so the bar silently falls back to its hardcoded colors.
#
# copy.sh already refreshes these files (including a stale-path auto-repair
# when it finds "$HOME/.config/waybar/..." references), but the menu's update
# action only pulls the repo and runs patches - it never re-syncs
# ~/.config/hypr/waybar. Without this patch a stale import would survive there.
#
# Only unambiguous legacy/over-nested targets are rewritten; the two forms the
# repo ships (with and without a leading ../../../) both resolve correctly and
# are deliberately left alone. Idempotent.

# shellcheck source=./lib.sh
. "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/lib.sh"

CONFIG_HOME="${KOOLDOTS_CONFIG_HOME:-${XDG_CONFIG_HOME:-$HOME/.config}}"
WAYBAR_DIR="$CONFIG_HOME/hypr/waybar"
STYLE_DIR="$WAYBAR_DIR/style"

# Waybar always loads its stylesheet through the top-level
# ~/.config/hypr/waybar/style.css (a symlink into style/), so three levels up
# from the stylesheet directory is $HOME.
CANONICAL_IMPORT="@import '../../../.config/hypr/waybar/wallust/colors-waybar.css';"

# Legacy "$HOME/.config/waybar/..." targets and doubly-nested
# "....config/.config/hypr/..." leftovers are both unambiguously broken.
STALE_RE='^[[:space:]]*@import[[:space:]].*\.config/(waybar|\.config/hypr)/.*colors-waybar\.css'

if [ ! -d "$WAYBAR_DIR" ]; then
  patch_log "waybar directory not found; skipping wallust import repair."
  exit 0
fi

files=()
shopt -s nullglob
for css in "$STYLE_DIR"/*.css; do
  files+=("$css")
done
shopt -u nullglob
# A regular top-level style.css is user-managed (the repo installs a symlink
# here, which already resolves into style/ and is covered above).
if [ -f "$WAYBAR_DIR/style.css" ] && [ ! -L "$WAYBAR_DIR/style.css" ]; then
  files+=("$WAYBAR_DIR/style.css")
fi

if [ "${#files[@]}" -eq 0 ]; then
  patch_log "no Waybar stylesheets found; skipping wallust import repair."
  exit 0
fi

repaired=0
for css in "${files[@]}"; do
  [ -f "$css" ] || continue
  grep -qE "$STALE_RE" "$css" 2>/dev/null || continue

  tmp="$(mktemp "${TMPDIR:-/tmp}/kooldots-patch.XXXXXX")" || continue
  if awk -v canonical="$CANONICAL_IMPORT" '
      $0 ~ /^[[:space:]]*@import[[:space:]].*colors-waybar\.css/ {
        if ($0 ~ /\.config\/(waybar|\.config\/hypr)\//) { print canonical; next }
      }
      { print }
    ' "$css" >"$tmp"; then
    cat "$tmp" >"$css"
    patch_log "Repaired Wallust import in $(basename "$css")"
    repaired=$((repaired + 1))
  else
    patch_log "failed to rewrite $(basename "$css"); leaving it unchanged."
  fi
  rm -f "$tmp"
done

if [ "$repaired" -eq 0 ]; then
  patch_log "Waybar styles already import the Wallust colors from the new path; no change."
fi

exit 0
