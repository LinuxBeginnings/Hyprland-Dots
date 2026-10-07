#!/usr/bin/env bash
# ==================================================
#  KoolDots (2026)
#  Project URL: https://github.com/LinuxBeginnings
#  License: GNU GPLv3
#  SPDX-License-Identifier: GPL-3.0-or-later
# ==================================================
# Patch: switch an installed system over to the display-layout system.
#
# copy.sh only ADDS missing UserConfigs files - existing ones are protected, on
# purpose, so a user's edits survive an upgrade. The consequence is that the
# three things the display-layout feature needs in UserConfigs never reach an
# install that already has those files:
#
#   * user_startup.lua has to start MonitorWatcher.sh, or nothing reconciles the
#     layout on login and no monitor event is ever handled;
#   * user_keybinds.lua has to bind SUPER+ALT+D (the menu) and SUPER+ALT+W;
#   * user_laptops.lua has to stop switching the internal panel off when the lid
#     is shut and no external monitor is connected - that leaves the session with
#     no output at all, and MonitorWatcher will not rescue it because the lid is
#     not a monitor event.
#
# user_laptops.lua itself is deliberately left ENABLED. It reads the same
# UserConfigs/monitors.lua that DisplayProfile.sh writes, so the two agree; and
# patches 50, 60 and 70 exist to keep it working.
#
# Everything here is content-idempotent and safe to run on every upgrade.

# shellcheck source=./lib.sh
. "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/lib.sh"

HYPR="$(patch_hypr_dir)"
USERCONFIGS="$HYPR/UserConfigs"
STARTUP="$USERCONFIGS/user_startup.lua"
KEYBINDS="$USERCONFIGS/user_keybinds.lua"
LAPTOPS="$USERCONFIGS/user_laptops.lua"
STORE="$USERCONFIGS/display-layouts.json"

workdir="$(mktemp -d "${TMPDIR:-/tmp}/kooldots-patch-80.XXXXXX")" || exit 1
trap 'rm -rf -- "$workdir"' EXIT

# --- 1. start the watcher on login ------------------------------------------
# Inserted after the startup_commands table's opening line. The table has to be
# found on a line of its own: appending to the end of the file instead would put
# the command outside the table, which is not valid Lua, and silently breaking a
# user's startup file is worse than not applying the patch.
if [ ! -f "$STARTUP" ]; then
  patch_log "user_startup.lua not installed; skipping the watcher"
elif grep -q 'MonitorWatcher\.sh' "$STARTUP" 2>/dev/null; then
  patch_log "user_startup.lua already starts MonitorWatcher.sh; nothing to do"
elif ! grep -qE '^local startup_commands = \{[[:space:]]*$' "$STARTUP" 2>/dev/null; then
  patch_log "user_startup.lua has no startup_commands table on a line of its own; add MonitorWatcher.sh by hand"
else
  if awk '
      { print }
      !done && /^local startup_commands = \{[[:space:]]*$/ {
        print "  -- Monitor management: one watcher per session. It reconciles the"
        print "  -- saved layout on login and after every monitor event, and it is the"
        print "  -- only thing that calls DisplayProfile.sh."
        print "  \"$HOME/.config/hypr/scripts/MonitorWatcher.sh\","
        done = 1
      }
    ' "$STARTUP" >"$workdir/startup.lua"; then
    cat "$workdir/startup.lua" >"$STARTUP"
    patch_log "user_startup.lua now starts MonitorWatcher.sh"
  else
    patch_log "could not rewrite user_startup.lua; add MonitorWatcher.sh by hand"
  fi
fi

# --- 2. the two display-layout keybinds -------------------------------------
# Appended: user_keybinds.lua is a flat list of top-level bind() calls, so the
# end of the file is always inside it.
if [ ! -f "$KEYBINDS" ]; then
  patch_log "user_keybinds.lua not installed; skipping the keybinds"
elif grep -q 'DisplayProfileMenu\.sh' "$KEYBINDS" 2>/dev/null; then
  patch_log "user_keybinds.lua already has the display-layout binds; nothing to do"
else
  cat >>"$KEYBINDS" <<'LUA'

-- =============================================================================
-- DISPLAY LAYOUTS
-- =============================================================================
-- SUPER+ALT+D opens the layout menu for the monitor set in front of you.
-- SUPER+ALT+W applies a layout named Work directly, which is also the fallback
-- for when rofi will not start. Both combos were free: SUPER+ALT+H and
-- SUPER+ALT+P are taken by "horizontal scroll right" and the KB-passthrough
-- submap.
bind(
  "SUPER ALT",
  "D",
  exec_cmd("$HOME/.config/hypr/scripts/DisplayProfileMenu.sh"),
  { description = "Display layouts: menu for this monitor set" }
)
bind(
  "SUPER ALT",
  "W",
  -- A bare layout name is the controller's "apply this layout" verb, passed
  -- after -- so a name that looks like an option stays data. Create a layout
  -- called Work (menu -> Edit parameters) and this key applies it.
  exec_cmd("$HOME/.config/hypr/scripts/DisplayProfile.sh -- Work"),
  { description = "Display layouts: apply the layout named Work" }
)
LUA
  patch_log "user_keybinds.lua now binds SUPER+ALT+D and SUPER+ALT+W"
fi

# --- 3. a shut lid must not switch off the only screen ----------------------
# Only the no-externals branch is touched. Its three lines are matched together,
# because the clamshell branch above has the same `if lid_closed then` followed
# by the same hl.monitor call and must keep its lid test.
if [ ! -f "$LAPTOPS" ]; then
  patch_log "user_laptops.lua not installed; skipping the lid fix"
elif ! grep -q 'elseif int_cfg then' "$LAPTOPS" 2>/dev/null; then
  patch_log "user_laptops.lua does not have the branch this patch knows; skipping the lid fix"
elif awk '
      { n++; L[n] = $0 }
      END {
        for (i = 1; i <= n; i++) {
          if (!done && L[i] == "    if lid_closed then" &&
              L[i+1] == "      hl.monitor({ output = internal, disabled = true })" &&
              L[i+2] == "    elseif int_cfg then") {
            print "    -- A shut lid with no external monitor must NOT switch the only"
            print "    -- screen off: that leaves the session with no output at all."
            print "    if int_cfg then"
            i += 2
            done = 1
            continue
          }
          print L[i]
        }
        if (!done) exit 3
      }
    ' "$LAPTOPS" >"$workdir/laptops.lua"; then
  cat "$workdir/laptops.lua" >"$LAPTOPS"
  patch_log "user_laptops.lua no longer switches the internal panel off when it is the only screen"
else
  patch_log "user_laptops.lua did not match the expected layout; left unchanged"
fi

# --- 4. the layout store ----------------------------------------------------
# lib_copy.sh only ADDS this file, so it should already be there. Creating it
# here means an install that predates the store still starts from a valid one
# rather than from nothing - but only for an install that is actually there: a
# patch must never invent a config tree.
if [ ! -f "$STORE" ] && [ -d "$USERCONFIGS" ]; then
  printf '{"version":1,"fingerprints":{}}\n' >"$STORE"
  patch_log "created an empty layout store at $STORE"
fi

exit 0
