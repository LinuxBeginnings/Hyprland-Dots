-- ==================================================
--  KoolDots (2026)
--  Project URL: https://github.com/LinuxBeginnings
--  License: GNU GPLv3
--  SPDX-License-Identifier: GPL-3.0-or-later
-- ==================================================
-- System window rules for the Lua workflow.
-- Loaded by user_overrides.lua on every Hyprland session start.
-- Delegates to lua/window_rules.lua which contains the canonical window rules.

local configHome = os.getenv("XDG_CONFIG_HOME") or ((os.getenv("HOME") or "") .. "/.config")
local hyprDir = configHome .. "/hypr"
local window_rules_path = hyprDir .. "/lua/window_rules.lua"
local ok, err = pcall(dofile, window_rules_path)
if not ok then
  print("[ERROR] system_window_rules: failed to load lua/window_rules.lua: " .. tostring(err))
end
