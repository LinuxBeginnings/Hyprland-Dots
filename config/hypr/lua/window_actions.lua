-- ==================================================
--  KoolDots (2026)
--  Project URL: https://github.com/LinuxBeginnings
--  License: GNU GPLv3
--  SPDX-License-Identifier: GPL-3.0-or-later
-- ==================================================

-- In-process window actions that previously lived in bash/Lua helper scripts
-- under ~/.config/hypr/scripts. Everything here runs inside Hyprland's own Lua
-- VM, so a keybind costs zero process forks and zero hyprctl IPC round trips.
--
-- Replaces:
--   scripts/float.all.samesize.lua     -> M.same_size_floating()
--   scripts/ScrollCycleColumnWidth.sh  -> M.cycle_column_width()
--
-- See docs/LuaScriptsMigrationPlan.md for the rules these follow. In short:
--   * never call hyprctl from here, the hl.* API is already in-process
--   * pass HL.Window objects to dispatchers, never "address:0x..." strings
--   * HL.Window.size is { x = w, y = h }; size[1] does not exist
--   * HL.Monitor.reserved is { top, left, bottom, right }; it is not an array

local M = {}

local SAME_SIZE_GAP = 16
local MIN_USABLE_W, MIN_USABLE_H = 320, 240
local NOTIFY_TIMEOUT_MS = 2000

local COLUMN_WIDTH_PRESETS = { 0.25, 0.33, 0.5, 0.66, 0.75, 1.0 }

-- ---------------------------------------------------------------------------
-- small helpers
-- ---------------------------------------------------------------------------

local function as_number(value)
  if type(value) == "number" then
    return value
  end
  if type(value) == "string" then
    return tonumber(value)
  end
  return nil
end

-- Single-quote a value for safe interpolation into a shell command.
local function shquote(value)
  return "'" .. tostring(value):gsub("'", "'\\''") .. "'"
end

local function notify(title, body)
  if not (hl and hl.exec_cmd) then
    return
  end
  hl.exec_cmd(
    string.format(
      "notify-send -e -u low -t %d %s %s >/dev/null 2>&1",
      NOTIFY_TIMEOUT_MS,
      shquote(title),
      shquote(body)
    )
  )
end

local function dispatch(dispatcher)
  if not (hl and hl.dispatch and dispatcher) then
    return
  end
  local ok, err = pcall(hl.dispatch, dispatcher)
  if not ok then
    print("[WARN] window_actions: dispatch failed: " .. tostring(err))
  end
end

local function window_size(win)
  local size = win and win.size
  if type(size) ~= "table" then
    return nil, nil
  end
  return as_number(size.x or size[1] or size.width or size.w),
    as_number(size.y or size[2] or size.height or size.h)
end

-- ---------------------------------------------------------------------------
-- Float every window on the active workspace to a uniform size
-- ---------------------------------------------------------------------------

local function same_size_positions(usable_x, usable_y, usable_w, usable_h, count)
  local gap = SAME_SIZE_GAP
  local positions = {}

  if count == 1 then
    local target_w = math.floor(math.min(usable_w - gap * 2, math.max(480, usable_w * 0.72)))
    local target_h = math.floor(math.min(usable_h - gap * 2, math.max(320, usable_h * 0.72)))
    positions[1] = {
      x = usable_x + math.floor((usable_w - target_w) / 2),
      y = usable_y + math.floor((usable_h - target_h) / 2),
      w = target_w,
      h = target_h,
    }
    return positions
  end

  if count == 2 then
    local target_w = math.floor((usable_w - gap * 3) / 2)
    local target_h = math.floor(math.min(usable_h - gap * 2, math.max(320, usable_h * 0.70)))
    local start_y = usable_y + math.floor((usable_h - target_h) / 2)
    for i = 1, 2 do
      positions[i] = {
        x = usable_x + gap + (i - 1) * (target_w + gap),
        y = start_y,
        w = target_w,
        h = target_h,
      }
    end
    return positions
  end

  local cols = math.ceil(math.sqrt(count))
  local rows = math.ceil(count / cols)
  local target_w = math.max(320, math.floor((usable_w - gap * (cols + 1)) / cols))
  local target_h = math.max(220, math.floor((usable_h - gap * (rows + 1)) / rows))
  local total_grid_h = rows * target_h + (rows - 1) * gap
  local start_y = usable_y + math.max(gap, math.floor((usable_h - total_grid_h) / 2))

  local index = 0
  for row = 0, rows - 1 do
    local count_in_row = math.min(cols, count - row * cols)
    if count_in_row > 0 then
      local row_w = count_in_row * target_w + (count_in_row - 1) * gap
      local start_x = usable_x + math.max(gap, math.floor((usable_w - row_w) / 2))
      local y = start_y + row * (target_h + gap)
      for col = 0, count_in_row - 1 do
        index = index + 1
        positions[index] = {
          x = start_x + col * (target_w + gap),
          y = y,
          w = target_w,
          h = target_h,
        }
      end
    end
  end

  return positions
end

