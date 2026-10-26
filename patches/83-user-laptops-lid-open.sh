#!/usr/bin/env bash
# ==================================================
#  KoolDots (2026)
#  Project URL: https://github.com/LinuxBeginnings
#  License: GNU GPLv3
#  SPDX-License-Identifier: GPL-3.0-or-later
# ==================================================
# Patch: makes an installed UserConfigs/user_laptops.lua turn the internal panel
# back on when the lid is opened.
#
# The lid-open branch replayed the stored rule for the panel:
#
#   local int_cfg = get_monitor_config(internal)
#   if int_cfg then
#     hl.monitor(int_cfg)
#
# In Hyprland's Lua monitor API a rule that OMITS `disabled` leaves the output
# disabled - it is not an enable. The rules users end up with in
# UserConfigs/monitors.lua, and the ones the shipped Monitor_Profiles carry, omit
# it, so `hl.monitor(int_cfg)` was a no-op on a panel that the lid-close bind had
# just switched off. The lid opened, the panel stayed dark, and its workspaces
# stayed on the external monitor.
#
# Only a rule that names `disabled = false` brings the output back, which is why
# every other path in these dots spells it out. The branch now builds the rule
# from the stored mode, position, scale and transform, and always adds
# `disabled = false` - the same shape the no-externals branch already uses.
#
# copy.sh only adds missing UserConfigs templates (existing files are protected),
# so an install that already shipped user_laptops.lua would keep the old branch
# forever. This patch rewrites that one block, leaves the rest of the file
# intact, and is content-idempotent.
#
# Lid handling stays in user_laptops.lua: nothing else binds the lid switch.

# shellcheck source=./lib.sh
. "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/lib.sh"

TARGET="$(patch_hypr_dir)/UserConfigs/user_laptops.lua"

if [ ! -f "$TARGET" ]; then
  patch_log "user_laptops.lua not installed; skipping"
  exit 0
fi

if grep -q 'the internal panel has to come back ON' "$TARGET" 2>/dev/null; then
  patch_log "user_laptops.lua already re-enables the panel on lid open; nothing to do"
  exit 0
fi

workdir="$(mktemp -d "${TMPDIR:-/tmp}/kooldots-patch-83.XXXXXX")" || exit 1
block="$workdir/lid-open.lua"
out="$workdir/patched.lua"

# The replacement branch. It has to stay byte-identical to the repo's
# UserConfigs/user_laptops.lua, so that a patched install and a fresh one agree.
cat >"$block" <<'LUA'
      -- Lid is open: the internal panel has to come back ON, so `disabled = false`
      -- is forced rather than replayed. In the Lua monitor API a rule that omits
      -- `disabled` leaves the output off, and the rules in monitors.lua (and the
      -- shipped Monitor_Profiles) do omit it - replaying one verbatim is what
      -- left the panel dark after a lid open. Mode, position, scale and
      -- transform still come from the stored rule.
      local int_cfg = get_monitor_config(internal)
      local int_on = {
        output = internal,
        disabled = false,
        mode = (int_cfg and int_cfg.mode) or default_fallback.mode or "preferred",
        position = (int_cfg and int_cfg.position) or default_fallback.position or "auto",
        scale = (int_cfg and int_cfg.scale) or default_fallback.scale or "auto",
      }
      if int_cfg and int_cfg.transform then
        int_on.transform = int_cfg.transform
      end
      hl.monitor(int_on)
LUA

# The block being replaced, matched in full rather than by its first line: the
# clamshell branch above it opens with the same `else`, and a half-match would
# cut the lid test out of clamshell mode. Anything that is not exactly this
# thirteen-line shape is a customised file and is left alone.
awk -v block="$block" '
  function emit(f,   line) {
    while ((getline line < f) > 0) print line
    close(f)
  }

  { n++; L[n] = $0 }
  END {
    for (i = 1; i <= n; i++) {
      if (!done &&
          L[i]    == "      -- Lid is open: apply internal display configuration from monitors.lua" &&
          L[i+1]  == "      local int_cfg = get_monitor_config(internal)" &&
          L[i+2]  == "      if int_cfg then" &&
          L[i+3]  == "        hl.monitor(int_cfg)" &&
          L[i+4]  == "      else" &&
          L[i+5]  == "        hl.monitor({" &&
          L[i+6]  == "          output = internal," &&
          L[i+7]  == "          disabled = false," &&
          L[i+8]  == "          mode = default_fallback.mode or \"preferred\"," &&
          L[i+9]  == "          position = default_fallback.position or \"auto\"," &&
          L[i+10] == "          scale = default_fallback.scale or \"auto\"," &&
          L[i+11] == "        })" &&
          L[i+12] == "      end") {
        emit(block)
        i += 12
        done = 1
        continue
      }
      print L[i]
    }
    if (!done) exit 3
  }
' "$TARGET" >"$out" || {
  patch_log "user_laptops.lua does not have the lid-open branch this patch knows; add the fix by hand"
  rm -rf "$workdir"
  exit 0
}

# Sanity check before writing: the new branch is in place, the old one is gone,
# the clamshell disable survived, and the function it lives in is still there.
if ! grep -q 'the internal panel has to come back ON' "$out" 2>/dev/null ||
  ! grep -q 'hl.monitor(int_on)' "$out" 2>/dev/null ||
  ! grep -q 'disabled = true' "$out" 2>/dev/null ||
  ! grep -q '^  if #externals > 0 then' "$out" 2>/dev/null ||
  grep -q 'Lid is open: apply internal display configuration' "$out" 2>/dev/null; then
  patch_log "user_laptops.lua did not match the expected layout; left unchanged"
  rm -rf "$workdir"
  exit 1
fi

cat "$out" >"$TARGET"
rm -rf "$workdir"
patch_log "user_laptops.lua now turns the internal panel back on when the lid opens"
exit 0
