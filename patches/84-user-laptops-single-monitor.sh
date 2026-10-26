#!/usr/bin/env bash
# ==================================================
#  KoolDots (2026)
#  Project URL: https://github.com/LinuxBeginnings
#  License: GNU GPLv3
#  SPDX-License-Identifier: GPL-3.0-or-later
# ==================================================
# Patch: makes an installed UserConfigs/user_laptops.lua keep the internal panel
# usable when it is the only screen - no external display connected.
#
# The no-externals branch replayed the stored rule for the panel:
#
#   local int_cfg = get_monitor_config(internal)
#   if int_cfg then
#     hl.monitor(int_cfg)
#
# Two things are wrong with replaying it. In Hyprland's Lua monitor API a rule
# that OMITS `disabled` leaves the output off - it is not an enable - so a stored
# rule without it leaves the only screen dark. And a single monitor belongs at
# the origin: a rule carried over from a monitor set that had more keeps its old
# position, while its transform (rotation) was dropped entirely.
#
# The branch now builds the rule the way the lid-open branch does - mode, scale
# and transform from the stored rule, with `disabled = false` and
# `position = "0x0"` forced - so one monitor on one panel is always on, upright
# and at 0x0.
#
# copy.sh only adds missing UserConfigs templates (existing files are protected),
# so an install that already shipped user_laptops.lua would keep the old branch
# forever. This patch rewrites that one block, leaves the rest of the file
# intact, and is content-idempotent.
#
# The block it matches is the one patches/80-display-layouts.sh leaves behind,
# and it runs after it. An install whose file patch 80 could not recognise is
# skipped here too rather than guessed at: anything that is not exactly this
# shape is a customised file and is left alone.
#
# Lid handling stays in user_laptops.lua: nothing else binds the lid switch.

# shellcheck source=./lib.sh
. "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/lib.sh"

TARGET="$(patch_hypr_dir)/UserConfigs/user_laptops.lua"

if [ ! -f "$TARGET" ]; then
  patch_log "user_laptops.lua not installed; skipping"
  exit 0
fi

if grep -q 'the internal panel is the ONLY screen' "$TARGET" 2>/dev/null; then
  patch_log "user_laptops.lua already treats the internal panel as the only screen; nothing to do"
  exit 0
fi

workdir="$(mktemp -d "${TMPDIR:-/tmp}/kooldots-patch-84.XXXXXX")" || exit 1
block="$workdir/no-externals.lua"
out="$workdir/patched.lua"

# The replacement branch. It has to stay byte-identical to the repo's
# UserConfigs/user_laptops.lua, so that a patched install and a fresh one agree.
cat >"$block" <<'LUA'
    -- No external displays connected, so the internal panel is the ONLY screen.
    -- It stays on whatever the lid is doing: a closed lid with nothing else to
    -- show the session must not blank the panel, or the laptop goes dark with no
    -- way back. Mode and scale are still taken from the stored config, but its
    -- on/off state and position are overridden - a single monitor belongs at the
    -- origin, and the stored config may belong to a monitor set that had more.
    local int_cfg = get_monitor_config(internal)
    local int_on = {
      output = internal,
      disabled = false,
      mode = (int_cfg and int_cfg.mode) or default_fallback.mode or "preferred",
      position = "0x0",
      scale = (int_cfg and int_cfg.scale) or default_fallback.scale or "auto",
    }
    if int_cfg and int_cfg.transform then
      int_on.transform = int_cfg.transform
    end
    hl.monitor(int_on)
LUA

# The block being replaced, matched in full rather than by its first line: the
# two comments above it were written by patch 80 and the table below it is the
# fallback the clamshell path also relies on, so a half-match would rewrite
# something this patch has no business touching.
awk -v block="$block" '
  function emit(f,   line) {
    while ((getline line < f) > 0) print line
    close(f)
  }

  { n++; L[n] = $0 }
  END {
    for (i = 1; i <= n; i++) {
      if (!done &&
          L[i]    == "    -- No external displays connected: internal panel must be enabled (unless lid is closed)" &&
          L[i+1]  == "    local int_cfg = get_monitor_config(internal)" &&
          L[i+2]  == "    -- A shut lid with no external monitor must NOT switch the only" &&
          L[i+3]  == "    -- screen off: that leaves the session with no output at all." &&
          L[i+4]  == "    if int_cfg then" &&
          L[i+5]  == "      hl.monitor(int_cfg)" &&
          L[i+6]  == "    else" &&
          L[i+7]  == "      hl.monitor({" &&
          L[i+8]  == "        output = internal," &&
          L[i+9]  == "        disabled = false," &&
          L[i+10] == "        mode = default_fallback.mode or \"preferred\"," &&
          L[i+11] == "        position = \"0x0\"," &&
          L[i+12] == "        scale = default_fallback.scale or \"auto\"," &&
          L[i+13] == "      })" &&
          L[i+14] == "    end") {
        emit(block)
        i += 14
        done = 1
        continue
      }
      print L[i]
    }
    if (!done) exit 3
  }
' "$TARGET" >"$out" || {
  patch_log "user_laptops.lua does not have the no-externals branch this patch knows; add the fix by hand"
  rm -rf "$workdir"
  exit 0
}

# Sanity check before writing: the new branch is in place, the old one is gone,
# the clamshell disable survived, and the function it lives in is still there.
if ! grep -q 'the internal panel is the ONLY screen' "$out" 2>/dev/null ||
  ! grep -q 'hl.monitor(int_on)' "$out" 2>/dev/null ||
  ! grep -q 'disabled = true' "$out" 2>/dev/null ||
  ! grep -q '^  if #externals > 0 then' "$out" 2>/dev/null ||
  grep -q 'A shut lid with no external monitor must NOT switch' "$out" 2>/dev/null; then
  patch_log "user_laptops.lua did not match the expected layout; left unchanged"
  rm -rf "$workdir"
  exit 1
fi

cat "$out" >"$TARGET"
rm -rf "$workdir"
patch_log "user_laptops.lua now keeps the only screen on, upright, at the origin"
exit 0
