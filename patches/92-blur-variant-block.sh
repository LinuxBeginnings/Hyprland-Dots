#!/usr/bin/env bash
# ==================================================
#  KoolDots (2026)
#  Project URL: https://github.com/LinuxBeginnings
#  License: GNU GPLv3
#  SPDX-License-Identifier: GPL-3.0-or-later
# ==================================================
# Patch: give an installed UserConfigs/user_decorations.lua the Hyprland 0.57
# blur-variant and wobble blocks.
#
# copy.sh only ADDS missing UserConfigs files, so an install made before those
# blocks shipped keeps its old user_decorations.lua and never sees them. The blur
# strength cycle still works (SUPER ALT O writes enabled/size/passes), while
# `variant` and window wobble stay absent - which reads as "the new blur options
# do nothing here". This patch is what carries them across, exactly as
# docs/Patching-UserConfigs.md describes.
#
# Two independent blocks are appended, each with its own sentinel comment:
#
#   * blur-variant-block writes only `decoration.blur.variant`, defaulted to
#     kawase, so applying it changes nothing until a variant is chosen. The
#     comment above it names the eleven variants and the per-variant tables.
#   * wobble-block writes the same physics table the shipped file carries, so
#     SUPER SHIFT X (scripts/ToggleWobble.sh) has a table to flip.
#
# A block is skipped when the file already configures that feature - by this
# patch (sentinel), by the shipped template (its gated block), or by the user's
# own `variant = ...` / `wobble = { ... }`. That last case matters: appending a
# default `kawase` write over a chosen variant would silently reset it on every
# upgrade, because the appended code runs last.
#
# Both blocks are gated inside Lua on hl.get_config, so a 0.56 compositor skips
# them instead of rejecting keys it does not have.

# shellcheck source=./lib.sh
. "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/lib.sh"

TARGET="$(patch_hypr_dir)/UserConfigs/user_decorations.lua"

if [ ! -f "$TARGET" ]; then
  patch_log "UserConfigs/user_decorations.lua is absent; nothing to patch"
  exit 0
fi

VARIANT_MARK='kooldots-patch: blur-variant-block'
WOBBLE_MARK='kooldots-patch: wobble-block'

append_variant_block() {
  cat >>"$TARGET" <<'LUA'

-- kooldots-patch: blur-variant-block
-- Blur variants (Hyprland 0.57+). A fresh user_decorations.lua ships this block;
-- existing installs keep their own file, so patches/92-blur-variant-block.sh
-- adds it here.
--
-- Values for `variant`: kawase (default), frost, ripple, drops, water,
-- fluid_jar, prism, heat_shimmer, acrylic, aurora, haze.
-- frost and prism read decoration.blur.glass. Every variant also has its own
-- table (haze = { intensity, iridescence }, ripple = { duration, radius,
-- strength, width }, drops = { speed }, ...); the animated ones cost GPU time.
-- Only the keys below are written, and an older compositor skips the block.
local kd_has_option = function(key)
  if type(hl) ~= "table" or type(hl.get_config) ~= "function" then
    return false
  end
  local ok, value = pcall(hl.get_config, key)
  return ok and value ~= nil
end

if kd_has_option("decoration.blur.variant") then
  hl.config({
    decoration = {
      blur = {
        variant = "kawase",
      },
    },
  })
end
LUA
}

append_wobble_block() {
  cat >>"$TARGET" <<'LUA'

-- kooldots-patch: wobble-block
-- Window wobble (Hyprland 0.57+), the same table a fresh install carries.
-- SUPER SHIFT X or scripts/ToggleWobble.sh rewrites the `enabled` value below
-- in place, matching the keys by name, so reformat this freely.
-- Physics: upstream defaults are mesh 12, stiffness 200, damping 12. These are
-- stiffer, so the window settles instead of swinging (damping ratio ~0.52).
local kd_has_option = function(key)
  if type(hl) ~= "table" or type(hl.get_config) ~= "function" then
    return false
  end
  local ok, value = pcall(hl.get_config, key)
  return ok and value ~= nil
end

if kd_has_option("decoration.wobble.enabled") then
  hl.config({
    decoration = {
      wobble = {
        enabled = true,
        mesh = 12,
        stiffness = 240,
        damping = 16,
        mass = 1,
        intensity = 0.25,
        value_epsilon = 0.25,
        velocity_epsilon = 2,
      },
    },
  })
end
LUA
}

changed=0

# `decoration.blur.variant` covers the shipped template's gate line; the bare
# assignment covers a file where the user already picked one by hand.
if grep -qF "$VARIANT_MARK" "$TARGET" 2>/dev/null \
  || grep -qE 'decoration[.]blur[.]variant' "$TARGET" \
  || grep -qE '^[[:space:]]*variant[[:space:]]*=' "$TARGET"; then
  variant_state="already configured"
else
  append_variant_block
  variant_state="appended"
  changed=1
fi

if grep -qF "$WOBBLE_MARK" "$TARGET" 2>/dev/null \
  || grep -qE 'wobble[[:space:]]*=[[:space:]]*\{' "$TARGET"; then
  wobble_state="already configured"
else
  append_wobble_block
  wobble_state="appended"
  changed=1
fi

if [ "$changed" -eq 1 ]; then
  patch_log "UserConfigs/user_decorations.lua: blur variants ${variant_state}, wobble ${wobble_state}"
  patch_log "  change the variant name in the appended block to pick one; kawase is the default"
else
  patch_log "UserConfigs/user_decorations.lua already configures blur variants and wobble; nothing to do"
fi

exit 0
