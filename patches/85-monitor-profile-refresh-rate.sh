#!/usr/bin/env bash
# ==================================================
#  KoolDots (2026)
#  Project URL: https://github.com/LinuxBeginnings
#  License: GNU GPLv3
#  SPDX-License-Identifier: GPL-3.0-or-later
# ==================================================
# Patch: makes an installed Monitor_Profiles/HDMI-A-1-HighRefreshRate.lua ask
# for a mode by name instead of `highrr`.
#
# `highrr` is not "the highest refresh rate this monitor can do at the resolution
# it is using". It is the highest refresh rate anywhere in the mode list, whatever
# the resolution. A 1920x1080@75 panel also advertises 1024x768@75.03, so the
# profile named HighRefreshRate went to 1024x768: the resolution was dropped to
# chase 0.06Hz. Hyprland has no keyword for "the best refresh rate at the current
# resolution", so the profile now names one mode and says to edit it per monitor.
#
# copy.sh copies config/hypr wholesale, but on upgrade it then restores
# Monitor_Profiles/ from the backup, because that directory is treated as
# user-owned - its .lua files are the user's own profiles. So a REWRITTEN profile
# never reaches an existing install: the backup's copy wins. That is why this
# needs a patch and not just a repo change, and it is the same reason
# patches/81-monitor-profiles-readme.sh exists for the README.
#
# Only a file that is still byte-for-byte the profile we shipped is replaced.
# Anything else - a mode the user picked, an extra rule, a renamed output - is
# their own profile and is left exactly as it is. The replacement is the content
# the repo ships, so a patched install and a fresh one agree.

# shellcheck source=./lib.sh
. "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/lib.sh"

TARGET="$(patch_hypr_dir)/Monitor_Profiles/HDMI-A-1-HighRefreshRate.lua"

if [ ! -f "$TARGET" ]; then
  patch_log "HDMI-A-1-HighRefreshRate.lua not installed; skipping"
  exit 0
fi

if grep -q 'The mode is spelled out on purpose' "$TARGET" 2>/dev/null; then
  patch_log "the high-refresh profile already names its mode; nothing to do"
  exit 0
fi

workdir="$(mktemp -d "${TMPDIR:-/tmp}/kooldots-patch-85.XXXXXX")" || exit 1
old="$workdir/shipped.lua"
new="$workdir/fixed.lua"

# The profile as v2.3.28 shipped it. Matching it byte-for-byte is the guard: a
# user who changed anything in here has made the file their own, and guessing at
# what they meant is not this patch's business.
cat >"$old" <<'LUA'
-- ==================================================
--  KoolDots (2026)
--  Project URL: https://github.com/LinuxBeginnings
--  License: GNU GPLv3
--  SPDX-License-Identifier: GPL-3.0-or-later
-- ==================================================

-- HDMI-A-1 High Refresh Rate profile

hl.monitor({
    output = "HDMI-A-1",
    mode = "highrr",
    position = "auto",
    scale = "1",
})
LUA

# The replacement. It has to stay byte-identical to the repo's
# config/hypr/Monitor_Profiles/HDMI-A-1-HighRefreshRate.lua, so that a patched
# install and a fresh one agree.
cat >"$new" <<'LUA'
-- ==================================================
--  KoolDots (2026)
--  Project URL: https://github.com/LinuxBeginnings
--  License: GNU GPLv3
--  SPDX-License-Identifier: GPL-3.0-or-later
-- ==================================================

-- HDMI-A-1 High Refresh Rate profile
--
-- The mode is spelled out on purpose. Hyprland's "highrr" keyword is not "the
-- highest refresh rate this monitor can do at the resolution it is using": it is
-- the highest refresh rate anywhere in the mode list, whatever the resolution.
-- A 1920x1080@75 panel that also advertises 1024x768@75.03 therefore goes to
-- 1024x768 under "highrr" - the resolution is dropped to chase 0.06Hz. There is
-- no keyword for "the best refresh rate at the current resolution", so this
-- profile asks for one mode by name.
--
-- Edit the mode to match the monitor on this port. `hyprctl monitors all` lists
-- what it advertises, and a value close to an advertised one is matched to it,
-- so "1920x1080@75" reaches a 74.97Hz mode. A mode the monitor does not
-- advertise leaves the panel on its preferred mode instead - Hyprland ignores
-- the rule rather than reporting an error.
hl.monitor({
    output = "HDMI-A-1",
    mode = "1920x1080@75",
    position = "auto",
    scale = "1",
})
LUA

if ! cmp -s -- "$old" "$TARGET"; then
  patch_log "HDMI-A-1-HighRefreshRate.lua is not the profile we shipped; leaving it alone"
  rm -rf "$workdir"
  exit 0
fi

# Write beside the target and rename: a truncated write would leave a profile the
# user could pick and get a broken rule from. The temp name has no .lua suffix,
# so MonitorProfiles.sh never offers it and the config's syntax sweep ignores it.
tmp="$(mktemp -- "$(dirname -- "$TARGET")/.kooldots-profile.XXXXXX")" || {
  patch_log "could not create a temporary file beside $TARGET; left it in place"
  rm -rf "$workdir"
  exit 1
}
if cat "$new" >"$tmp" && chmod 644 "$tmp" 2>/dev/null; then
  if mv -f -- "$tmp" "$TARGET"; then
    patch_log "HDMI-A-1-HighRefreshRate.lua now asks for 1920x1080@75, not highrr"
    patch_log "  highrr is the highest refresh rate at ANY resolution"
    patch_log "  on a 1920x1080@75 panel it picked 1024x768@75.03 instead"
    patch_log "  edit the mode if the monitor on this port is not 1920x1080"
    rm -rf "$workdir"
    exit 0
  fi
fi
rm -f -- "$tmp" 2>/dev/null || true
patch_log "could not write $TARGET; left it in place"
rm -rf "$workdir"
exit 1
