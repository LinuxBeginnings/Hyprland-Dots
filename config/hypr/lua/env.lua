-- ==================================================
--  KoolDots (2026)
--  Project URL: https://github.com/LinuxBeginnings
--  License: GNU GPLv3
--  SPDX-License-Identifier: GPL-3.0-or-later
-- ==================================================

-- Converted from:
-- - config/hypr/configs/ENVariables.conf
-- - config/hypr/UserConfigs/ENVariables.conf (active values only)

hl.env("DOTS_VERSION", "2.3.23")
hl.env("GDK_BACKEND", "wayland,x11,*")
hl.env("QT_QPA_PLATFORM", "wayland;xcb")
hl.env("CLUTTER_BACKEND", "wayland")
hl.env("XDG_CURRENT_DESKTOP", "Hyprland")
hl.env("XDG_SESSION_DESKTOP", "Hyprland")
hl.env("XDG_SESSION_TYPE", "wayland")
hl.env("QT_AUTO_SCREEN_SCALE_FACTOR", "1")
hl.env("QT_WAYLAND_DISABLE_WINDOWDECORATION", "1")
hl.env("QT_QPA_PLATFORMTHEME", "qt6ct")
hl.env("QT_STYLE_OVERRIDE", "kvantum")
hl.env("QT_QUICK_CONTROLS_STYLE", "org.hyprland.style")
hl.env("GDK_SCALE", "1")
hl.env("QT_SCALE_FACTOR", "1")
hl.env("MOZ_ENABLE_WAYLAND", "1")
hl.env("ELECTRON_OZONE_PLATFORM_HINT", "auto")

-- Fix for missing mime-info database error
local current_data_dirs = os.getenv("XDG_DATA_DIRS") or ""
if not current_data_dirs:find("/usr/share") then
  local new_data_dirs = "/usr/local/share:/usr/share"
  if current_data_dirs ~= "" then
    new_data_dirs = new_data_dirs .. ":" .. current_data_dirs
  end
  hl.env("XDG_DATA_DIRS", new_data_dirs)
end
