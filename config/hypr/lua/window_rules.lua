-- ==================================================
--  KoolDots (2026)
--  Project URL: https://github.com/LinuxBeginnings
--  License: GNU GPLv3
--  SPDX-License-Identifier: GPL-3.0-or-later
-- ==================================================

-- Auto-generated from config/hypr/configs/WindowRules.conf for Lua testing.
-- Edit the source WindowRules.conf and regenerate this file when vendor rules change.

local function apply_window_rule(rule)
  if hl.window_rule then
    hl.window_rule(rule)
  end
end


apply_window_rule({
  name = "tag-browser-firefox",
  match = {
    class = "^([Ff]irefox|org.mozilla.firefox|[Ff]irefox-esr|[Ff]irefox-bin)$",
  },
  tag = "+browser",
})

apply_window_rule({
  name = "tag-browser-google-chrome",
  match = {
    class = "^([Gg]oogle-chrome(-beta|-dev|-unstable)?)$",
  },
  tag = "+browser",
})

apply_window_rule({
  name = "tag-browser-chrome-default-profile",
  match = {
    class = "^(chrome-.+-Default)$",
  },
  tag = "+browser",
})

apply_window_rule({
  name = "tag-browser-chromium",
  match = {
    class = "^([Cc]hromium)$",
  },
  tag = "+browser",
})

apply_window_rule({
  name = "tag-browser-microsoft-edge",
  match = {
    class = "^([Mm]icrosoft-edge(-stable|-beta|-dev|-unstable))$",
  },
  tag = "+browser",
})

apply_window_rule({
  name = "tag-browser-brave",
  match = {
    class = "^([Bb]rave-browser(-beta|-dev|-unstable)?)$",
  },
  tag = "+browser",
})

apply_window_rule({
  name = "tag-browser-thorium-cachy",
  match = {
    class = "^([Tt]horium-browser|[Cc]achy-browser)$",
  },
  tag = "+browser",
})

apply_window_rule({
  name = "tag-browser-zen",
  match = {
    class = "^(zen-alpha|zen)$",
  },
  tag = "+browser",
})

apply_window_rule({
  name = "tag-notifications-swaync",
  match = {
    class = "^(swaync-control-center|swaync-notification-window|swaync-client|class)$",
  },
  tag = "+notif",
})

apply_window_rule({
  name = "tag-kool-cheat-sheet",
  match = {
    title = "^(KooL Quick Cheat Sheet)$",
  },
  tag = "+KooL_Cheat",
})

apply_window_rule({
  name = "tag-kool-hyprland-settings",
  match = {
    title = "^(KooL Hyprland Settings)$",
  },
  tag = "+KooL_Settings",
})

apply_window_rule({
  name = "tag-kool-settings-nwg-tools",
  match = {
    class = "^(nwg-displays|nwg-look)$",
  },
  tag = "+KooL-Settings",
})

apply_window_rule({
  name = "tag-terminal-emulators",
  match = {
    class = "^(ghostty|wezterm|Alacritty|kitty|kitty-dropterm)$",
  },
  tag = "+terminal",
})

apply_window_rule({
  name = "tag-email-thunderbird",
  match = {
    class = "^([Tt]hunderbird|org.mozilla.Thunderbird)$",
  },
  tag = "+email",
})

apply_window_rule({
  name = "tag-email-betterbird",
  match = {
    class = "^(eu.betterbird.Betterbird)$",
  },
  tag = "+email",
})

apply_window_rule({
  name = "tag-email-evolution",
  match = {
    class = "^(org.gnome.Evolution)$",
  },
  tag = "+email",
})

apply_window_rule({
  name = "tag-projects-vscodium",
  match = {
    class = "^(codium|codium-url-handler|VSCodium)$",
  },
  tag = "+projects",
})

apply_window_rule({
  name = "tag-projects-vscode",
  match = {
    class = "^(VSCode|code|code-url-handler)$",
  },
  tag = "+projects",
})

apply_window_rule({
  name = "tag-projects-jetbrains",
  match = {
    class = "^(jetbrains-.+)$",
  },
  tag = "+projects",
})

apply_window_rule({
  name = "tag-projects-zed",
  match = {
    class = "^(dev.zed.Zed|antigravity)$",
  },
  tag = "+projects",
})

apply_window_rule({
  name = "tag-screenshare-obs",
  match = {
    class = "^(com.obsproject.Studio)$",
  },
  tag = "+screenshare",
})

