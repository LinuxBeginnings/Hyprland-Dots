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

-- Config options ship with the compositor, not with the dots. Blur variants and
-- wobble arrived in Hyprland 0.57 while 0.56 is still supported, and writing an
-- option the running build does not have is a config error on every reload.
-- hl.get_config answers nil for such an option, so it decides. No version string
-- to parse, and a distro backport or a later release needs no edit.
local has_option = (ok and helper and helper.has_config_option) or function()
  return false
end

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

-- Blur variants (Hyprland 0.57+).
-- `variant` swaps the default kawase blur for one of: kawase, frost, ripple,
-- drops, water, fluid_jar, prism, heat_shimmer, acrylic, aurora, haze.
-- frost and prism read the glass table. Animated variants cost GPU time.
--
-- Only the keys you set are applied, so uncomment the block of the variant you
-- picked. The values shown are Hyprland's defaults; uncommenting one changes
-- nothing until you edit it.
if has_option("decoration.blur.variant") then
  hl.config({
    decoration = {
      blur = {
        variant = "kawase",
        -- glass        = { refraction = 20.0, size = 40.0, roughness = 1.0 },
        -- acrylic      = { refraction = 24.0, aberration = 0.025, bulb = 48.0,
        --                  clarity = 0.82, tint = "0x14EEF5FF" },
        -- aurora       = { color1 = "0x29F0A0FF", color2 = "0x7A4DFFFF",
        --                  intensity = 0.35, speed = 1.0 },
        -- drops        = { speed = 3.0 },
        -- fluid_jar    = { color = "0xCC3399FF", distortion = 8.0,
        --                  fill_amount = 0.5, mass = 1.4, precision = 2.0,
        --                  speed = 3.7, turbulence = 1.2 },
        -- haze         = { intensity = 0.35, iridescence = 0.7 },
        -- heat_shimmer = { speed = 1.0 },
        -- ripple       = { duration = 0.45, radius = 400.0, strength = 30.0,
        --                  width = 32.0 },
        -- water        = { damping = 0.95, duration = 12.0, radius = 20.0,
        --                  speed = 0.76, strength = 32.0 },
        -- proportional = false, -- 0.57
      },
    },
  })
end

-- Window wobble (Hyprland 0.57+).
-- Gated like the blur variants above: 0.56 has no decoration:wobble:* keys.
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
if has_option("decoration.wobble.enabled") then
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
end

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
