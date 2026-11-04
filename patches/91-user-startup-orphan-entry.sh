#!/usr/bin/env bash
# ==================================================
#  KoolDots (2026)
#  Project URL: https://github.com/LinuxBeginnings
#  License: GNU GPLv3
#  SPDX-License-Identifier: GPL-3.0-or-later
# ==================================================
# Patch: repair a UserConfigs/user_startup.lua that an earlier installer run left
# unparseable.
#
# enable_ags(), enable_asusctl() and enable_blueman() added their command with
#
#   sed '/local startup_commands = {/a \  "ags",'
#
# which is not anchored. Every template before v2.3.28 ships the startup block
# commented out, so that address matched the COMMENTED `-- local startup_commands
# = {` and the entry was inserted OUTSIDE any table. A stray `  "ags",` at the
# top level is not valid Lua: the whole file failed to parse, lua/user_overrides
# .lua dropped it with a single [WARN], and none of the user's startup commands
# ran. The symptom is only ever "my autostart stopped working".
#
# scripts/lib_apps.sh no longer writes that - it anchors the address, and adds a
# live exec_once() call when the file has no live table. But copy.sh only ADDS
# missing UserConfigs files, so the file left behind on an install that already
# ran the old code would never be replaced. This patch is what repairs it.
#
# Only the exact shape the old installer produced is touched: a COMMENTED
# startup_commands opener, followed immediately by one or more live entry lines.
# A file with a live table is left alone, because there such a line is a
# legitimate member of that table.
#
# The orphan is commented out rather than deleted, which is what the surrounding
# template already looks like. scripts/lib_apps.sh reads only LIVE entries as
# "already enabled", so a later upgrade still adds the command properly.

# shellcheck source=./lib.sh
. "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/lib.sh"

TARGET="$(patch_hypr_dir)/UserConfigs/user_startup.lua"
LIVE_TABLE='^[[:space:]]*local[[:space:]]+startup_commands[[:space:]]*=[[:space:]]*[{]'
COMMENTED_TABLE='^[[:space:]]*--.*local[[:space:]]*startup_commands[[:space:]]*=[[:space:]]*[{]'
ORPHAN='^[[:space:]]*"[^"]*",[[:space:]]*$'

if [ ! -f "$TARGET" ]; then
  patch_log "UserConfigs/user_startup.lua is absent; nothing to repair"
  exit 0
fi

# A live table means the file is the shape the installer expects, so an entry
# line in it is where it belongs.
if grep -qE "$LIVE_TABLE" "$TARGET" 2>/dev/null; then
  patch_log "UserConfigs/user_startup.lua has a live startup_commands table; nothing to repair"
  exit 0
fi

if ! awk -v ct="$COMMENTED_TABLE" -v orph="$ORPHAN" '
      $0 ~ ct { block = 1; next }
      block && $0 ~ orph { found = 1; next }
      block { block = 0 }
      END { exit (found ? 0 : 1) }
    ' "$TARGET"; then
  patch_log "UserConfigs/user_startup.lua has no orphaned startup entry; nothing to repair"
  exit 0
fi

tmp="$(mktemp "${TMPDIR:-/tmp}/kooldots-patch-91.XXXXXX")" || exit 1
if awk -v ct="$COMMENTED_TABLE" -v orph="$ORPHAN" '
      $0 ~ ct { print; block = 1; next }
      block && $0 ~ orph { print "-- " $0; done_n++; next }
      block { block = 0 }
      { print }
      END { exit (done_n > 0 ? 0 : 3) }
    ' "$TARGET" >"$tmp"; then
  cat "$tmp" >"$TARGET"
  patch_log "commented out the orphaned startup entry in UserConfigs/user_startup.lua"
  patch_log "  it sat outside any table, so the file did not parse and nothing in it ran"
  patch_log "  the next upgrade adds the command back as a live entry"
else
  patch_log "UserConfigs/user_startup.lua did not match the broken shape; left unchanged"
fi
rm -f "$tmp"

exit 0