apply_window_rule({
  name = "tag-im-discord-family",
  match = {
    class = "^([Dd]iscord|[Ww]ebCord|[Vv]esktop)$",
  },
  tag = "+im",
})

apply_window_rule({
  name = "tag-im-ferdium",
  match = {
    class = "^([Ff]erdium)$",
  },
  tag = "+im",
})

apply_window_rule({
  name = "tag-im-whatsapp",
  match = {
    class = "^([Ww]hatsapp-for-linux|ZapZap|com.rtosta.zapzap)$",
  },
  tag = "+im",
})

apply_window_rule({
  name = "tag-im-telegram",
  match = {
    class = "^(org.telegram.desktop|io.github.tdesktop_x64.TDesktop)$",
  },
  tag = "+im",
})

apply_window_rule({
  name = "tag-im-teams",
  match = {
    class = "^(teams-for-linux)$",
  },
  tag = "+im",
})

apply_window_rule({
  name = "tag-im-element",
  match = {
    class = "^(im.riot.Riot|Element)$",
  },
  tag = "+im",
})

apply_window_rule({
  name = "tag-games-gamescope",
  match = {
    class = "^(gamescope)$",
  },
  tag = "+games",
})

apply_window_rule({
  name = "tag-games-steam-app",
  match = {
    class = "^(steam_app_\\\\d+)$",
  },
  tag = "+games",
})

apply_window_rule({
  name = "tag-games-proton",
  match = {
    xdg_tag = "^(proton-game)$",
  },
  tag = "+games",
})

apply_window_rule({
  name = "tag-gamestore-steam",
  match = {
    class = "^([Ss]team)$",
  },
  tag = "+gamestore",
})

apply_window_rule({
  name = "tag-gamestore-lutris",
  match = {
    title = "^([Ll]utris)$",
  },
  tag = "+gamestore",
})

apply_window_rule({
  name = "tag-gamestore-heroic",
  match = {
    class = "^(com.heroicgameslauncher.hgl)$",
  },
  tag = "+gamestore",
})

apply_window_rule({
  name = "tag-file-manager-common",
  match = {
    class = "^([Tt]hunar|org.gnome.Nautilus|[Pp]cmanfm-qt)$",
  },
  tag = "+file-manager",
})

apply_window_rule({
  name = "tag-file-manager-warp",
  match = {
    class = "^(app.drey.Warp)$",
  },
  tag = "+file-manager",
})

apply_window_rule({
  name = "tag-wallpaper-waytrogen",
  match = {
    class = "^([Ww]aytrogen)$",
  },
  tag = "+wallpaper",
})

apply_window_rule({
  name = "tag-multimedia-audacious",
  match = {
    class = "^([Aa]udacious)$",
  },
  tag = "+multimedia",
})

apply_window_rule({
  name = "tag-multimedia-video-players",
  match = {
    class = "^([Mm]pv|vlc)$",
  },
  tag = "+multimedia_video",
})

apply_window_rule({
  name = "tag-settings-rog-control",
  match = {
    title = "^(ROG Control)$",
  },
  tag = "+settings",
})

apply_window_rule({
  name = "tag-settings-wihotspot",
  match = {
    class = "^(wihotspot(-gui)?)$",
  },
  tag = "+settings",
})

apply_window_rule({
  name = "tag-settings-baobab",
  match = {
    class = "^([Bb]aobab|org.gnome.[Bb]aobab)$",
  },
  tag = "+settings",
})

apply_window_rule({
  name = "tag-settings-disks-and-hotspot",
  match = {
    class = "^(gnome-disks|wihotspot(-gui)?)$",
  },
  tag = "+settings",
})

apply_window_rule({
  name = "tag-settings-kvantum",
  match = {
    title = "(Kvantum Manager)",
  },
  tag = "+settings",
})

apply_window_rule({
  name = "tag-settings-file-roller",
  match = {
    class = "^(file-roller|org.gnome.FileRoller)$",
  },
  tag = "+settings",
})

apply_window_rule({
  name = "tag-settings-network-blueman",
  match = {
    class = "^(nm-applet|nm-connection-editor|blueman-manager)$",
  },
  tag = "+settings",
})

