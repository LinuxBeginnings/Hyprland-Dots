-- ==================================================
--  KoolDots (2026)
--  Project URL: https://github.com/LinuxBeginnings
--  License: GNU GPLv3
--  SPDX-License-Identifier: GPL-3.0-or-later
-- ==================================================
-- User decorations overrides template.
-- Keep this repo copy as comments only; put active custom values in:
--   ~/.config/hypr/UserConfigs/user_decorations.lua
--
-- Uncomment and edit examples below if you want defaults in the repo template.

-- Example general overrides:
hl.config({
  general = {
    border_size = 1,
    gaps_in = 4,
    gaps_out = 6,
  },
})

-- Example decoration overrides:
hl.config({
  decoration = {
    rounding = 10,
    active_opacity = 1.0,
    inactive_opacity = 0.95,
    fullscreen_opacity = 1.0,
    dim_inactive = true,
    dim_strength = 0.1,
    dim_special = 0.8,
    shadow = {
      enabled = true,
      range = 2,
      render_power = 1,
      color = "rgba(8db4ffff)",
      color_inactive = "rgba(5f6578ff)",
    },
    blur = {
      enabled = true,
      size = 6,
      passes = 3,
      new_optimizations = true,
      xray = true,
      ignore_opacity = true,
      special = true,
      popups = true,
    },
  },
})

-- Example group styling:
hl.config({
  group = {
    col = {
      border_active = "rgba(ffffffff)",
    },
    groupbar = {
      col = {
        active = "rgba(0f111aff)",
      },
    },
  },
})
