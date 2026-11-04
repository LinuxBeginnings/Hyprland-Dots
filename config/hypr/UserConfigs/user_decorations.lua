-- ==================================================
--  KoolDots (2026)
--  Project URL: https://github.com/LinuxBeginnings
--  License: GNU GPLv3
--  SPDX-License-Identifier: GPL-3.0-or-later
-- ==================================================
-- User decorations overrides.
-- Dynamically loads Wallust generated colors from wallust-hyprland.conf.

local home = os.getenv("HOME") or ""
local helper_path = home .. "/.config/hypr/lua/user_decorations_helper.lua"
local ok, helper = pcall(dofile, helper_path)
local wallust = (ok and helper and helper.load_wallust_colors)
  and helper.load_wallust_colors(home .. "/.config/hypr/wallust/wallust-hyprland.conf")
  or {}

local active_col = wallust.color12 or "rgba(8db4ffff)"
local inactive_col = wallust.color10 or "rgba(5f6578ff)"

hl.config({
  general = {
    border_size = 1,
    gaps_in = 4,
    gaps_out = 6,
    col = {
      active_border = active_col,
      inactive_border = inactive_col,
    },
  },
})

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
      color = active_col,
      color_inactive = inactive_col,
    },
    blur = {
      enabled = true,
      size = 6,
      passes = 3,
      new_optimizations = true,
      xray = false,
      ignore_opacity = true,
      special = true,
      popups = true,
    },
  },
})

-- Window wobble (Hyprland 0.57+).
-- Wobble is a window transformer, not an animation style: it is driven by
-- decoration:wobble:* and Hyprland ships it disabled by default.
--
-- This table is the only place wobble is configured. scripts/ToggleWobble.sh
-- flips the "enabled" value below and reports it back for the quick settings
-- menu. Both locate this table by its keys and brace depth, not by line number,
-- indentation or line length, so the layout below can be reformatted freely.
-- Adding or renaming the keys it reads is the only thing that would break it.
--
-- Physics: upstream defaults are mesh 12, stiffness 200, damping 12, mass 1,
-- intensity 0.2, value_epsilon 0.25, velocity_epsilon 2. These are stiffer, so
-- the window settles instead of swinging. Damping ratio ~0.52, still underdamped
-- so it does wobble. Raise damping to settle faster, lower stiffness to float more.
--
-- Inspect live state with: hyprctl getoption decoration:wobble:enabled
hl.config({
  decoration = {
    wobble = {
      enabled = true,
      mesh = 12,
      stiffness = 240,
      damping = 16,
      mass = 1,
      intensity = 0.25,
      value_epsilon = 0.25,
      velocity_epsilon = 2,
    },
  },
})

hl.config({
  group = {
    col = {
      border_active = wallust.color15 or active_col,
    },
    groupbar = {
      col = {
        active = wallust.color0 or "rgba(0f111aff)",
      },
    },
  },
})