apply_window_rule({
  name = "tag-settings-pavucontrol",
  match = {
    class = "^(pavucontrol|org.pulseaudio.pavucontrol|com.saivert.pwvucontrol)$",
  },
  tag = "+settings",
})

apply_window_rule({
  name = "tag-settings-qtct",
  match = {
    class = "^(qt5ct|qt6ct)$",
  },
  tag = "+settings",
})

apply_window_rule({
  name = "tag-settings-xdg-portal-gtk",
  match = {
    class = "(xdg-desktop-portal-gtk)",
  },
  tag = "+settings",
})

apply_window_rule({
  name = "tag-settings-polkit-kde",
  match = {
    class = "^(org.kde.polkit-kde-authentication-agent-1)$",
  },
  tag = "+settings",
})

apply_window_rule({
  name = "tag-settings-rofi",
  match = {
    class = "^([Rr]ofi)$",
  },
  tag = "+settings",
})

apply_window_rule({
  name = "tag-settings-btrfs-assistant",
  match = {
    class = "^(btrfs-assistant)$",
  },
  tag = "+settings",
})

apply_window_rule({
  name = "tag-settings-timeshift",
  match = {
    class = "^(timeshift-gtk)$",
  },
  tag = "+settings",
})

apply_window_rule({
  name = "tag-viewer-system-monitor",
  match = {
    class = "^(gnome-system-monitor|org.gnome.SystemMonitor|io.missioncenter.MissionCenter)$",
  },
  tag = "+viewer",
})

apply_window_rule({
  name = "tag-viewer-evince",
  match = {
    class = "^(evince)$",
  },
  tag = "+viewer",
})

apply_window_rule({
  name = "tag-viewer-image-viewers",
  match = {
    class = "^(eog|org.gnome.Loupe)$",
  },
  tag = "+viewer",
})

apply_window_rule({
  name = "multimedia-disable-blur",
  match = {
    tag = "multimedia",
  },
  no_blur = true,
})

apply_window_rule({
  name = "multimedia-force-opacity",
  match = {
    tag = "multimedia",
  },
  opacity = 1.0,
})

apply_window_rule({
  name = "float-zoom-onedriver",
  match = {
    class = "([Zz]oom|onedriver|onedriver-launcher)",
  },
  float = true,
})

apply_window_rule({
  name = "float-video-players",
  match = {
    class = "^(mpv|com.github.rafostar.Clapper)$",
  },
  float = true,
})

apply_window_rule({
  name = "float-qalculate",
  match = {
    class = "^([Qq]alculate-gtk)$",
  },
  float = true,
})

apply_window_rule({
  name = "float-center-auth-required-title",
  match = {
    title = "^(Authentication Required)$",
  },
  float = true,
  center = true,
})

apply_window_rule({
  name = "float-center-polkit-auth-dialog",
  match = {
    class = "^(xfce-polkit|mate-polkit|polkit-mate-authentication-agent-1)$",
    title = "^(Authentication required|Authentication Required)$",
  },
  float = true,
  center = true,
  size = "(monitor_w*0.35) (monitor_h*0.35)",
})

apply_window_rule({
  name = "float-vscodium-secondary-window",
  match = {
    class = "(codium|codium-url-handler|VSCodium)",
    title = "negative:(.*codium.*|.*VSCodium.*)",
  },
  float = true,
})

apply_window_rule({
  name = "float-heroic-secondary-window",
  match = {
    class = "^(com.heroicgameslauncher.hgl)$",
    title = "negative:(Heroic Games Launcher)",
  },
  float = true,
})

apply_window_rule({
  name = "float-steam-secondary-window",
  match = {
    class = "^([Ss]team)$",
    title = "negative:^([Ss]team)$",
  },
  float = true,
})

apply_window_rule({
  name = "float-center-add-folder-dialog",
  match = {
    title = "^(Add Folder to Workspace)$",
  },
  float = true,
  size = "(monitor_w*0.7) (monitor_h*0.6)",
  center = true,
})

apply_window_rule({
  name = "float-center-save-as-dialog",
  match = {
    title = "^(Save As)$",
  },
  float = true,
  size = "(monitor_w*0.7) (monitor_h*0.6)",
  center = true,
})

apply_window_rule({
  name = "float-open-files-dialog",
  match = {
    initial_title = "(Open Files)",
  },
  float = true,
  size = "(monitor_w*0.7) (monitor_h*0.6)",
})

