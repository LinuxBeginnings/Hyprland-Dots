-- Converted from:
-- - config/hypr/configs/Startup_Apps.conf
-- - config/hypr/UserConfigs/Startup_Apps.conf

local scriptsDir = "$HOME/.config/hypr/scripts"
local userScripts = "$HOME/.config/hypr/UserScripts"
local wallDir = "$HOME/Pictures/wallpapers"

hl.exec_once("$HOME/.config/hypr/initial-boot.sh")
hl.exec_once(scriptsDir .. "/WallpaperDaemon.sh")
hl.exec_once("dbus-update-activation-environment --systemd WAYLAND_DISPLAY XDG_CURRENT_DESKTOP")
hl.exec_once("systemctl --user import-environment WAYLAND_DISPLAY XDG_CURRENT_DESKTOP")
hl.exec_once("$HOME/.config/hypr/scripts/Dropterminal.sh \"kitty --class kitty-dropterm\" &")
hl.exec_once(scriptsDir .. "/Polkit.sh")
hl.exec_once("nm-applet --indicator")
hl.exec_once("nm-tray")
hl.exec_once("swaync")
hl.exec_once(scriptsDir .. "/PortalHyprlandUbuntu.sh")
hl.exec_once("waybar")
hl.exec_once("qs -c overview")
hl.exec_once("hypridle")
hl.exec_once(scriptsDir .. "/Hyprsunset.sh init")
hl.exec_once("wl-paste --type text --watch cliphist store")
hl.exec_once("wl-paste --type image --watch cliphist store")

-- Optional startup examples retained from the original config:
-- hl.exec_once("mpvpaper '*' -o \"load-scripts=no no-audio --loop\" \"\"")
-- hl.exec_once(userScripts .. "/WallpaperAutoChange.sh " .. wallDir)
-- hl.exec_once(userScripts .. "/RainbowBorders.sh")
