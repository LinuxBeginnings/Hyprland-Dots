-- ==================================================
--  KoolDots (2026)
--  Project URL: https://github.com/LinuxBeginnings
--  License: GNU GPLv3
--  SPDX-License-Identifier: GPL-3.0-or-later
-- ==================================================
-- System environment variables for the Lua workflow.
-- Loaded by user_overrides.lua on every Hyprland session start.
-- Delegates to lua/env.lua which contains the canonical environment variables.

local configHome = os.getenv("XDG_CONFIG_HOME") or ((os.getenv("HOME") or "") .. "/.config")
local hyprDir = configHome .. "/hypr"
local env_path = hyprDir .. "/lua/env.lua"
local ok, err = pcall(dofile, env_path)
if not ok then
  print("[ERROR] system_env: failed to load lua/env.lua: " .. tostring(err))
end

hl.env("QT_QUICK_CONTROLS_STYLE", "Basic")
hl.env("QT_STYLE_OVERRIDE", "Fusion")
