#!/usr/bin/env bash
# ==================================================
#  KoolDots (2026)
#  Project URL: https://github.com/LinuxBeginnings
#  License: GNU GPLv3
#  SPDX-License-Identifier: GPL-3.0-or-later
# ==================================================
# Patch: give an installed UserConfigs/user_keybinds.lua the helper bindings it
# is missing, so unbind(...) and dispatch(...) resolve instead of aborting it.
#
# v2.3.24 through v2.3.26.1 shipped a user_keybinds.lua that pulled only two
# functions out of lua/user_keybinds_helper.lua:
#
#   local exec_cmd = user_keybinds_helper.exec_cmd
#   local bind = user_keybinds_helper.bind
#
# The helper has exported dispatch() and unbind() since v2.3.24, but the
# template never reached into it for them, so from that file both names were
# undefined globals. The first call to either raised
#
#   attempt to call a nil value (global 'unbind')
#
# which aborts the rest of the file. lua/user_overrides.lua loads user files
# through pcall, so the failure surfaces as a single [WARN] in the Hyprland log
# and every bind below the call is silently dropped. The visible symptom is
# "my unbind does nothing", and a hand-written pcall(hl.unbind, "SUPER + T")
# works, because it bypasses the helper entirely - which is what made this read
# as the helper having no unbind at all. See issue #164.
#
# v2.3.26.2 fixed the template, but copy.sh only ADDS missing UserConfigs files
# (scripts/lib_copy.sh, ensure_lua_keybinds), so an install made before that
# release keeps the old file and never sees the fix. This patch is what carries
# it across, exactly as docs/Patching-UserConfigs.md describes.
#
# Only the two missing lines are inserted, each immediately after the helper
# line the file already has, so the result matches the shipped template's
# order. Nothing else is touched: a file that already binds them is left
# alone, and a file that does not load the helper at all is skipped rather
# than given a line that would read from a name it never defined.

# shellcheck source=./lib.sh
. "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/lib.sh"

TARGET="$(patch_hypr_dir)/UserConfigs/user_keybinds.lua"

if [ ! -f "$TARGET" ]; then
  patch_log "UserConfigs/user_keybinds.lua is absent; nothing to patch"
  exit 0
fi

# Without the helper there is no user_keybinds_helper table to read from, so
# adding these lines would replace one error with another.
if ! grep -q 'user_keybinds_helper' "$TARGET" 2>/dev/null; then
  patch_log "UserConfigs/user_keybinds.lua does not load the keybind helper; leaving it alone"
  exit 0
fi

# [.] rather than an escaped dot: these anchors are handed to awk as well as
# to grep -E (patches/lib.sh, patch_ensure_line_after), and awk warns about the
# backslash form.
EXEC_ANCHOR='^[[:space:]]*local[[:space:]]+exec_cmd[[:space:]]*=[[:space:]]*user_keybinds_helper[.]exec_cmd'
BIND_ANCHOR='^[[:space:]]*local[[:space:]]+bind[[:space:]]*=[[:space:]]*user_keybinds_helper[.]bind'

changed=0

if grep -qE "$EXEC_ANCHOR" "$TARGET" 2>/dev/null; then
  before="$(cat "$TARGET")"
  patch_ensure_line_after "$TARGET" "$EXEC_ANCHOR" \
    '^[[:space:]]*local[[:space:]]+dispatch[[:space:]]*=' \
    'local dispatch = user_keybinds_helper.dispatch'
  [ "$(cat "$TARGET")" != "$before" ] && changed=1
fi

if grep -qE "$BIND_ANCHOR" "$TARGET" 2>/dev/null; then
  before="$(cat "$TARGET")"
  patch_ensure_line_after "$TARGET" "$BIND_ANCHOR" \
    '^[[:space:]]*local[[:space:]]+unbind[[:space:]]*=' \
    'local unbind = user_keybinds_helper.unbind'
  [ "$(cat "$TARGET")" != "$before" ] && changed=1
fi

if [ "$changed" -eq 1 ]; then
  patch_log "added the missing dispatch/unbind helper bindings to UserConfigs/user_keybinds.lua"
  patch_log "  the file no longer aborts on the first unbind(...) or dispatch(...) call"
else
  patch_log "UserConfigs/user_keybinds.lua already binds the helper functions; nothing to do"
fi

exit 0
