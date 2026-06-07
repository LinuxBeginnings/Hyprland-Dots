-- ==================================================
--  KoolDots (2026)
--  Project URL: https://github.com/LinuxBeginnings
--  License: GNU GPLv3
--  SPDX-License-Identifier: GPL-3.0-or-later
-- ==================================================

-- KoolDots Hyprland Lua config entrypoint.
-- Mirrors hyprland.conf include order for features currently supported by Lua config.
local configHome = os.getenv("XDG_CONFIG_HOME") or (os.getenv("HOME") .. "/.config")
local hyprDir = configHome .. "/hypr"

local function load_module(name)
  dofile(hyprDir .. "/lua/" .. name .. ".lua")
end

-- In Lua workflow, runtime config is loaded from split files under:
--   ~/.config/hypr/configs/system_*.lua
--   ~/.config/hypr/UserConfigs/user_*.lua
-- via lua/user_overrides.lua. Base lua/*.lua modules are templates and should
-- not also be loaded directly here, or bindings/settings can be duplicated.
load_module("user_defaults")
load_module("user_overrides")
load_module("monitors")
load_module("workspaces")
