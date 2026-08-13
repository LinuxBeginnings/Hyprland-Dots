-- ==================================================
--  KoolDots (2026)
--  Project URL: https://github.com/LinuxBeginnings
--  License: GNU GPLv3
--  SPDX-License-Identifier: GPL-3.0-or-later
-- ========================================

local function sync_workspaces(delta, move_window)
  local active_ws = hl.get_active_workspace()
  if not active_ws then
    return
  end

  -- 1. Get all connected monitors and sort left-to-right by X position
  local monitors = hl.get_monitors()
  if #monitors == 0 then
    return
  end
  table.sort(monitors, function(a, b)
    return a.x < b.x
  end)

  local num_monitors = #monitors

  -- 2. Determine current Virtual Desktop block (e.g. WS 1 or 2 with 2 monitors -> VD 1)
  local current_vd = math.ceil(active_ws.id / num_monitors)
  local target_vd = current_vd + delta
  if target_vd < 1 then
    target_vd = 1
  end

  local active_mon = hl.get_active_monitor()

  -- 3. If moving active window, send it to the target workspace on the current monitor
  if move_window and active_mon then
    for i, m in ipairs(monitors) do
      if m.id == active_mon.id then
        local target_ws = (target_vd - 1) * num_monitors + i
        hl.dispatch(hl.dsp.window.move({ workspace = target_ws }))
        break
      end
    end
  end

  -- 4. Switch all monitors to their respective workspace in the target VD block
  for i, m in ipairs(monitors) do
    local target_ws = (target_vd - 1) * num_monitors + i
    hl.dispatch(hl.dsp.focus({ monitor = m.name }))
    hl.dispatch(hl.dsp.focus({ workspace = target_ws }))
  end

  -- 5. Preserve focused monitor focus state
  if active_mon then
    hl.dispatch(hl.dsp.focus({ monitor = active_mon.name }))
  end
end

-- Keybindings
-- SUPER + Up / Down: Switch entire monitor pair up/down
-- SUPER + SHIFT + Up / Down: Move focused window along with the pair switch
hl.bind(mainMod .. " + up", function()
  sync_workspaces(-1, false)
end)
hl.bind(mainMod .. " + down", function()
  sync_workspaces(1, false)
end)
hl.bind(mainMod .. " + SHIFT + up", function()
  sync_workspaces(-1, true)
end)
hl.bind(mainMod .. " + SHIFT + down", function()
  sync_workspaces(1, true)
end)
