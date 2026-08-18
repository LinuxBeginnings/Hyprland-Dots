-- ==================================================
--  KoolDots (2026)
--  Project URL: https://github.com/LinuxBeginnings
--  License: GNU GPLv3
--  SPDX-License-Identifier: GPL-3.0-or-later
-- ==================================================
-- System laptop rules for the Lua workflow.
-- Loaded by user_overrides.lua on every Hyprland session start.
-- Delegates to lua/laptops.lua which contains the canonical laptop rules.

local configHome = os.getenv("XDG_CONFIG_HOME") or ((os.getenv("HOME") or "") .. "/.config")
local hyprDir = configHome .. "/hypr"
local laptops_path = hyprDir .. "/lua/laptops.lua"
local ok, err = pcall(dofile, laptops_path)
if not ok then
  print("[ERROR] system_laptops: failed to load lua/laptops.lua: " .. tostring(err))
end
