#!/usr/bin/env bash
# ==================================================
#  KoolDots (2026)
#  Project URL: https://github.com/LinuxBeginnings
#  License: GNU GPLv3
#  SPDX-License-Identifier: GPL-3.0-or-later
# ==================================================
# Patch: the Ghostty palette moved out of ~/.config/ghostty and into
# hypr/UserConfigs, so it sits with every other Kooldots-owned config and
# another tool cannot overwrite it. Kitty's palette has always lived there.
#
# An install that still names the old path would keep a `config-file` pointing
# at a file nothing writes, which reads as Ghostty silently losing wallpaper
# colours. This moves the generated palette, then rewrites the include in both
# the managed config and the runtime copy Ghostty actually reads.
#
# Content-idempotent: a file that no longer names the old path is left alone,
# so a fresh install and a repeat run both skip.

# shellcheck source=./lib.sh
. "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/lib.sh"

readonly OLD_PATH="$KOOLDOTS_CONFIG_HOME/ghostty/wallust.conf"
readonly NEW_DIR="$(patch_hypr_dir)/UserConfigs/ghostty-themes"
readonly NEW_PATH="$NEW_DIR/01-Wallust.conf"
readonly MANAGED_CONFIG="$(patch_hypr_dir)/UserConfigs/ghostty.conf"
readonly RUNTIME_CONFIG="$KOOLDOTS_CONFIG_HOME/ghostty/config"

# rewrite_include <file> - point a wallust include at the new path, keeping
# whether it was commented. Returns 0 whether or not a change was needed.
rewrite_include() {
  local file="$1" tmp

  [ -f "$file" ] || return 0

  # Nothing to do when the file does not name the old path. Covers a fresh
  # install, which has no include line, and a repeat run.
  if ! grep -qE '^[[:space:]]*#?[[:space:]]*config-file[[:space:]]*=.*ghostty/wallust\.conf' "$file" 2>/dev/null; then
    return 0
  fi

  tmp="$(mktemp "${TMPDIR:-/tmp}/kooldots-patch.XXXXXX")" || return 1
  if sed -E "s|^([[:space:]]*#?[[:space:]]*config-file[[:space:]]*=).*ghostty/wallust\.conf.*$|\1 $NEW_PATH|" "$file" >"$tmp"; then
    cat "$tmp" >"$file"
    rm -f "$tmp"
    patch_log "Ghostty palette include now names $NEW_PATH in $file"
    return 0
  fi
  rm -f "$tmp"
  return 1
}

mkdir -p "$NEW_DIR" 2>/dev/null || true

# Move the palette itself, so the colours survive until the next wallpaper
# change re-renders it. When both exist the new one is the live one.
if [ -f "$OLD_PATH" ]; then
  if [ ! -f "$NEW_PATH" ] && mv -f "$OLD_PATH" "$NEW_PATH" 2>/dev/null; then
    patch_log "Moved the Ghostty palette to $NEW_PATH"
  else
    rm -f "$OLD_PATH" 2>/dev/null || true
  fi
fi

rewrite_include "$MANAGED_CONFIG"
rewrite_include "$RUNTIME_CONFIG"

exit 0
