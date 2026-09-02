-- ==================================================
--  KoolDots (2026)
--  Project URL: https://github.com/LinuxBeginnings
--  License: GNU GPLv3
--  SPDX-License-Identifier: GPL-3.0-or-later
-- ==================================================
-- User startup overrides template.
-- Add personal exec-once commands here.
--
-- =============================================================================
-- USER STARTUP RULES & SYNTAX
-- =============================================================================
-- In KoolDots Lua configuration, user autostart commands are defined in this file.
--
-- How it works:
-- 1. Add command strings to the `startup_commands` table below (or call `exec_once("command")`).
-- 2. `exec_once` ensures commands run once per Hyprland session and prevents re-execution on config reload.
-- 3. Startup logs for each command are written to /tmp/hypr-lua-user-startup-<cmd>.log for easy debugging.
--
-- =============================================================================
-- EXAMPLES OF COMMON STARTUP APPS & DAEMONS
-- =============================================================================
--
-- 1. TRAY APPLET & SYSTEM UTILITIES:
--    "blueman-applet",                -- Bluetooth manager tray applet
--    "nm-applet --indicator",         -- NetworkManager tray icon
--    "pasystray",                     -- PulseAudio / PipeWire volume tray applet
--    "udiskie --tray",                -- Auto-mount removable media with tray icon
--    "cbatticon",                     -- Battery icon for laptops
--
-- 2. BACKGROUND APPS / MESSENGERS / DAEMONS:
--    "kdeconnect-app",                -- KDE Connect (or "kdeconnect-indicator")
--    "flatpak run com.discordapp.Discord --start-minimized",
--    "flatpak run org.telegram.desktop -startintray",
--    "spotify --minimized",
--    "1password --silent",
--    "copyq --start-server",
--
-- 3. CLOUD SYNC & BACKUP:
--    "nextcloud --background",
--    "insync start",
--    "megasync",
--
-- 4. CUSTOM SCRIPTS & WALLPAPER ENHANCEMENTS:
--    "$HOME/.config/hypr/UserScripts/RainbowBorders.sh",
--    "$HOME/.config/hypr/UserScripts/WallpaperAutoChange.sh $HOME/Pictures/wallpapers",
--    "sleep 3; notify-send 'Welcome' 'Hyprland session started successfully!'",
--
-- 5. IDLE / NIGHT LIGHT / RGB:
--    "wlsunset -l 37.77 -l -122.41 -t 4000 -T 6500", -- Custom color temperature
--    "openrgb --startminimized --profile 'MyProfile'",
--
-- =============================================================================

local user_startup_helper = nil
do
  local source = (debug.getinfo(1, "S") or {}).source or ""
  local source_path = source:match("^@(.+)$")
  local source_dir = source_path and source_path:match("^(.*)/[^/]+$") or nil
  local home = os.getenv("HOME") or ""
  local candidate_paths = {
    source_dir and (source_dir .. "/../lua/user_startup_helper.lua") or nil,
    home ~= "" and (home .. "/.config/hypr/lua/user_startup_helper.lua") or nil,
    home ~= "" and (home .. "/.config/hypr/user_startup_helper.lua") or nil,
  }

  local tried_paths = {}
  for _, helper_path in ipairs(candidate_paths) do
    if helper_path then
      table.insert(tried_paths, helper_path)
      local f = io.open(helper_path, "r")
      if f then
        f:close()
        local loaded_ok, loaded_helpers = pcall(dofile, helper_path)
        if loaded_ok and type(loaded_helpers) == "table" and loaded_helpers.exec_once then
          user_startup_helper = loaded_helpers
          break
        end
      end
    end
  end

  if not user_startup_helper then
    error("Failed to load user_startup_helper.lua from: " .. table.concat(tried_paths, ", "))
  end
end

local exec_once = user_startup_helper.exec_once

-- Add custom startup commands:
local startup_commands = {
  -- "kdeconnect-app",
  -- "blueman-applet",
  -- "$HOME/.config/hypr/UserScripts/RainbowBorders.sh",
}

local function run_startup_commands()
  for _, cmd in ipairs(startup_commands) do
    exec_once(cmd)
  end
end

if hl and hl.on then
  hl.on("hyprland.start", run_startup_commands)
else
  run_startup_commands()
end