apply_window_rule({
  name = "float-center-sddm-background",
  match = {
    title = "^(SDDM Background)$",
  },
  float = true,
  center = true,
  size = "(monitor_w*0.16) (monitor_h*0.12)",
})

apply_window_rule({
  name = "float-center-yad-dialog",
  match = {
    class = "^(yad)$",
  },
  float = true,
  center = true,
  size = "(monitor_w*0.2) (monitor_h*0.2)",
})

apply_window_rule({
  name = "float-center-hyprland-donate",
  match = {
    class = "^(hyprland-donate-screen)$",
  },
  float = true,
  center = true,
})

apply_window_rule({
  name = "center-rog-control",
  match = {
    title = "^(ROG Control)$",
  },
  center = true,
})

apply_window_rule({
  name = "center-keybindings",
  match = {
    title = "^(Keybindings)$",
  },
  center = true,
})

apply_window_rule({
  name = "center-pavucontrol",
  match = {
    class = "^(pavucontrol|org.pulseaudio.pavucontrol|com.saivert.pwvucontrol)$",
  },
  center = true,
})

apply_window_rule({
  name = "center-whatsapp",
  match = {
    class = "^([Ww]hatsapp-for-linux|ZapZap|com.rtosta.zapzap)$",
  },
  center = true,
})

apply_window_rule({
  name = "center-network-editor",
  match = {
    class = "^(nm-connection-editor)$",
  },
  center = true,
})

apply_window_rule({
  name = "center-nm-auth-dialog",
  match = {
    class = "^(nm-applet)$",
    title = "^(Wi-Fi Network Authentication Required)$",
  },
  center = true,
})

apply_window_rule({
  name = "idle-inhibit-fullscreen-bool",
  match = {
    fullscreen = true,
  },
  idle_inhibit = "fullscreen",
})

apply_window_rule({
  name = "idle-inhibit-fullscreen-int",
  match = {
    fullscreen = 1,
  },
  idle_inhibit = "fullscreen",
})

apply_window_rule({
  name = "idle-inhibit-any-class",
  match = {
    class = ".*",
  },
  idle_inhibit = "fullscreen",
})

apply_window_rule({
  name = "idle-inhibit-any-title",
  match = {
    title = ".*",
  },
  idle_inhibit = "fullscreen",
})

apply_window_rule({
  name = "opacity-browser-tag",
  match = {
    tag = "browser",
  },
  opacity = "0.99 0.8",
})

apply_window_rule({
  name = "opacity-projects-tag",
  match = {
    tag = "projects",
  },
  opacity = "0.9 0.8",
})

apply_window_rule({
  name = "opacity-im-tag",
  match = {
    tag = "im",
  },
  opacity = "0.94 0.86",
})

apply_window_rule({
  name = "opacity-multimedia-tag",
  match = {
    tag = "multimedia",
  },
  opacity = "0.94 0.86",
})

apply_window_rule({
  name = "opacity-file-manager-tag",
  match = {
    tag = "file-manager",
  },
  opacity = "0.9 0.8",
})

apply_window_rule({
  name = "opacity-terminal-tag",
  match = {
    tag = "terminal",
  },
  opacity = "0.9 0.7",
})

apply_window_rule({
  name = "opacity-text-editors",
  match = {
    class = "^(gedit|org.gnome.TextEditor|mousepad)$",
  },
  opacity = "0.8 0.7",
})

apply_window_rule({
  name = "opacity-deluge",
  match = {
    class = "^(deluge)$",
  },
  opacity = "0.9 0.8",
})

apply_window_rule({
  name = "opacity-seahorse",
  match = {
    class = "^(seahorse)$",
  },
  opacity = "0.9 0.8",
})

apply_window_rule({
  name = "no-initial-focus-jetbrains",
  match = {
    class = "^(jetbrains-.*)$",
  },
  no_initial_focus = true,
})

apply_window_rule({
  name = "no-initial-focus-wind-title",
  match = {
    title = "^(wind.*)$",
  },
  no_initial_focus = true,
})


apply_window_rule({
  name = "Picture-in-Picture",
  match = {
    title = "^[Pp]icture-in-[Pp]icture$",
  },
  float = true,
  move = "72% 7%",
  opacity = "0.95 0.75",
  pin = true,
  keep_aspect_ratio = true,
  size = "(monitor_w*0.3) (monitor_h*0.3)",
})

