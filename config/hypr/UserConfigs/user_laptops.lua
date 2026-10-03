-- ==================================================
--  KoolDots (2026)
--  Project URL: https://github.com/LinuxBeginnings
--  License: GNU GPLv3
--  SPDX-License-Identifier: GPL-3.0-or-later
-- ==================================================
-- User laptop overrides.
--
-- Dynamically manages internal laptop panel and external monitors:
-- * Auto-detects internal panel (eDP, LVDS, DSI) and all connected external displays.
-- * Respects ~/.config/hypr/UserConfigs/monitors.lua as the primary source of truth for
--   monitor modes, positions, and scales, then falls back to explicit per-output rules
--   from ~/.config/hypr/lua/monitors.lua. Wildcard rules in the system file are ignored
--   here because Hyprland already applies them as its own fallback chain.
-- * Docked/Clamshell mode: disables the internal panel when the lid is closed AND
--   at least one external display is connected.
-- * Automatically restores the internal panel when external displays are disconnected,
--   or when the lid is opened.
-- * Listens to hotplug events (monitor.added, monitor.removed) and lid switch events.

local FALLBACK_INTERNAL = "eDP-1"

local function read_file(path)
  local f = io.open(path, "r")
  if not f then
    return nil
  end
  local content = f:read("*a")
  f:close()
  return content
end

-- Lid state lives in a handful of fixed sysfs paths, so they can be read
-- directly. The old fallback ran `cat /proc/acpi/button/lid/*/state` through
-- io.popen, which blocks the compositor's Lua VM for the whole fork.
local LID_STATE_PATHS = {
  "/proc/acpi/button/lid/LID/state",
  "/proc/acpi/button/lid/LID0/state",
  "/proc/acpi/button/lid/LID1/state",
}

local function is_internal(name)
  return name ~= nil
    and (name:match("^eDP") ~= nil or name:match("^LVDS") ~= nil or name:match("^DSI") ~= nil)
end

local function is_lid_closed()
  for _, path in ipairs(LID_STATE_PATHS) do
    local content = read_file(path)
    if content then
      return content:find("closed", 1, true) ~= nil
    end
  end
  return false
end

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

-- Collect active monitor names from Hyprland and DRM
local function get_connected_monitors()
  local monitors = {}
  local seen = {}

  -- 1. Read from DRM sysfs (sees connected hardware immediately)
  for _, name in ipairs(connected_drm_connectors()) do
    if not seen[name] then
      seen[name] = true
      table.insert(monitors, name)
    end
  end

  -- 2. Read from active Hyprland monitors
  if hl and hl.get_monitors then
    local hl_mons = hl.get_monitors() or {}
    for _, mon in ipairs(hl_mons) do
      local name = mon.name
      if name and not seen[name] then
        seen[name] = true
        table.insert(monitors, name)
      end
    end
  end

  return monitors
end

-- Detect the internal panel name dynamically
local function detect_internal_monitor(connected)
  for _, name in ipairs(connected) do
    if is_internal(name) then
      return name
    end
  end
  return FALLBACK_INTERNAL
end

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

local function post_layout_refresh()
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

  local configHome = os.getenv("XDG_CONFIG_HOME") or ((os.getenv("HOME") or "") .. "/.config")
  local script = configHome .. "/hypr/scripts/LidSwitch.sh refresh"
  if hl and hl.exec_cmd then
    hl.exec_cmd(script)
  else
    os.execute(script .. " >/dev/null 2>&1 &")
  end
end

-- Apply appropriate monitor layout based on connected displays, user configs, and lid state
local function apply_laptop_monitor_layout(trigger_refresh)
  local connected = get_connected_monitors()
  local internal = detect_internal_monitor(connected)
  local lid_closed = is_lid_closed()

  local externals = {}
  for _, name in ipairs(connected) do
    if not is_internal(name) then
      table.insert(externals, name)
    end
  end

  local monitor_configs = load_monitor_configs()
  -- Wildcards are intentionally taken from the user file only: the system file's
  -- wildcard rules are Hyprland's own fallback chain, not per-output defaults.
  local user_configs = monitor_configs.user
  local get_monitor_config = monitor_configs.get
  local default_fallback = user_configs[""] or user_configs["*"] or { mode = "preferred", position = "auto", scale = "auto" }

  if #externals > 0 then
    -- External display(s) connected
    if lid_closed then
      -- Clamshell / Docked mode: lid is closed, disable internal panel
      hl.monitor({ output = internal, disabled = true })
    else
      -- Lid is open: apply internal display configuration from monitors.lua
      local int_cfg = get_monitor_config(internal)
      if int_cfg then
        hl.monitor(int_cfg)
      else
        hl.monitor({
          output = internal,
          disabled = false,
          mode = default_fallback.mode or "preferred",
          position = default_fallback.position or "auto",
          scale = default_fallback.scale or "auto",
        })
      end
    end

    -- Apply configurations for external displays from monitors.lua
    for _, ext_name in ipairs(externals) do
      local cfg = get_monitor_config(ext_name)
      if cfg then
        hl.monitor(cfg)
      else
        -- Fallback if not explicitly defined in monitors.lua
        hl.monitor({
          output = ext_name,
          disabled = false,
          mode = default_fallback.mode or "preferred",
          position = default_fallback.position or "auto",
          scale = default_fallback.scale or "auto",
        })
      end
    end
  else
    -- No external displays connected: internal panel must be enabled (unless lid is closed)
    local int_cfg = get_monitor_config(internal)
    if lid_closed then
      hl.monitor({ output = internal, disabled = true })
    elseif int_cfg then
      hl.monitor(int_cfg)
    else
      hl.monitor({
        output = internal,
        disabled = false,
        mode = default_fallback.mode or "preferred",
        position = "0x0",
        scale = default_fallback.scale or "auto",
      })
    end
  end

  if trigger_refresh then
    post_layout_refresh()
  end
end

-- Export for direct CLI / eval access
_G.apply_laptop_monitor_layout = apply_laptop_monitor_layout

-- Initial apply at config load time
apply_laptop_monitor_layout(false)

-- Event hooks for dynamic hotplugging
if hl and hl.on then
  hl.on("hyprland.start", function()
    apply_laptop_monitor_layout(false)
  end)

  hl.on("monitor.added", function()
    apply_laptop_monitor_layout(true)
  end)

  hl.on("monitor.removed", function()
    apply_laptop_monitor_layout(true)
  end)
end

-- Lid switch triggers
hl.bind("switch:on:Lid Switch", function()
  apply_laptop_monitor_layout(true)
end)

hl.bind("switch:off:Lid Switch", function()
  apply_laptop_monitor_layout(true)
end)
