-- ==================================================
--  KoolDots (2026)
--  Project URL: https://github.com/LinuxBeginnings
--  License: GNU GPLv3
--  SPDX-License-Identifier: GPL-3.0-or-later
-- ==================================================
-- System startup commands for the Lua workflow.
-- Loaded by user_overrides.lua on every Hyprland session start.
-- Delegates to lua/startup.lua which contains the canonical startup command list.

local configHome = os.getenv("XDG_CONFIG_HOME") or ((os.getenv("HOME") or "") .. "/.config")
local hyprDir = configHome .. "/hypr"
local startup_path = hyprDir .. "/lua/startup.lua"
local ok, err = pcall(dofile, startup_path)
if not ok then
  print("[ERROR] system_startup: failed to load lua/startup.lua: " .. tostring(err))
end