apply_window_rule({
  name = "CachyOS Kernel Manager",
  match = {
    class = "^(org.cachyos.KernelManager)$",
    title = "^(CachyOS Kernel Manager)$",
    initial_class = "^(org.cachyos.KernelManager)$",
    initial_title = "^(CachyOS Kernel Manager)$",
  },
  float = true,
  center = true,
  size = "(monitor_w*0.6) (monitor_h*0.6)",
})

apply_window_rule({
  name = "Mainline Kernels",
  match = {
    class = "^(mainline-gtk)$",
    title = "^(Mainline Kernels)$",
    initial_class = "^(mainline-gtk)$",
    initial_title = "^(Mainline Kernels)$",
  },
  float = true,
  center = true,
  size = "(monitor_w*0.45) (monitor_h*0.55)",
})

apply_window_rule({
  name = "Kwallet",
  match = {
    class = "^(org.kde.kwalletmanager)$",
    title = "^(Wallet Manager)$",
    initial_class = "^(org.kde.kwalletmanager)$",
    initial_title = "^(Wallet Manager)$",
  },
  float = true,
  center = true,
  size = "(monitor_w*0.6) (monitor_h*0.6)",
})

apply_window_rule({
  name = "NVIDIA Settings",
  match = {
    class = "^(nvidia-settings)$",
    title = "^(NVIDIA Settings)$",
    initial_class = "^(nvidia-settings)$",
    initial_title = "^(NVIDIA Settings)$",
  },
  float = true,
  center = true,
  size = "(monitor_w*0.6) (monitor_h*0.6)",
})

apply_window_rule({
  name = "CachyOS Package Installer",
  match = {
    class = "^(org.cachyos.cachyos-pi)$",
    title = "^(CachyOS Package Installer)$",
    initial_class = "^(org.cachyos.cachyos-pi)$",
    initial_title = "^(CachyOS Package Installer)$",
  },
  float = true,
  center = true,
  size = "(monitor_w*0.6) (monitor_h*0.6)",
})

apply_window_rule({
  name = "Shelly",
  match = {
    class = "^(com.shellyorg.shelly)$",
    title = "^(Shelly)$",
    initial_class = "^(com.shellyorg.shelly)$",
    initial_title = "^(Shelly)$",
  },
  float = true,
  center = true,
  size = "(monitor_w*0.6) (monitor_h*0.6)",
})

apply_window_rule({
  name = "CachyOS Hello",
  match = {
    class = "^(CachyOSHello)$",
    title = "^(CachyOS Hello)$",
    initial_class = "^(CachyOSHello)$",
    initial_title = "^(CachyOS Hello)$",
  },
  float = true,
  center = true,
  size = "(monitor_w*0.6) (monitor_h*0.6)",
})

apply_window_rule({
  name = "Cache Cleaner - Octopi",
  match = {
    class = "^(octopi-cachecleaner)$",
    title = "^(Cache Cleaner - Octopi)$",
    initial_class = "^(octopi-cachecleaner)$",
    initial_title = "^(Cache Cleaner - Octopi)$",
  },
  float = true,
  center = true,
  size = "(monitor_w*0.6) (monitor_h*0.6)",
})

apply_window_rule({
  name = "Octopi Package Manager",
  match = {
    class = "^(octopi)$",
    title = "^(Octopi)$",
    initial_class = "^(octopi)$",
    initial_title = "^(Octopi)$",
  },
  float = true,
  center = true,
  size = "(monitor_w*0.6) (monitor_h*0.6)",
})

apply_window_rule({
  name = "Repository Editor - Octopi",
  match = {
    class = "^(octopi-repoeditor)$",
    title = "^(Repository Editor - Octopi)$",
    initial_class = "^(octopi-repoeditor)$",
    initial_title = "^(Repository Editor - Octop)$",
  },
  float = true,
  center = true,
  size = "(monitor_w*0.6) (monitor_h*0.6)",
})

apply_window_rule({
  name = "KooL Cheat (tag)",
  match = {
    tag = "KooL_Cheat",
  },
  float = true,
  center = true,
  size = "(monitor_w*0.65) (monitor_h*0.9)",
})

apply_window_rule({
  name = "Wallpaper (tag)",
  match = {
    tag = "wallpaper",
  },
  float = true,
  center = true,
  size = "(monitor_w*0.7) (monitor_h*0.7)",
  opacity = "0.9 0.7",
})

