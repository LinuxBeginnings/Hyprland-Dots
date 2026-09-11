-- ==================================================
--  KoolDots (2026)
--  Project URL: https://github.com/LinuxBeginnings
--  License: GNU GPLv3
--  SPDX-License-Identifier: GPL-3.0-or-later
-- ==================================================

-- Converted from:
-- - config/hypr/configs/ENVariables.conf
-- - config/hypr/UserConfigs/ENVariables.conf (active values only)

hl.env("DOTS_VERSION", "2.3.6.27")
hl.env("GDK_BACKEND", "wayland,x11,*")
hl.env("QT_QPA_PLATFORM", "wayland;xcb")
hl.env("CLUTTER_BACKEND", "wayland")
hl.env("XDG_CURRENT_DESKTOP", "Hyprland")
hl.env("XDG_SESSION_DESKTOP", "Hyprland")
hl.env("XDG_SESSION_TYPE", "wayland")
hl.env("QT_AUTO_SCREEN_SCALE_FACTOR", "1")
hl.env("QT_WAYLAND_DISABLE_WINDOWDECORATION", "1")
hl.env("QT_QPA_PLATFORMTHEME", "qt6ct")
hl.env("QT_STYLE_OVERRIDE", "Fusion")
hl.env("QT_QUICK_CONTROLS_STYLE", "Basic")
hl.env("GDK_SCALE", "1")
hl.env("QT_SCALE_FACTOR", "1")
hl.env("MOZ_ENABLE_WAYLAND", "1")
hl.env("ELECTRON_OZONE_PLATFORM_HINT", "auto")

-- Cursor theme defaults
hl.env("HYPRCURSOR_THEME", "Bibata-Modern-Ice")
hl.env("HYPRCURSOR_SIZE", "24")
hl.env("XCURSOR_THEME", "Bibata-Modern-Ice")
hl.env("XCURSOR_SIZE", "24")

-- NVIDIA specific environment variables (enabled by detector when Nvidia GPU present)
hl.env("LIBVA_DRIVER_NAME", "nvidia")
hl.env("__GLX_VENDOR_LIBRARY_NAME", "nvidia")
hl.env("NVD_BACKEND", "direct")
hl.env("GSK_RENDERER", "ngl")

-- VM / Software rendering fallback (enabled by detector in VM)
-- hl.env("WLR_RENDERER_ALLOW_SOFTWARE", "1")

-- Fix for missing mime-info database error
local current_data_dirs = os.getenv("XDG_DATA_DIRS") or ""
if not current_data_dirs:find("/usr/share") then
  local new_data_dirs = "/usr/local/share:/usr/share"
  if current_data_dirs ~= "" then
    new_data_dirs = new_data_dirs .. ":" .. current_data_dirs
  end
  hl.env("XDG_DATA_DIRS", new_data_dirs)
end
