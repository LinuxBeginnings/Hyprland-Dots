-- ==================================================
--  KoolDots (2026)
--  Project URL: https://github.com/LinuxBeginnings
--  License: GNU GPLv3
--  SPDX-License-Identifier: GPL-3.0-or-later
-- ==================================================
-- System settings for the Lua workflow.
-- Loaded by user_overrides.lua on every Hyprland session start.
-- Delegates to lua/settings.lua which contains the canonical settings.

local configHome = os.getenv("XDG_CONFIG_HOME") or ((os.getenv("HOME") or "") .. "/.config")
local hyprDir = configHome .. "/hypr"
local settings_path = hyprDir .. "/lua/settings.lua"
local ok, err = pcall(dofile, settings_path)
if not ok then
  print("[ERROR] system_settings: failed to load lua/settings.lua: " .. tostring(err))
end
