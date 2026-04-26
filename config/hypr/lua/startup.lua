-- Converted from:
-- - config/hypr/configs/Startup_Apps.conf
-- - config/hypr/UserConfigs/Startup_Apps.conf

local scriptsDir = "$HOME/.config/hypr/scripts"
local userScripts = "$HOME/.config/hypr/UserScripts"
local wallDir = "$HOME/Pictures/wallpapers"
local function exec_once(cmd)
  if hl.exec_once then
    hl.exec_once(cmd)
  else
    hl.exec_cmd(cmd)
  end
end

exec_once("$HOME/.config/hypr/initial-boot.sh")
exec_once(scriptsDir .. "/WallpaperDaemon.sh")
exec_once("dbus-update-activation-environment --systemd WAYLAND_DISPLAY XDG_CURRENT_DESKTOP")
exec_once("systemctl --user import-environment WAYLAND_DISPLAY XDG_CURRENT_DESKTOP")
exec_once("$HOME/.config/hypr/scripts/Dropterminal.sh \"kitty --class kitty-dropterm\" &")
exec_once(scriptsDir .. "/Polkit.sh")
exec_once("nm-applet --indicator")
exec_once("nm-tray")
exec_once("swaync")
exec_once(scriptsDir .. "/PortalHyprlandUbuntu.sh")
exec_once("waybar")
exec_once("qs -c overview")
exec_once("hypridle")
exec_once(scriptsDir .. "/Hyprsunset.sh init")
exec_once("wl-paste --type text --watch cliphist store")
exec_once("wl-paste --type image --watch cliphist store")

-- Optional startup examples retained from the original config:
-- exec_once("mpvpaper '*' -o \"load-scripts=no no-audio --loop\" \"\"")
-- exec_once(userScripts .. "/WallpaperAutoChange.sh " .. wallDir)
-- exec_once(userScripts .. "/RainbowBorders.sh")
