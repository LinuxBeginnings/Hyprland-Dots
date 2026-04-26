-- KoolDots Hyprland Lua config entrypoint.
-- Mirrors hyprland.conf include order for features currently supported by Lua config.
local configHome = os.getenv("XDG_CONFIG_HOME") or (os.getenv("HOME") .. "/.config")
local hyprDir = configHome .. "/hypr"

local function load_module(name)
  dofile(hyprDir .. "/lua/" .. name .. ".lua")
end

load_module("keybinds")
load_module("startup")
load_module("env")
load_module("laptops")
load_module("window_rules")
load_module("settings")
load_module("decorations")
load_module("animations")
load_module("user_overrides")
load_module("user_defaults")
load_module("monitors")
load_module("workspaces")