--- Float every window on the active workspace to a uniform size, laid out in a
--- balanced non-overlapping grid. Acts as a toggle: if every window on the
--- workspace is already floating, they are untiled back into the active layout.
--- Does nothing on the monocle layout.
function M.same_size_floating()
  if not (hl and hl.dsp and hl.dsp.window) then
    return
  end

  local workspace = hl.get_active_workspace and hl.get_active_workspace()
  if not workspace then
    return
  end

  local layout = workspace.tiled_layout
  if layout == nil or layout == "" then
    layout = hl.get_config and hl.get_config("general.layout")
  end
  if layout == "monocle" then
    notify("Float Windows", "Skipped: Workspace is in Monocle mode")
    return
  end

  local windows = {}
  for _, win in ipairs(hl.get_windows and hl.get_windows({ workspace = workspace.id }) or {}) do
    if not win.hidden then
      windows[#windows + 1] = win
    end
  end

  local count = #windows
  if count == 0 then
    return
  end

  local all_floating = true
  for _, win in ipairs(windows) do
    if not win.floating then
      all_floating = false
      break
    end
  end

  if all_floating then
    for _, win in ipairs(windows) do
      dispatch(hl.dsp.window.float({ window = win, action = "toggle" }))
    end
    notify("Float Windows", "Restored windows to tiled layout")
    return
  end

  local monitor = (hl.get_active_monitor and hl.get_active_monitor()) or workspace.monitor
  local mon_x, mon_y = 0, 0
  local mon_w, mon_h = 1920, 1080
  local scale = 1.0
  local res_left, res_top, res_right, res_bottom = 0, 0, 0, 0

  if monitor then
    mon_x = as_number(monitor.x) or 0
    mon_y = as_number(monitor.y) or 0
    mon_w = as_number(monitor.width) or mon_w
    mon_h = as_number(monitor.height) or mon_h
    scale = as_number(monitor.scale) or 1.0
    if scale <= 0 then
      scale = 1.0
    end

    -- Lua API shape: named fields, not reserved[1..4].
    local reserved = monitor.reserved
    if type(reserved) == "table" then
      res_left = as_number(reserved.left) or 0
      res_top = as_number(reserved.top) or 0
      res_right = as_number(reserved.right) or 0
      res_bottom = as_number(reserved.bottom) or 0
    end
  end

  local screen_w = math.floor(mon_w / scale)
  local screen_h = math.floor(mon_h / scale)
  local usable_x = mon_x + res_left
  local usable_y = mon_y + res_top
  local usable_w = math.max(MIN_USABLE_W, screen_w - (res_left + res_right))
  local usable_h = math.max(MIN_USABLE_H, screen_h - (res_top + res_bottom))

  local positions = same_size_positions(usable_x, usable_y, usable_w, usable_h, count)
  local last = positions[#positions]

  for index, win in ipairs(windows) do
    local position = positions[index] or last
    dispatch(hl.dsp.window.float({ window = win, action = "on" }))
    dispatch(hl.dsp.window.resize({ window = win, x = position.w, y = position.h }))
    dispatch(hl.dsp.window.move({ window = win, x = position.x, y = position.y }))
  end
end

-- ---------------------------------------------------------------------------
-- Cycle the scrolling layout column width through the preset list
-- ---------------------------------------------------------------------------

local function current_column_width(win, monitor)
  -- Preferred source: the scrolling layout reports the column width directly.
  local layout = win and win.layout
  if type(layout) == "table" then
    local column = layout.column
    if type(column) == "table" then
      local width = as_number(column.width)
      if width and width > 0 and width <= 1.0 then
        return width
      end
    elseif type(column) == "number" then
      if column > 0 and column <= 1.0 then
        return column
      end
    end
  end

  -- Fallback: derive the fraction from the window width over the logical
  -- monitor width.
  local win_w = window_size(win)
  if not win_w then
    return nil
  end

  local mon_w = monitor and as_number(monitor.width)
  local scale = monitor and (as_number(monitor.scale) or 1.0) or 1.0
  if not mon_w or mon_w <= 0 then
    return nil
  end
  if scale <= 0 then
    scale = 1.0
  end

  local logical_mon_w = mon_w / scale
  if logical_mon_w <= 0 then
    return nil
  end

  return win_w / logical_mon_w
end

--- Advance the active scrolling column to the next width preset. Does nothing
--- on any other layout, or when the current width cannot be determined.
function M.cycle_column_width()
  if not (hl and hl.dsp and hl.dsp.layout) then
    return
  end

  local workspace = hl.get_active_workspace and hl.get_active_workspace()
  if not workspace or workspace.tiled_layout ~= "scrolling" then
    return
  end

  local win = hl.get_active_window and hl.get_active_window()
  if not win then
    return
  end

  local width = current_column_width(win, hl.get_active_monitor and hl.get_active_monitor())
  if not width or width <= 0 then
    return
  end

  local closest, closest_diff = 1, nil
  for index, preset in ipairs(COLUMN_WIDTH_PRESETS) do
    local diff = math.abs(preset - width)
    if not closest_diff or diff < closest_diff then
      closest, closest_diff = index, diff
    end
  end

  local next_preset = COLUMN_WIDTH_PRESETS[(closest % #COLUMN_WIDTH_PRESETS) + 1]
  dispatch(hl.dsp.layout("colresize " .. tostring(next_preset)))
end

-- Exposed so system_keybinds.lua can reach it regardless of load order.
KOOLDOTS_WINDOW_ACTIONS = M

return M
