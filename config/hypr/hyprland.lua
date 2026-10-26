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
-- keybind_index must load before user_overrides, which loads every keybind file:
-- it records binds by hooking hl.bind, so it can only see the ones registered
-- after it. See lua/keybind_index.lua.
load_module("keybind_index")
load_module("animations")
-- window_actions must load before user_overrides so configs/system_keybinds.lua
-- can reach the in-process window actions through KOOLDOTS_WINDOW_ACTIONS.
load_module("window_actions")
load_module("user_overrides")
load_module("monitors")
load_module("workspaces")

-- Every keybind file has been loaded by now, so render the list the rofi menu
-- reads. KeyBinds.sh re-renders through `hyprctl eval` before it runs, so a
-- failure here costs the bootstrap file, not the menu.
local keybind_index = rawget(_G, "KOOLDOTS_KEYBIND_INDEX")
if keybind_index and keybind_index.write_cache then
  pcall(keybind_index.write_cache, keybind_index)
end
