#!/usr/bin/env lua
-- ==================================================
--  KoolDots (2026)
--  Project URL: https://github.com/LinuxBeginnings
--  License: GNU GPLv3
--  SPDX-License-Identifier: GPL-3.0-or-later
-- ==================================================
-- Float all windows in the active workspace to uniform dimensions
-- dynamically computed from monitor resolution, reserved bar margins,
-- and the number of active windows.
-- Acts as a toggle: if every window on the workspace is already floating
-- (e.g. from a previous run of this script), it untiles them back into
-- the active tiled layout instead.
-- Exits safely if monocle layout is active.

-- Lightweight embedded JSON decoder to guarantee standalone execution
-- without requiring external C libraries (e.g. cjson)
local function parse_json(str)
  if not str or str:match("^%s*$") then return nil end
  local pos = 1
  local function skip_ws()
    pos = str:find("%S", pos) or (#str + 1)
  end
  local parse_val
  local function parse_str()
    local res = {}
    pos = pos + 1
    while pos <= #str do
      local c = str:sub(pos, pos)
      if c == '"' then
        pos = pos + 1
        return table.concat(res)
      elseif c == '\\' then
        pos = pos + 1
        local esc = str:sub(pos, pos)
        if esc == '"' or esc == '\\' or esc == '/' then
          table.insert(res, esc)
        elseif esc == 'b' then table.insert(res, '\b')
        elseif esc == 'f' then table.insert(res, '\f')
        elseif esc == 'n' then table.insert(res, '\n')
        elseif esc == 'r' then table.insert(res, '\r')
        elseif esc == 't' then table.insert(res, '\t')
        elseif esc == 'u' then
          local hex = str:sub(pos + 1, pos + 4)
          pos = pos + 4
          local code = tonumber(hex, 16)
          if code and code < 128 then
            table.insert(res, string.char(code))
          else
            table.insert(res, '?')
          end
        end
        pos = pos + 1
      else
        local s = str:find('["\\]', pos) or (#str + 1)
        table.insert(res, str:sub(pos, s - 1))
        pos = s
      end
    end
    error("unterminated JSON string")
  end
  local function parse_num()
    local s, e = str:find("^-?%d+%.?%d*[eE]?[+-]?%d*", pos)
    if not s then error("invalid JSON number at position " .. pos) end
    pos = e + 1
    return tonumber(str:sub(s, e))
  end
  local function parse_arr()
    local arr = {}
    pos = pos + 1
    skip_ws()
    if str:sub(pos, pos) == "]" then pos = pos + 1 return arr end
    while pos <= #str do
      table.insert(arr, parse_val())
      skip_ws()
      local c = str:sub(pos, pos)
      if c == "]" then pos = pos + 1 return arr
      elseif c == "," then pos = pos + 1 skip_ws()
      else error("expected ',' or ']' at position " .. pos) end
    end
  end
  local function parse_obj()
    local obj = {}
    pos = pos + 1
    skip_ws()
    if str:sub(pos, pos) == "}" then pos = pos + 1 return obj end
    while pos <= #str do
      skip_ws()
      if str:sub(pos, pos) ~= '"' then error("expected JSON key at position " .. pos) end
      local k = parse_str()
      skip_ws()
      if str:sub(pos, pos) ~= ":" then error("expected ':' at position " .. pos) end
      pos = pos + 1
      skip_ws()
      obj[k] = parse_val()
      skip_ws()
      local c = str:sub(pos, pos)
      if c == "}" then pos = pos + 1 return obj
      elseif c == "," then pos = pos + 1 skip_ws()
      else error("expected ',' or '}' at position " .. pos) end
    end
  end
  parse_val = function()
    skip_ws()
    local c = str:sub(pos, pos)
    if c == '"' then return parse_str()
    elseif c == "{" then return parse_obj()
    elseif c == "[" then return parse_arr()
    elseif c == "t" and str:sub(pos, pos + 3) == "true" then pos = pos + 4 return true
    elseif c == "f" and str:sub(pos, pos + 4) == "false" then pos = pos + 5 return false
    elseif c == "n" and str:sub(pos, pos + 3) == "null" then pos = pos + 4 return nil
    elseif c and c:find("[%-%d]") then return parse_num()
    else error("unexpected character '" .. tostring(c) .. "' at position " .. pos) end
  end

  local ok, res = pcall(parse_val)
  return ok and res or nil
end

-- Helper to run commands and capture JSON output
local function exec_json(cmd)
  local handle = io.popen(cmd)
  if not handle then return nil end
  local result = handle:read("*a")
  handle:close()
  if not result or result == "" then return nil end

  -- Try fast native/library decoders first, fallback to pure Lua parser
  if _G.vim and vim.fn and vim.fn.json_decode then
    local ok, json = pcall(vim.fn.json_decode, result)
    if ok then return json end
  end

  local ok_cjson, cjson = pcall(require, "cjson")
  if ok_cjson and cjson and cjson.decode then
    local ok, json = pcall(cjson.decode, result)
    if ok then return json end
  end

  local ok_luna, lunajson = pcall(require, "lunajson")
  if ok_luna and lunajson and lunajson.decode then
    local ok, json = pcall(lunajson.decode, result)
    if ok then return json end
  end

  return parse_json(result)
end

-- 1. Fetch active workspace, monitor details, and clients
local active_ws = exec_json("hyprctl -j activeworkspace")
if not active_ws or not active_ws.id then
  os.exit(1)
end

-- 2. Check for Monocle layout
-- Floating all windows is counterproductive in Monocle mode (designed for full focus / single window visibility)
local layout = active_ws.tiledLayout or active_ws.tiled_layout or active_ws.layout
if not layout or layout == "" then
  local general_opt = exec_json("hyprctl -j getoption general:layout")
  if general_opt and general_opt.str then
    layout = general_opt.str
  end
end

if layout == "monocle" then
  io.stderr:write("Monocle layout is active on workspace " .. tostring(active_ws.id) .. " - skipping float all windows.\n")
  os.execute("notify-send -e -u low -t 2000 'Float Windows' 'Skipped: Workspace is in Monocle mode' >/dev/null 2>&1")
  os.exit(0)
end

local clients = exec_json("hyprctl -j clients") or {}
local monitors = exec_json("hyprctl -j monitors") or {}

-- 3. Filter clients on the active workspace
local ws_clients = {}
for _, client in ipairs(clients) do
  if client.workspace and client.workspace.id == active_ws.id and not client.hidden then
    table.insert(ws_clients, client)
  end
end

local window_count = #ws_clients
if window_count == 0 then
  os.exit(0)
end

-- Helper to detect Hyprland config mode (Lua entrypoint vs legacy .conf includes)
local function get_hypr_config_mode()
  local config_home = os.getenv("XDG_CONFIG_HOME")
  if not config_home or config_home == "" then
    config_home = (os.getenv("HOME") or "") .. "/.config"
  end
  local hypr_dir = config_home .. "/hypr"
  local lua_entry = hypr_dir .. "/hyprland.lua"
  local legacy_lua_entry = config_home .. "/hyprland.lua"

  local f = io.open(lua_entry, "r")
  if f then
    f:close()
    return "lua"
  end
  f = io.open(legacy_lua_entry, "r")
  if f then
    f:close()
    return "lua"
  end
  return "conf"
end

local mode = get_hypr_config_mode()

-- 3b. Toggle: if every window on the workspace is already floating (i.e. this
-- script was already run), untile them back into the active layout instead
-- of re-floating/resizing them.
local all_floating = true
for _, client in ipairs(ws_clients) do
  if not client.floating then
    all_floating = false
    break
  end
end

if all_floating then
  local untile_commands = {}
  for _, client in ipairs(ws_clients) do
    local address = "address:" .. client.address
    if mode == "lua" then
      table.insert(
        untile_commands,
        string.format('dispatch hl.dsp.window.float({ window = "%s", action = "toggle" })', address)
      )
    else
      -- Vanilla Hyprland has no dedicated "untile" dispatcher; togglefloating
      -- is safe here since every window in this set is confirmed floating.
      table.insert(untile_commands, string.format("dispatch togglefloating %s", address))
    end
  end

  if #untile_commands > 0 then
    local full_cmd = string.format("hyprctl --batch '%s'", table.concat(untile_commands, " ; "))
    os.execute(full_cmd)
    os.execute("notify-send -e -u low -t 2000 'Float Windows' 'Restored windows to tiled layout' >/dev/null 2>&1")
  end
  os.exit(0)
end

-- 4. Determine monitor dimensions and usable area (accounting for scaling and reserved bar margins)
local active_monitor = nil
for _, m in ipairs(monitors) do
  if (active_ws.monitor and m.name == active_ws.monitor) or
     (active_ws.monitorID and m.id == active_ws.monitorID) or
     m.focused == true then
    active_monitor = m
    break
  end
end

local mon_x = 0
local mon_y = 0
local mon_width = 1920
local mon_height = 1080
local scale = 1.0
local res_left, res_top, res_right, res_bottom = 0, 0, 0, 0

if active_monitor then
  mon_x = active_monitor.x or 0
  mon_y = active_monitor.y or 0
  mon_width = active_monitor.width or mon_width
  mon_height = active_monitor.height or mon_height
  scale = active_monitor.scale or 1.0
  if scale <= 0 then scale = 1.0 end

  if active_monitor.reserved and type(active_monitor.reserved) == "table" then
    res_left = active_monitor.reserved[1] or 0
    res_top = active_monitor.reserved[2] or 0
    res_right = active_monitor.reserved[3] or 0
    res_bottom = active_monitor.reserved[4] or 0
  end
end

local screen_w = math.floor(mon_width / scale)
local screen_h = math.floor(mon_height / scale)
local usable_x = mon_x + res_left
local usable_y = mon_y + res_top
local usable_w = math.max(320, screen_w - (res_left + res_right))
local usable_h = math.max(240, screen_h - (res_top + res_bottom))

-- 5. Calculate dynamic uniform window size and balanced non-overlapping layout positions
local gap = 16
local positions = {}

if window_count == 1 then
  local target_w = math.floor(math.min(usable_w - gap * 2, math.max(480, usable_w * 0.72)))
  local target_h = math.floor(math.min(usable_h - gap * 2, math.max(320, usable_h * 0.72)))
  local x = usable_x + math.floor((usable_w - target_w) / 2)
  local y = usable_y + math.floor((usable_h - target_h) / 2)
  table.insert(positions, { x = x, y = y, w = target_w, h = target_h })
elseif window_count == 2 then
  local target_w = math.floor((usable_w - gap * 3) / 2)
  local target_h = math.floor(math.min(usable_h - gap * 2, math.max(320, usable_h * 0.70)))
  local start_y = usable_y + math.floor((usable_h - target_h) / 2)
  for i = 1, 2 do
    local x = usable_x + gap + (i - 1) * (target_w + gap)
    table.insert(positions, { x = x, y = start_y, w = target_w, h = target_h })
  end
else
  local cols = math.ceil(math.sqrt(window_count))
  local rows = math.ceil(window_count / cols)

  local raw_w = math.floor((usable_w - gap * (cols + 1)) / cols)
  local raw_h = math.floor((usable_h - gap * (rows + 1)) / rows)

  local target_w = math.max(320, raw_w)
  local target_h = math.max(220, raw_h)

  local total_grid_h = rows * target_h + (rows - 1) * gap
  local start_y = usable_y + math.max(gap, math.floor((usable_h - total_grid_h) / 2))

  for r = 0, rows - 1 do
    local count_in_row = math.min(cols, window_count - r * cols)
    if count_in_row > 0 then
      local row_w = count_in_row * target_w + (count_in_row - 1) * gap
      local start_x = usable_x + math.max(gap, math.floor((usable_w - row_w) / 2))
      local y = start_y + r * (target_h + gap)

      for c = 0, count_in_row - 1 do
        local x = start_x + c * (target_w + gap)
        table.insert(positions, { x = x, y = y, w = target_w, h = target_h })
      end
    end
  end
end

-- 6. Build and execute atomic Hyprland batch command
local batch_commands = {}

for idx, client in ipairs(ws_clients) do
  local pos = positions[idx] or positions[#positions]
  local address = "address:" .. client.address

  if mode == "lua" then
    -- In Lua mode, use native Hyprland Lua dispatcher syntax with double quotes for Lua strings
    table.insert(batch_commands, string.format('dispatch hl.dsp.window.float({ window = "%s", action = "on" })', address))
    table.insert(
      batch_commands,
      string.format('dispatch hl.dsp.window.resize({ window = "%s", x = %d, y = %d, exact = true })', address, pos.w, pos.h)
    )
    table.insert(
      batch_commands,
      string.format('dispatch hl.dsp.window.move({ window = "%s", x = %d, y = %d, exact = true })', address, pos.x, pos.y)
    )
  else
    -- Legacy Hyprlang mode
    table.insert(batch_commands, string.format("dispatch setfloating %s", address))
    table.insert(
      batch_commands,
      string.format("dispatch resizewindowpixel exact %d %d,%s", pos.w, pos.h, address)
    )
    table.insert(
      batch_commands,
      string.format("dispatch movewindowpixel exact %d %d,%s", pos.x, pos.y, address)
    )
  end
end

if #batch_commands > 0 then
  local full_cmd = string.format("hyprctl --batch '%s'", table.concat(batch_commands, " ; "))
  os.execute(full_cmd)
end
