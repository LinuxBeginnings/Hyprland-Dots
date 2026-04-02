-- Hyprland Lua entry (migration scaffold)
-- Keep this under LUA-files/ until upstream Lua config stabilizes.
-- Mirrors config/hypr/hyprland.conf include order.

-- NOTE: Update package.path or move these modules when integrating into ~/.config/hypr/.

require("lua.env")
require("lua.startup")
require("lua.user_defaults")
require("lua.laptops")
require("lua.window_rules")
require("lua.settings")
require("lua.decorations")
require("lua.animations")
require("lua.keybinds")
require("lua.user_overrides")
require("lua.monitors")
require("lua.workspaces")
