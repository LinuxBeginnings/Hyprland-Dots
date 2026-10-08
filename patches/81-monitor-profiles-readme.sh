#!/usr/bin/env bash
# ==================================================
#  KoolDots (2026)
#  Project URL: https://github.com/LinuxBeginnings
#  License: GNU GPLv3
#  SPDX-License-Identifier: GPL-3.0-or-later
# ==================================================
# Patch: tell an installed Monitor_Profiles/README how profiles work now.
#
# copy.sh copies config/hypr wholesale, but on upgrade `restore_hypr_assets` then
# copies the backup's Monitor_Profiles/ back over it, because that directory is
# treated as user-owned - its .lua files are the user's own profiles. That is a
# merge, so a NEW file the repo ships still lands, but a REWRITTEN one does not:
# the backup's copy wins. The README is therefore the one file in there that needs
# a patch to reach an existing install.
#
# It APPENDS, and never rewrites: the README is a user-owned file, and a user may
# have written their own notes in it. Everything already there is kept, and the
# note is added once.

# shellcheck source=./lib.sh
. "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/lib.sh"

README="$(patch_hypr_dir)/Monitor_Profiles/README"
MARKER='# Managed by the display-layout system: see README-display-profiles.md.'

if [ ! -f "$README" ]; then
  patch_log "Monitor_Profiles/README not installed; skipping"
  exit 0
fi

# The same line the repo's own copy starts with, so a fresh install - which gets
# that copy - is already up to date and this is a no-op there.
if grep -qF "$MARKER" "$README" 2>/dev/null; then
  patch_log "Monitor_Profiles/README already says how profiles work; nothing to do"
  exit 0
fi

if cat >>"$README" <<NOTE

$MARKER

# The guidance above predates the display-layout system. A .lua file in this
# directory is now a PROFILE: a set of hl.monitor rules matched by port, which
# Hyprland applies at every config load. Work.lua ships as an example.

# Choose one from Quick Settings (SUPER + SHIFT + E) -> Choose Monitor Profiles.
# That applies its rules and saves what is on screen as a layout for the monitors
# you have connected, so SUPER + ALT + W applies a layout named Work from then on.

# For an arrangement that follows the monitor rather than the port, save a layout
# from the layout menu (SUPER + ALT + D) instead.

# Do NOT add require("monitors") to your Hyprland config. On nwg-displays 0.4.3+
# that loads the Lua file nwg writes next to its .conf, and it would then compete
# with UserConfigs/monitors.lua.
NOTE
then
  patch_log "appended the current profile notes to Monitor_Profiles/README"
else
  patch_log "could not append to Monitor_Profiles/README"
  exit 1
fi

exit 0
