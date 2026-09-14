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
-- * Respects ~/.config/hypr/UserConfigs/monitors.lua as the single source of truth for
--   monitor modes, positions, and scales (no duplicate configuration needed).
-- * Docked/Clamshell mode: disables the internal panel when the lid is closed AND
--   at least one external display is connected.
-- * Automatically restores the internal panel when external displays are disconnected,
--   or when the lid is opened.
-- * Listens to hotplug events (monitor.added, monitor.removed) and lid switch events.

local FALLBACK_INTERNAL = "eDP-1"

local function read_command(command)
  local pipe = io.popen(command, "r")
  if not pipe then
    return ""
  end
  local output = pipe:read("*a") or ""
  pipe:close()
  return output
end

local function is_internal(name)
  return name ~= nil
    and (name:match("^eDP") ~= nil or name:match("^LVDS") ~= nil or name:match("^DSI") ~= nil)
end

local function is_lid_closed()
  local state = read_command("cat /proc/acpi/button/lid/*/state 2>/dev/null")
  return state:find("closed", 1, true) ~= nil
end

-- Gather all physically connected DRM connectors from sysfs
local function connected_drm_connectors()
  local connectors = {}
  local command = table.concat({
    "for status in /sys/class/drm/card*-*/status; do",
    ' [ -r "$status" ] || continue;',
    ' [ "$(cat "$status" 2>/dev/null)" = connected ] || continue;',
    " dir=${status%/status};",
    ' echo "${dir##*/}";',
    "done",
  }, " ")
  for line in read_command(command):gmatch("%S+") do
    local name = line:match("^card%d+%-(.+)$")
    if name then
      connectors[#connectors + 1] = name
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

-- Read user monitor rules from UserConfigs/monitors.lua
local function load_user_monitor_configs()
  local configHome = os.getenv("XDG_CONFIG_HOME") or ((os.getenv("HOME") or "") .. "/.config")
  local userMonitorsPath = configHome .. "/hypr/UserConfigs/monitors.lua"

  local handle = io.open(userMonitorsPath, "r")
  if not handle then
    local source = (debug.getinfo(1, "S") or {}).source or ""
    local source_dir = source:match("^@?(.*)/[^/]+$")
    if source_dir and io.open(source_dir .. "/monitors.lua", "r") then
      userMonitorsPath = source_dir .. "/monitors.lua"
      handle = io.open(userMonitorsPath, "r")
    end
  end

  if not handle then
    return {}
  end
  handle:close()

  local configs = {}
  local orig_monitor = hl and hl.monitor
  if hl then
    hl.monitor = function(cfg)
      if type(cfg) == "table" and cfg.output then
        configs[cfg.output] = cfg
      end
    end
  end

  pcall(dofile, userMonitorsPath)

  if hl then
    hl.monitor = orig_monitor
  end

  return configs
end

local function post_layout_refresh()
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

  local user_configs = load_user_monitor_configs()
  local default_fallback = user_configs[""] or user_configs["*"] or { mode = "preferred", position = "auto", scale = "auto" }

  if #externals > 0 then
    -- External display(s) connected
    if lid_closed then
      -- Clamshell / Docked mode: lid is closed, disable internal panel
      hl.monitor({ output = internal, disabled = true })
    else
      -- Lid is open: apply internal display configuration from monitors.lua
      local int_cfg = user_configs[internal]
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
      local cfg = user_configs[ext_name]
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
    local int_cfg = user_configs[internal]
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
