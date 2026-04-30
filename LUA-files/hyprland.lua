-- ==================================================
--  KoolDots (2026)
--  Project URL: https://github.com/LinuxBeginnings
--  License: GNU GPLv3
--  SPDX-License-Identifier: GPL-3.0-or-later
-- ==================================================

-- Updated Lua migration entry (reference copy).
-- Working config lives in ~/.config/hypr/hyprland.lua with modules under ~/.config/hypr/lua/.
-- This file mirrors that module load order.

require("lua.keybinds")
require("lua.startup")
require("lua.env")
require("lua.laptops")
require("lua.window_rules")
require("lua.settings")
require("lua.decorations")
require("lua.animations")
require("lua.user_overrides")
require("lua.user_defaults")
require("lua.monitors")
require("lua.workspaces")
