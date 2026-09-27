#!/usr/bin/env bash
# ==================================================
#  KoolDots (2026)
#  Project URL: https://github.com/LinuxBeginnings
#  License: GNU GPLv3
#  SPDX-License-Identifier: GPL-3.0-or-later
# ==================================================
# Patch: makes an installed UserConfigs/user_laptops.lua honour explicit
# per-output monitor rules from the system file (hypr/lua/monitors.lua).
#
# Before this fix user_laptops.lua applied a synthetic "preferred" fallback to
# every connected display that was not listed in UserConfigs/monitors.lua. That
# pass runs at config load and again on hyprland.start / monitor.added /
# monitor.removed, so it always ran last and silently replaced explicit rules
# such as
#   hl.monitor({ output = "Virtual-1", mode = "1920x1080@60", ... })
# with the monitor's native "preferred" mode.
#
# copy.sh only adds missing UserConfigs templates (existing files are
# protected), so an install that already shipped user_laptops.lua would keep
# the old logic forever. This patch replaces just the rule-loading function and
# its call sites, leaves the rest of the file intact, and is content-idempotent.

# shellcheck source=./lib.sh
. "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/lib.sh"

TARGET="$(patch_hypr_dir)/UserConfigs/user_laptops.lua"

if [ ! -f "$TARGET" ]; then
  patch_log "user_laptops.lua not installed; skipping"
  exit 0
fi

if grep -q 'capture_monitor_configs' "$TARGET" 2>/dev/null; then
  patch_log "user_laptops.lua already honours system per-output monitor rules; nothing to do"
  exit 0
fi

if ! grep -qE '^local function load_user_monitor_configs\(\)[[:space:]]*$' "$TARGET" 2>/dev/null; then
  patch_log "user_laptops.lua was customised (no load_user_monitor_configs); skipping"
  exit 0
fi

workdir="$(mktemp -d "${TMPDIR:-/tmp}/kooldots-patch-50.XXXXXX")" || exit 1
backup="$workdir/original.lua"
block="$workdir/rules.lua"
headerblock="$workdir/header.lua"
callerblock="$workdir/caller.lua"
out1="$workdir/pass1.lua"
out2="$workdir/pass2.lua"
cp -f "$TARGET" "$backup"

# Replacement text for the old rule-loading function.
cat >"$block" <<'LUA'
-- Read hl.monitor() rules from a Lua config file without applying them.
local function capture_monitor_configs(path)
  local configs = {}

  local handle = io.open(path, "r")
  if not handle then
    return configs
  end
  handle:close()

  local orig_monitor = hl and hl.monitor
  if hl then
    hl.monitor = function(cfg)
      if type(cfg) == "table" and cfg.output then
        configs[cfg.output] = cfg
      end
    end
  end

  pcall(dofile, path)

  if hl then
    hl.monitor = orig_monitor
  end

  return configs
end

-- Path to the user-editable monitor overrides, with the legacy co-located
-- monitors.lua next to this file as a fallback.
local function user_monitors_path()
  local configHome = os.getenv("XDG_CONFIG_HOME") or ((os.getenv("HOME") or "") .. "/.config")
  local path = configHome .. "/hypr/UserConfigs/monitors.lua"
  if io.open(path, "r") then
    return path
  end

  local source = (debug.getinfo(1, "S") or {}).source or ""
  local source_dir = source:match("^@?(.*)/[^/]+$")
  if source_dir and io.open(source_dir .. "/monitors.lua", "r") then
    return source_dir .. "/monitors.lua"
  end

  return path
end

-- Monitor rules are resolved from the user overrides first, then from explicit
-- per-output rules in the system file (hypr/lua/monitors.lua). Without the system
-- lookup, a specific rule such as "Virtual-1 = 1920x1080@60" would be silently
-- replaced by the generic fallback below on every hotplug/login event.
local function load_monitor_configs()
  local configHome = os.getenv("XDG_CONFIG_HOME") or ((os.getenv("HOME") or "") .. "/.config")
  local hyprDir = configHome .. "/hypr"

  local system_configs = capture_monitor_configs(hyprDir .. "/lua/monitors.lua")
  local user_configs = capture_monitor_configs(user_monitors_path())

  return {
    user = user_configs,
    get = function(name)
      return user_configs[name] or system_configs[name]
    end,
  }
end
LUA

# Replacement text for the two-line header note.
cat >"$headerblock" <<'LUA'
-- * Respects ~/.config/hypr/UserConfigs/monitors.lua as the primary source of truth for
--   monitor modes, positions, and scales, then falls back to explicit per-output rules
--   from ~/.config/hypr/lua/monitors.lua. Wildcard rules in the system file are ignored
--   here because Hyprland already applies them as its own fallback chain.
LUA

# Replacement text for the old load_user_monitor_configs() caller.
cat >"$callerblock" <<'LUA'
  local monitor_configs = load_monitor_configs()
  -- Wildcards are intentionally taken from the user file only: the system file's
  -- wildcard rules are Hyprland's own fallback chain, not per-output defaults.
  local user_configs = monitor_configs.user
  local get_monitor_config = monitor_configs.get
LUA

# Pass 1: drop the now-stale comment and replace the old rule-loading function
# (top-level, closes at column 0).
awk -v new="$block" '
  $0 == "-- Read user monitor rules from UserConfigs/monitors.lua" { next }
  state == 0 && $0 ~ /^local function load_user_monitor_configs\(\)[[:space:]]*$/ {
    while ((getline line < new) > 0) print line
    close(new)
    state = 1
    next
  }
  state == 1 {
    if ($0 ~ /^end[[:space:]]*$/) state = 0
    next
  }
  { print }
' "$TARGET" >"$out1" || {
  rm -rf "$workdir"
  exit 1
}

# Pass 2: update the header note, the caller, and the per-output lookups.
awk -v header="$headerblock" -v caller="$callerblock" '
  skip == 1 {
    skip = 0
    if ($0 ~ /^--   monitor modes, positions, and scales \(no duplicate configuration needed\)\.$/) next
  }
  $0 ~ /^-- \* Respects ~\/\.config\/hypr\/UserConfigs\/monitors\.lua as the single source of truth for$/ {
    while ((getline line < header) > 0) print line
    close(header)
    skip = 1
    next
  }
  $0 ~ /^[[:space:]]*local user_configs = load_user_monitor_configs\(\)[[:space:]]*$/ {
    while ((getline line < caller) > 0) print line
    close(caller)
    next
  }
  {
    line = $0
    gsub(/user_configs\[internal\]/, "get_monitor_config(internal)", line)
    gsub(/user_configs\[ext_name\]/, "get_monitor_config(ext_name)", line)
    print line
  }
' "$out1" >"$out2" || {
  rm -rf "$workdir"
  exit 1
}
cat "$out2" >"$TARGET"

# Sanity check: the new helpers must be present, the old caller gone, and all
# three per-output lookups rewritten. Otherwise restore and report.
lookups="$(grep -c 'get_monitor_config(' "$TARGET" 2>/dev/null || true)"
if grep -q 'load_user_monitor_configs' "$TARGET" 2>/dev/null ||
  ! grep -q 'capture_monitor_configs' "$TARGET" 2>/dev/null ||
  [ "${lookups:-0}" -lt 3 ]; then
  cat "$backup" >"$TARGET"
  patch_log "user_laptops.lua did not match the expected layout; left unchanged"
  rm -rf "$workdir"
  exit 1
fi

rm -rf "$workdir"
patch_log "user_laptops.lua now reads explicit per-output rules from hypr/lua/monitors.lua"
exit 0
