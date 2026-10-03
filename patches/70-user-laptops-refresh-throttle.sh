#!/usr/bin/env bash
# ==================================================
#  KoolDots (2026)
#  Project URL: https://github.com/LinuxBeginnings
#  License: GNU GPLv3
#  SPDX-License-Identifier: GPL-3.0-or-later
# ==================================================
# Patch: adds the layout-refresh throttle to an installed
# UserConfigs/user_laptops.lua.
#
# A single login or monitor hotplug fires monitor.added / monitor.removed
# several times in a row. Without a throttle, post_layout_refresh() spawned one
# LidSwitch.sh refresh - and therefore one Waybar start attempt - per event,
# which is how duplicate bars survived even after WaybarStartup.sh serialised
# the lifecycle.
#
# The repo's user_laptops.lua has carried this throttle since the duplicate-bar
# fix, but copy.sh only adds missing UserConfigs templates (existing files are
# protected), so installs that already shipped the file never received it.
# patches/60-user-laptops-nonblocking.sh deliberately touches only the blocking
# calls, so this is a separate patch that also reaches installs that already ran
# patch 60.

# shellcheck source=./lib.sh
. "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/lib.sh"

TARGET="$(patch_hypr_dir)/UserConfigs/user_laptops.lua"

if [ ! -f "$TARGET" ]; then
  patch_log "user_laptops.lua not installed; skipping"
  exit 0
fi

if grep -q 'hypr-lua-layout-refresh.stamp' "$TARGET" 2>/dev/null; then
  patch_log "user_laptops.lua already throttles layout refreshes; nothing to do"
  exit 0
fi

if ! grep -q '^local function post_layout_refresh()[[:space:]]*$' "$TARGET" 2>/dev/null; then
  patch_log "user_laptops.lua was customised (no post_layout_refresh); skipping"
  exit 0
fi

workdir="$(mktemp -d "${TMPDIR:-/tmp}/kooldots-patch-70.XXXXXX")" || exit 1
block="$workdir/throttle.lua"
out="$workdir/patched.lua"

# Inserted as the first statements of post_layout_refresh(), ahead of the work
# it throttles. The trailing blank line keeps the original body separated.
cat >"$block" <<'LUA'
  -- A single login or hotplug fires monitor.added/removed several times in a
  -- row. Throttle so the burst collapses into one refresh instead of spawning
  -- a refresh (and therefore a Waybar start attempt) per event.
  local runtimeDir = os.getenv("XDG_RUNTIME_DIR") or "/tmp"
  local stampPath = runtimeDir .. "/hypr-lua-layout-refresh.stamp"
  local last = tonumber(read_file(stampPath) or "") or 0
  local now = os.time()
  if now - last < 2 then
    return
  end
  local stamp = io.open(stampPath, "w")
  if stamp then
    stamp:write(tostring(now))
    stamp:close()
  end

LUA

awk -v block="$block" '
  function emit(f,   line) {
    while ((getline line < f) > 0) print line
    close(f)
  }

  inserted == 0 && $0 ~ /^local function post_layout_refresh\(\)[[:space:]]*$/ {
    print
    emit(block)
    inserted = 1
    next
  }
  { print }
' "$TARGET" >"$out" || {
  rm -rf "$workdir"
  exit 1
}

# Sanity check before writing: the throttle is in place and the function body
# still follows it. Otherwise leave the file untouched.
if ! grep -q 'hypr-lua-layout-refresh.stamp' "$out" 2>/dev/null ||
  ! grep -q 'local script = configHome .. "/hypr/scripts/LidSwitch.sh refresh"' "$out" 2>/dev/null; then
  patch_log "user_laptops.lua did not match the expected layout; left unchanged"
  rm -rf "$workdir"
  exit 1
fi

cat "$out" >"$TARGET"
rm -rf "$workdir"
patch_log "user_laptops.lua now throttles layout refreshes"
exit 0
