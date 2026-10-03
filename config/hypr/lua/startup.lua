-- ==================================================
--  KoolDots (2026)
--  Project URL: https://github.com/LinuxBeginnings
--  License: GNU GPLv3
--  SPDX-License-Identifier: GPL-3.0-or-later
-- ==================================================

-- Converted from:
-- - config/hypr/configs/Startup_Apps.conf
-- - config/hypr/UserConfigs/Startup_Apps.conf

local scriptsDir = "$HOME/.config/hypr/scripts"
local userScripts = "$HOME/.config/hypr/UserScripts"
local wallDir = "$HOME/Pictures/wallpapers"

-- exec_once (once-per-session marker + session readiness gate + per-command log)
-- lives in lua/user_startup_helper.lua and is shared with
-- UserConfigs/user_startup.lua, so the system and user startup lists cannot
-- drift apart again. Only the marker/log prefixes differ here, which keeps the
-- two lists separately debuggable.
local configHome = os.getenv("XDG_CONFIG_HOME") or ((os.getenv("HOME") or "") .. "/.config")
local helperPath = configHome .. "/hypr/lua/user_startup_helper.lua"
local helperOk, startupHelper = pcall(dofile, helperPath)
if not (helperOk and type(startupHelper) == "table" and startupHelper.exec_once) then
  error("system_startup: failed to load " .. helperPath .. ": " .. tostring(startupHelper))
end

local function exec_once(cmd)
  return startupHelper.exec_once(cmd, {
    marker_prefix = "/tmp/hypr-lua-exec-once-",
    log_prefix = "/tmp/hypr-lua-startup-",
  })
end

-- Prefer lifecycle-hook orchestration for clarity while keeping exec_once
-- reliability semantics for real-world startup behavior.
local startup_commands = {
  -- Fix an unresolvable Ghostty theme before the terminal is ever opened.
  scriptsDir .. "/GhosttyThemeGuard.sh",
  "sleep 1; $HOME/.config/hypr/scripts/WallpaperDaemon.sh && $HOME/.config/hypr/scripts/WaybarStartup.sh",
  "$HOME/.config/hypr/initial-boot.sh",
  "dbus-update-activation-environment --systemd WAYLAND_DISPLAY XDG_CURRENT_DESKTOP WEATHER_UNITS KITTY_CONFIG_DIRECTORY",
  "systemctl --user import-environment WAYLAND_DISPLAY XDG_CURRENT_DESKTOP WEATHER_UNITS KITTY_CONFIG_DIRECTORY",
  scriptsDir .. "/Polkit.sh",
  "nm-applet",
  -- nm-tray now optional for ubuntu
  -- "nm-tray",
  "systemctl --user start swaync.service || swaync",
  scriptsDir .. "/PortalHyprland.sh",
  'qs --log-rules "qt.qpa.wayland.textinput.warning=false" -c overview',
  'qs --log-rules "qt.qpa.wayland.textinput.warning=false" -p $HOME/.config/quickshell/qs-hyprview',
  -- Starts hypridle once (preferring the systemd user unit) and removes any
  -- stray duplicate daemons - each of which holds its own logind sleep delay
  -- inhibitor and would otherwise add to the suspend path.
  scriptsDir .. "/HypridleStartup.sh",
  -- LuaAutoReload.sh was retired: Hyprland reloads the Lua config automatically
  -- when a file is saved, so the inotify/polling watcher was a redundant process.
  scriptsDir .. "/Hyprsunset.sh init",
  -- NOTE: Dropterminal is currently certified only with kitty. Not all terminals behave correctly as a dropdown.
  scriptsDir .. "/Dropterminal.sh --startup kitty",
  -- Clipboard history: one supervised watcher handles every offered type
  -- (text, images, uri-lists) and is restarted if wl-paste dies.
  scriptsDir .. "/ClipboardWatcher.sh",
  -- Re-apply the selected Rainbow Borders mode. The wallpaper pass
  -- (WallustSwww.sh) re-applies it too, right after it rewrites
  -- general:col.active_border, so this entry only matters for a login where no
  -- wallpaper resolves and the wallpaper pass never runs.
  scriptsDir .. "/RainbowBordersStartup.sh",
}

local function run_startup_commands()
  for _, cmd in ipairs(startup_commands) do
    exec_once(cmd)
  end
end

if hl and hl.on then
  hl.on("hyprland.start", run_startup_commands)
else
  -- Compatibility fallback for older/limited runtimes without hl.on.
  run_startup_commands()
end

-- Optional startup examples retained from the original config:
-- exec_once("mpvpaper '*' -o \"load-scripts=no no-audio --loop\" \"\"")
-- exec_once(scriptsDir .. "/WallpaperAutoChange.sh " .. wallDir)
-- exec_once(userScripts .. "/RainbowBorders.sh")
