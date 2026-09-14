-- ==================================================
--  KoolDots (2026)
--  Project URL: https://github.com/LinuxBeginnings
--  License: GNU GPLv3
--  SPDX-License-Identifier: GPL-3.0-or-later
-- ==================================================
-- User laptop overrides.
--
-- Keeps the laptop panel in sync with the connected displays instead of
-- relying on lid events alone:
--   * the laptop panel is disabled while an external display is connected
--   * the laptop panel is enabled again automatically when the last
--     external display is unplugged, or when the lid is opened without one
--   * external displays are placed left to right, starting at 0x0
--
-- The layout is read from the connected DRM connectors on config load and
-- re-applied on every hotplug through the monitor.added / monitor.removed
-- events, so a panel that was disabled while docked always comes back.
--
-- Tunables:
--   EXTERNAL_ORDER       preferred left-to-right order of external outputs
--   OUTPUT_SETTINGS      per-output mode/scale overrides
--   INTERNAL_MODE        laptop panel mode
--   INTERNAL_SCALE       laptop panel scale

local INTERNAL_MODE = "preferred"
local INTERNAL_SCALE = "auto"

local EXTERNAL_ORDER = { "DP-1", "HDMI-A-1" }

local OUTPUT_SETTINGS = {
  -- ["HDMI-A-1"] = { mode = "2560x1440@144", scale = 1 },
}

local DEFAULT_OUTPUT = { mode = "preferred", scale = "auto" }
local FALLBACK_INTERNAL = "eDP-1"

local EXTERNAL_INDEX = {}
for index, name in ipairs(EXTERNAL_ORDER) do
  EXTERNAL_INDEX[name] = index
end

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

local function connected_connectors()
  local connectors = {}
  local command = table.concat({
    "for status in /sys/class/drm/card*-*/status; do",
    '  [ -r "$status" ] || continue;',
    '  [ "$(cat "$status" 2>/dev/null)" = connected ] || continue;',
    "  dir=${status%/status};",
    '  echo "${dir##*/}";',
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

local lid_closed = read_command("cat /proc/acpi/button/lid/*/state 2>/dev/null"):find("closed", 1, true) ~= nil

local internal_output = FALLBACK_INTERNAL
for _, name in ipairs(connected_connectors()) do
  if is_internal(name) then
    internal_output = name
  end
end

local function output_settings(name)
  local settings = OUTPUT_SETTINGS[name] or {}
  return {
    mode = settings.mode or DEFAULT_OUTPUT.mode,
    scale = settings.scale or DEFAULT_OUTPUT.scale,
    width = settings.width,
  }
end

local function logical_width(monitor, settings)
  local width = monitor and tonumber(monitor.width) or nil
  local scale = monitor and tonumber(monitor.scale) or nil
  if not width or width <= 0 then
    width = settings.width
  end
  if not width or width <= 0 then
    return nil
  end
  if not scale or scale <= 0 then
    scale = tonumber(settings.scale) or 1
  end
  return math.floor(width / scale + 0.5)
end

local function ordered_externals(present)
  local names = {}
  for name in pairs(present) do
    if not is_internal(name) then
      names[#names + 1] = name
    end
  end
  table.sort(names, function(a, b)
    local index_a, index_b = EXTERNAL_INDEX[a], EXTERNAL_INDEX[b]
    if index_a and not index_b then
      return true
    end
    if index_b and not index_a then
      return false
    end
    if index_a and index_b then
      return index_a < index_b
    end
    return a < b
  end)
  return names
end

local function apply_monitors(present)
  for name in pairs(present) do
    if is_internal(name) then
      internal_output = name
    end
  end

  local externals = ordered_externals(present)

  if #externals > 0 then
    hl.monitor({ output = internal_output, disabled = true })

    local x = 0
    for index, name in ipairs(externals) do
      local settings = output_settings(name)
      local width = logical_width(present[name], settings)
      local position = tostring(x) .. "x0"
      if index > 1 and x == nil then
        position = "auto"
      end

      hl.monitor({
        output = name,
        disabled = false,
        mode = settings.mode,
        position = position,
        scale = settings.scale,
      })

      if x == nil or width == nil then
        x = nil
      else
        x = x + width
      end
    end
    return
  end

  hl.monitor({
    output = internal_output,
    disabled = lid_closed,
    mode = INTERNAL_MODE,
    position = "0x0",
    scale = INTERNAL_SCALE,
  })
end

local function apply_layout(overrides)
  local present = {}
  for _, monitor in ipairs(hl.get_monitors()) do
    present[monitor.name] = monitor
  end
  for name, monitor in pairs(overrides or {}) do
    present[name] = monitor ~= false and monitor or nil
  end
  apply_monitors(present)
end

-- Bootstrap: at load time the outputs are not attached yet, so read the
-- connected connectors from sysfs and apply the matching layout.
do
  local present = {}
  for _, name in ipairs(connected_connectors()) do
    if not is_internal(name) then
      present[name] = { name = name }
    end
  end
  apply_monitors(present)
end

if hl.on then
  hl.on("hyprland.start", function()
    apply_layout()
  end)

  hl.on("monitor.added", function(monitor)
    if monitor and monitor.name then
      apply_layout({ [monitor.name] = monitor })
    else
      apply_layout()
    end
  end)

  hl.on("monitor.removed", function(monitor)
    if monitor and monitor.name then
      apply_layout({ [monitor.name] = false })
    else
      apply_layout()
    end
  end)
end

hl.bind("switch:on:Lid Switch", function()
  lid_closed = true
  apply_layout()
end)

hl.bind("switch:off:Lid Switch", function()
  lid_closed = false
  apply_layout()
end)