apply_window_rule({
  name = "Settings (tag)",
  match = {
    tag = "settings",
  },
  float = true,
  center = true,
  size = "(monitor_w*0.7) (monitor_h*0.7)",
  opacity = "0.8 0.7",
})

apply_window_rule({
  name = "Viewer (tag)",
  match = {
    tag = "viewer",
  },
  float = true,
  center = true,
  opacity = "0.82 0.75",
})

apply_window_rule({
  name = "KooL Settings (tag)",
  match = {
    tag = "KooL-Settings",
  },
  float = true,
  center = true,
})

apply_window_rule({
  name = "Multimedia Video (tag)",
  match = {
    tag = "multimedia_video",
  },
  no_blur = true,
  opacity = 1.0,
})

apply_window_rule({
  name = "Games (tag)",
  match = {
    tag = "games",
  },
  no_blur = true,
  fullscreen = 0,
})

apply_window_rule({
  name = "Ferdium",
  match = {
    class = "^([Ff]erdium)$",
  },
  float = true,
  center = true,
  size = "(monitor_w*0.6) (monitor_h*0.7)",
})

apply_window_rule({
  name = "Calculators",
  match = {
    class = "(org.gnome.Calculator|qalculate-gtk)",
  },
  float = true,
  center = true,
  size = "(monitor_w*0.55) (monitor_h*0.45)",
})

apply_window_rule({
  name = "Thunar Dialogs",
  match = {
    class = "([Tt]hunar)",
    title = "negative:(.*[Tt]hunar.*)",
  },
  float = true,
  center = true,
})

apply_window_rule({
  name = "Bitwarden",
  match = {
    class = "^(Bitwarden)$",
    title = "^(Bitwarden)$",
    initial_class = "^(Bitwarden)$",
    initial_title = "^(Bitwarden)$",
  },
  float = true,
  center = true,
  size = "(monitor_w*0.6) (monitor_h*0.6)",
})

apply_window_rule({
  name = "hyprland audio panel",
  match = {
    class = "^(hyprpwcenter)$",
    title = "^(Pipewire Control Center)$",
    initial_class = "^(hyprpwcenter)$",
    initial_title = "^(Pipewire Control Center)$",
  },
  float = true,
  center = true,
  size = "(monitor_w*0.6) (monitor_h*0.6)",
})

apply_window_rule({
  name = "Garuda Assistant",
  match = {
    class = "^(garuda-assistant)$",
    title = "^(Garuda Assistant)$",
    initial_class = "^(garuda-assistant)$",
    initial_title = "^(Garuda Assistant)$",
  },
  float = true,
  center = true,
  size = "(monitor_w*0.6) (monitor_h*0.6)",
})

apply_window_rule({
  name = "HyprMod GUI",
  match = {
    class = "^(com.github.hyprmod)$",
    title = "^(HyprMod)$",
    initial_class = "^(com.github.hyprmod)$",
    initial_title = "^(HyprMod)$",
  },
  float = true,
  center = true,
  size = "(monitor_w*0.7) (monitor_h*0.75)",
})

apply_window_rule({
  name = "EasyEffects",
  match = {
    class = "^(com.github.wwmm.easyeffects)$",
    title = "^(Easy Effects)$",
    initial_class = "^(com.github.wwmm.easyeffects)$",
    initial_title = "^(Easy Effects)$",
  },
  float = true,
  center = true,
  size = "(monitor_w*0.6) (monitor_h*0.65)",
})
apply_window_rule({
  name = "Megasync",
  match = {
    class = "^(nz\\.co\\.mega\\.megasync)$",
    initial_class = "^(nz\\.co\\.mega\\.megasync)$",
  },
  float = true,
  center = true,
  size = "(monitor_w*0.1) (monitor_h*0.2)",
})

apply_window_rule({
  name = "Mousam Weather",
  match = {
    class = "^(io.github.amit9838.mousam)$",
    title = "^(Mousam)$",
    initial_class = "^(io.github.amit9838.mousam)$",
    initial_title = "^(Mousam)$",
  },
  float = true,
  center = true,
  size = "(monitor_w*0.7) (monitor_h*0.75)",
})

-- Lua-only rule: keep the dropterminal positioned when toggled by keybind.
apply_window_rule({
  name = "dropterminal",
  match = {
    class = "kitty-dropterm",
  },
  float = true,
})
