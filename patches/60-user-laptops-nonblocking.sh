#!/usr/bin/env bash
# ==================================================
#  KoolDots (2026)
#  Project URL: https://github.com/LinuxBeginnings
#  License: GNU GPLv3
#  SPDX-License-Identifier: GPL-3.0-or-later
# ==================================================
# Patch: removes the blocking io.popen calls from an installed
# UserConfigs/user_laptops.lua.
#
# io.popen and os.execute run on the compositor's own thread and wait for the
# child to finish, so the whole session freezes for the duration. This file had
# two of them, on a path that runs at config load and on hyprland.start:
#
#   * read_command() piped `cat /proc/acpi/button/lid/*/state` to read the lid
#     state, after two direct io.open attempts had already missed.
#   * connected_drm_connectors() ran one `io.popen("ls /sys/class/drm/...")` per
#     DRM card, up to five of them per call.
#
# They are replaced by a fixed list of lid sysfs paths and by probing a known
# list of DRM connector names with io.open, which is a plain file read. Every
# monitor Hyprland itself reports is still added by get_connected_monitors().
#
# copy.sh only adds missing UserConfigs templates (existing files are
# protected), so an install that already shipped user_laptops.lua would keep the
# blocking calls forever. This patch rewrites only the three affected blocks,
# leaves the rest of the file intact, and is content-idempotent.

# shellcheck source=./lib.sh
. "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/lib.sh"

TARGET="$(patch_hypr_dir)/UserConfigs/user_laptops.lua"

if [ ! -f "$TARGET" ]; then
  patch_log "user_laptops.lua not installed; skipping"
  exit 0
fi

if grep -q 'LID_STATE_PATHS' "$TARGET" 2>/dev/null; then
  patch_log "user_laptops.lua already avoids io.popen; nothing to do"
  exit 0
fi

# Only touch the shape this patch was written against. Anything else is a
# customised file and is left alone.
if ! grep -q '^local function read_command(command)[[:space:]]*$' "$TARGET" 2>/dev/null ||
  ! grep -q '^local function is_lid_closed()[[:space:]]*$' "$TARGET" 2>/dev/null ||
  ! grep -q '^local function connected_drm_connectors()[[:space:]]*$' "$TARGET" 2>/dev/null ||
  ! grep -qE '^[^/-]*io\.popen' "$TARGET" 2>/dev/null; then
  patch_log "user_laptops.lua was customised (unexpected shape); skipping"
  exit 0
fi

workdir="$(mktemp -d "${TMPDIR:-/tmp}/kooldots-patch-60.XXXXXX")" || exit 1
block_lid_paths="$workdir/lid-paths.lua"
block_lid_closed="$workdir/lid-closed.lua"
block_drm="$workdir/drm.lua"
out="$workdir/patched.lua"

# Replaces read_command(), which existed only to serve the lid fallback.
cat >"$block_lid_paths" <<'LUA'
-- Lid state lives in a handful of fixed sysfs paths, so they can be read
-- directly. The old fallback ran `cat /proc/acpi/button/lid/*/state` through
-- io.popen, which blocks the compositor's Lua VM for the whole fork.
local LID_STATE_PATHS = {
  "/proc/acpi/button/lid/LID/state",
  "/proc/acpi/button/lid/LID0/state",
  "/proc/acpi/button/lid/LID1/state",
}
LUA

# Replaces is_lid_closed(), minus the io.popen fallback.
cat >"$block_lid_closed" <<'LUA'
local function is_lid_closed()
  for _, path in ipairs(LID_STATE_PATHS) do
    local content = read_file(path)
    if content then
      return content:find("closed", 1, true) ~= nil
    end
  end
  return false
end
LUA

# Replaces connected_drm_connectors() and adds the name list it probes.
cat >"$block_drm" <<'LUA'
-- Connector names Linux DRM uses, in reporting order.
--
-- Enumerating sysfs with `ls` needed one blocking io.popen fork per card. The
-- known names are probed with io.open instead, which is a plain file read, and
-- get_connected_monitors() still adds every monitor Hyprland itself reports.
local DRM_CONNECTOR_NAMES = {
  "eDP-1", "eDP-2",
  "LVDS-1", "LVDS-2",
  "DSI-1", "DSI-2",
  "DP-1", "DP-2", "DP-3", "DP-4",
  "DP-1-1", "DP-2-1", "DP-3-1",
  "HDMI-A-1", "HDMI-A-2", "HDMI-A-3",
  "HDMI-B-1",
  "DVI-D-1", "DVI-I-1",
  "VGA-1",
  "Virtual-1", "Virtual-2",
}

-- Gather all physically connected DRM connectors from sysfs
local function connected_drm_connectors()
  local connectors = {}

  for card = 0, 4 do
    for _, name in ipairs(DRM_CONNECTOR_NAMES) do
      local status = read_file("/sys/class/drm/card" .. card .. "-" .. name .. "/status")
      if status and status:match("^connected") then
        connectors[#connectors + 1] = name
      end
    end
  end

  return connectors
end
LUA

# Replace each top-level function by name, skipping to its closing `end` at
# column 0. The stale comment above connected_drm_connectors() is dropped too,
# since the replacement block carries its own.
awk -v b_paths="$block_lid_paths" -v b_lid="$block_lid_closed" -v b_drm="$block_drm" '
  function emit(f,   line) {
    while ((getline line < f) > 0) print line
    close(f)
  }

  $0 == "-- Gather all physically connected DRM connectors from sysfs" { next }

  state == 0 && $0 ~ /^local function read_command\(command\)[[:space:]]*$/ {
    emit(b_paths); state = 1; next
  }
  state == 0 && $0 ~ /^local function is_lid_closed\(\)[[:space:]]*$/ {
    emit(b_lid); state = 1; next
  }
  state == 0 && $0 ~ /^local function connected_drm_connectors\(\)[[:space:]]*$/ {
    emit(b_drm); state = 1; next
  }
  state == 1 {
    if ($0 ~ /^end[[:space:]]*$/) state = 0
    next
  }
  { print }
' "$TARGET" >"$out" || {
  rm -rf "$workdir"
  exit 1
}

# Sanity check before writing: every blocking call gone, every replacement in
# place. Otherwise leave the file untouched.
#
# The call patterns are matched with `^[^/-]*` so that the explanatory comments
# this patch itself writes (which do mention io.popen) are not mistaken for a
# surviving call.
if grep -qE '^[^/-]*(io\.popen|read_command)' "$out" 2>/dev/null ||
  ! grep -q 'LID_STATE_PATHS' "$out" 2>/dev/null ||
  ! grep -q 'DRM_CONNECTOR_NAMES' "$out" 2>/dev/null ||
  ! grep -q '^local function connected_drm_connectors()' "$out" 2>/dev/null; then
  patch_log "user_laptops.lua did not match the expected layout; left unchanged"
  rm -rf "$workdir"
  exit 1
fi

cat "$out" >"$TARGET"
rm -rf "$workdir"
patch_log "user_laptops.lua no longer blocks the compositor with io.popen"
exit 0
