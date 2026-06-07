-- ==================================================
--  KoolDots (2026)
--  Project URL: https://github.com/LinuxBeginnings
--  License: GNU GPLv3
--  SPDX-License-Identifier: GPL-3.0-or-later
-- ==================================================

-- User decorations overrides (auto-generated).
-- This file is intentionally split from other user overrides.
-- Add only user-specific Lua overrides here.
-- Example:
-- hl.config({ general = { gaps_in = 4, gaps_out = 8 } })

-- Source reference from UserDecorations.conf (hyprlang):
-- source = $HOME/.config/hypr/wallust/wallust-hyprland.conf
-- general {
-- border_size = 2
-- gaps_in = 2
-- gaps_out = 4
-- col.active_border = $color12
-- col.inactive_border = $color10
-- }
-- decoration {
-- rounding = 10
-- active_opacity = 1.0
-- inactive_opacity = 0.9
-- fullscreen_opacity = 1.0
-- dim_inactive = true
-- dim_strength = 0.1
-- dim_special = 0.8
-- shadow {
-- enabled = true
-- range = 3
-- render_power = 1
-- color =  $color12
-- color_inactive = $color10
-- }
-- blur {
-- enabled = true
-- size = 6
-- passes = 3
-- new_optimizations = true
-- xray = true
-- ignore_opacity = true
-- special = true
-- popups = true
-- }
-- }
-- group {
-- col.border_active = $color15
-- groupbar {
-- col.active = $color0
-- }
-- }

local function read_wallust_colors(path)
  local colors = {}
  local handle = io.open(path, "r")
  if not handle then
    return colors
  end
  for line in handle:lines() do
    local key, hex = line:match("^%$([%w_]+)%s*=%s*rgb%(([0-9A-Fa-f]+)%)")
    if key and hex then
      colors[key] = "rgb(" .. hex .. ")"
    end
  end
  handle:close()
  return colors
end

local wallust_path = (os.getenv("HOME") or "") .. "/.config/hypr/wallust/wallust-hyprland.conf"
local colors = read_wallust_colors(wallust_path)

if next(colors) then
  hl.config({
    general = {
      col = {
        active_border = colors.color12 or "rgba(8db4ffff)",
        inactive_border = colors.color10 or "rgba(5f6578ff)",
      },
    },
  })

  hl.config({
    decoration = {
      shadow = {
        color = colors.color12 or "rgba(8db4ffff)",
        color_inactive = colors.color10 or "rgba(5f6578ff)",
      },
    },
  })

  hl.config({
    group = {
      col = {
        border_active = colors.color15 or "rgba(ffffffff)",
      },
      groupbar = {
        col = {
          active = colors.color0 or "rgba(0f111aff)",
        },
      },
    },
  })
end
