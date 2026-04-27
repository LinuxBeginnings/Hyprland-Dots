-- Auto-generated from config/hypr/configs/WindowRules.conf for Lua testing.
-- Edit the source WindowRules.conf and regenerate this file when vendor rules change.

local function apply_window_rule(rule)
  if hl.window_rule then
    hl.window_rule(rule)
  end
end

local function apply_layer_rule(rule)
  if hl.layer_rule then
    hl.layer_rule(rule)
  end
end

apply_window_rule({
  name = "windowrule-001",
  match = {
    class = "^([Ff]irefox|org.mozilla.firefox|[Ff]irefox-esr|[Ff]irefox-bin)$",
  },
  tag = "+browser",
})

apply_window_rule({
  name = "windowrule-002",
  match = {
    class = "^([Gg]oogle-chrome(-beta|-dev|-unstable)?)$",
  },
  tag = "+browser",
})

apply_window_rule({
  name = "windowrule-003",
  match = {
    class = "^(chrome-.+-Default)$",
  },
  tag = "+browser",
})

apply_window_rule({
  name = "windowrule-004",
  match = {
    class = "^([Cc]hromium)$",
  },
  tag = "+browser",
})

apply_window_rule({
  name = "windowrule-005",
  match = {
    class = "^([Mm]icrosoft-edge(-stable|-beta|-dev|-unstable))$",
  },
  tag = "+browser",
})

apply_window_rule({
  name = "windowrule-006",
  match = {
    class = "^([Bb]rave-browser(-beta|-dev|-unstable)?)$",
  },
  tag = "+browser",
})

apply_window_rule({
  name = "windowrule-007",
  match = {
    class = "^([Tt]horium-browser|[Cc]achy-browser)$",
  },
  tag = "+browser",
})

apply_window_rule({
  name = "windowrule-008",
  match = {
    class = "^(zen-alpha|zen)$",
  },
  tag = "+browser",
})

apply_window_rule({
  name = "windowrule-009",
  match = {
    class = "^(swaync-control-center|swaync-notification-window|swaync-client|class)$",
  },
  tag = "+notif",
})

apply_window_rule({
  name = "windowrule-010",
  match = {
    title = "^(KooL Quick Cheat Sheet)$",
  },
  tag = "+KooL_Cheat",
})

apply_window_rule({
  name = "windowrule-011",
  match = {
    title = "^(KooL Hyprland Settings)$",
  },
  tag = "+KooL_Settings",
})

apply_window_rule({
  name = "windowrule-012",
  match = {
    class = "^(nwg-displays|nwg-look)$",
  },
  tag = "+KooL-Settings",
})

apply_window_rule({
  name = "windowrule-013",
  match = {
    class = "^(ghostty|wezterm|Alacritty|kitty|kitty-dropterm)$",
  },
  tag = "+terminal",
})

apply_window_rule({
  name = "windowrule-014",
  match = {
    class = "^([Tt]hunderbird|org.mozilla.Thunderbird)$",
  },
  tag = "+email",
})

apply_window_rule({
  name = "windowrule-015",
  match = {
    class = "^(eu.betterbird.Betterbird)$",
  },
  tag = "+email",
})

apply_window_rule({
  name = "windowrule-016",
  match = {
    class = "^(org.gnome.Evolution)$",
  },
  tag = "+email",
})

apply_window_rule({
  name = "windowrule-017",
  match = {
    class = "^(codium|codium-url-handler|VSCodium)$",
  },
  tag = "+projects",
})

apply_window_rule({
  name = "windowrule-018",
  match = {
    class = "^(VSCode|code|code-url-handler)$",
  },
  tag = "+projects",
})

apply_window_rule({
  name = "windowrule-019",
  match = {
    class = "^(jetbrains-.+)$",
  },
  tag = "+projects",
})

apply_window_rule({
  name = "windowrule-020",
  match = {
    class = "^(dev.zed.Zed|antigravity)$",
  },
  tag = "+projects",
})

apply_window_rule({
  name = "windowrule-021",
  match = {
    class = "^(com.obsproject.Studio)$",
  },
  tag = "+screenshare",
})

apply_window_rule({
  name = "windowrule-022",
  match = {
    class = "^([Dd]iscord|[Ww]ebCord|[Vv]esktop)$",
  },
  tag = "+im",
})

apply_window_rule({
  name = "windowrule-023",
  match = {
    class = "^([Ff]erdium)$",
  },
  tag = "+im",
})

apply_window_rule({
  name = "windowrule-024",
  match = {
    class = "^([Ww]hatsapp-for-linux|ZapZap|com.rtosta.zapzap)$",
  },
  tag = "+im",
})

apply_window_rule({
  name = "windowrule-025",
  match = {
    class = "^(org.telegram.desktop|io.github.tdesktop_x64.TDesktop)$",
  },
  tag = "+im",
})

apply_window_rule({
  name = "windowrule-026",
  match = {
    class = "^(teams-for-linux)$",
  },
  tag = "+im",
})

apply_window_rule({
  name = "windowrule-027",
  match = {
    class = "^(im.riot.Riot|Element)$",
  },
  tag = "+im",
})

apply_window_rule({
  name = "windowrule-028",
  match = {
    class = "^(gamescope)$",
  },
  tag = "+games",
})

apply_window_rule({
  name = "windowrule-029",
  match = {
    class = "^(steam_app_\\\\d+)$",
  },
  tag = "+games",
})

apply_window_rule({
  name = "windowrule-030",
  match = {
    xdg_tag = "^(proton-game)$",
  },
  tag = "+games",
})

apply_window_rule({
  name = "windowrule-031",
  match = {
    class = "^([Ss]team)$",
  },
  tag = "+gamestore",
})

apply_window_rule({
  name = "windowrule-032",
  match = {
    title = "^([Ll]utris)$",
  },
  tag = "+gamestore",
})

apply_window_rule({
  name = "windowrule-033",
  match = {
    class = "^(com.heroicgameslauncher.hgl)$",
  },
  tag = "+gamestore",
})

apply_window_rule({
  name = "windowrule-034",
  match = {
    class = "^([Tt]hunar|org.gnome.Nautilus|[Pp]cmanfm-qt)$",
  },
  tag = "+file-manager",
})

apply_window_rule({
  name = "windowrule-035",
  match = {
    class = "^(app.drey.Warp)$",
  },
  tag = "+file-manager",
})

apply_window_rule({
  name = "windowrule-036",
  match = {
    class = "^([Ww]aytrogen)$",
  },
  tag = "+wallpaper",
})

apply_window_rule({
  name = "windowrule-037",
  match = {
    class = "^([Aa]udacious)$",
  },
  tag = "+multimedia",
})

apply_window_rule({
  name = "windowrule-038",
  match = {
    class = "^([Mm]pv|vlc)$",
  },
  tag = "+multimedia_video",
})

apply_window_rule({
  name = "windowrule-039",
  match = {
    title = "^(ROG Control)$",
  },
  tag = "+settings",
})

apply_window_rule({
  name = "windowrule-040",
  match = {
    class = "^(wihotspot(-gui)?)$",
  },
  tag = "+settings",
})

apply_window_rule({
  name = "windowrule-041",
  match = {
    class = "^([Bb]aobab|org.gnome.[Bb]aobab)$",
  },
  tag = "+settings",
})

apply_window_rule({
  name = "windowrule-042",
  match = {
    class = "^(gnome-disks|wihotspot(-gui)?)$",
  },
  tag = "+settings",
})

apply_window_rule({
  name = "windowrule-043",
  match = {
    title = "(Kvantum Manager)",
  },
  tag = "+settings",
})

apply_window_rule({
  name = "windowrule-044",
  match = {
    class = "^(file-roller|org.gnome.FileRoller)$",
  },
  tag = "+settings",
})

apply_window_rule({
  name = "windowrule-045",
  match = {
    class = "^(nm-applet|nm-connection-editor|blueman-manager)$",
  },
  tag = "+settings",
})

apply_window_rule({
  name = "windowrule-046",
  match = {
    class = "^(pavucontrol|org.pulseaudio.pavucontrol|com.saivert.pwvucontrol)$",
  },
  tag = "+settings",
})

apply_window_rule({
  name = "windowrule-047",
  match = {
    class = "^(qt5ct|qt6ct)$",
  },
  tag = "+settings",
})

apply_window_rule({
  name = "windowrule-048",
  match = {
    class = "(xdg-desktop-portal-gtk)",
  },
  tag = "+settings",
})

apply_window_rule({
  name = "windowrule-049",
  match = {
    class = "^(org.kde.polkit-kde-authentication-agent-1)$",
  },
  tag = "+settings",
})

apply_window_rule({
  name = "windowrule-050",
  match = {
    class = "^([Rr]ofi)$",
  },
  tag = "+settings",
})

apply_window_rule({
  name = "windowrule-051",
  match = {
    class = "^(btrfs-assistant)$",
  },
  tag = "+settings",
})

apply_window_rule({
  name = "windowrule-052",
  match = {
    class = "^(timeshift-gtk)$",
  },
  tag = "+settings",
})

apply_window_rule({
  name = "windowrule-053",
  match = {
    class = "^(gnome-system-monitor|org.gnome.SystemMonitor|io.missioncenter.MissionCenter)$",
  },
  tag = "+viewer",
})

apply_window_rule({
  name = "windowrule-054",
  match = {
    class = "^(evince)$",
  },
  tag = "+viewer",
})

apply_window_rule({
  name = "windowrule-055",
  match = {
    class = "^(eog|org.gnome.Loupe)$",
  },
  tag = "+viewer",
})

apply_window_rule({
  name = "windowrule-056",
  match = {
    tag = "multimedia",
  },
  no_blur = true,
})

apply_window_rule({
  name = "windowrule-057",
  match = {
    tag = "multimedia",
  },
  opacity = 1.0,
})

apply_window_rule({
  name = "windowrule-058",
  match = {
    class = "([Zz]oom|onedriver|onedriver-launcher)",
  },
  float = true,
})

apply_window_rule({
  name = "windowrule-059",
  match = {
    class = "^(mpv|com.github.rafostar.Clapper)$",
  },
  float = true,
})

apply_window_rule({
  name = "windowrule-060",
  match = {
    class = "^([Qq]alculate-gtk)$",
  },
  float = true,
})

apply_window_rule({
  name = "windowrule-061",
  match = {
    title = "^(Authentication Required)$",
  },
  float = true,
  center = true,
})

apply_window_rule({
  name = "windowrule-062",
  match = {
    class = "^(xfce-polkit|mate-polkit|polkit-mate-authentication-agent-1)$",
    title = "^(Authentication required|Authentication Required)$",
  },
  float = true,
  center = true,
  size = "(monitor_w*0.35) (monitor_h*0.35)",
})

apply_window_rule({
  name = "windowrule-063",
  match = {
    class = "(codium|codium-url-handler|VSCodium)",
    title = "negative:(.*codium.*|.*VSCodium.*)",
  },
  float = true,
})

apply_window_rule({
  name = "windowrule-064",
  match = {
    class = "^(com.heroicgameslauncher.hgl)$",
    title = "negative:(Heroic Games Launcher)",
  },
  float = true,
})

apply_window_rule({
  name = "windowrule-065",
  match = {
    class = "^([Ss]team)$",
    title = "negative:^([Ss]team)$",
  },
  float = true,
})

apply_window_rule({
  name = "windowrule-066",
  match = {
    title = "^(Add Folder to Workspace)$",
  },
  float = true,
  size = "(monitor_w*0.7) (monitor_h*0.6)",
  center = true,
})

apply_window_rule({
  name = "windowrule-067",
  match = {
    title = "^(Save As)$",
  },
  float = true,
  size = "(monitor_w*0.7) (monitor_h*0.6)",
  center = true,
})

apply_window_rule({
  name = "windowrule-068",
  match = {
    initial_title = "(Open Files)",
  },
  float = true,
  size = "(monitor_w*0.7) (monitor_h*0.6)",
})

apply_window_rule({
  name = "windowrule-069",
  match = {
    title = "^(SDDM Background)$",
  },
  float = true,
  center = true,
  size = "(monitor_w*0.16) (monitor_h*0.12)",
})

apply_window_rule({
  name = "windowrule-070",
  match = {
    class = "^(yad)$",
  },
  float = true,
  center = true,
  size = "(monitor_w*0.2) (monitor_h*0.2)",
})

apply_window_rule({
  name = "windowrule-071",
  match = {
    class = "^(hyprland-donate-screen)$",
  },
  float = true,
  center = true,
})

apply_window_rule({
  name = "windowrule-072",
  match = {
    title = "^(ROG Control)$",
  },
  center = true,
})

apply_window_rule({
  name = "windowrule-073",
  match = {
    title = "^(Keybindings)$",
  },
  center = true,
})

apply_window_rule({
  name = "windowrule-074",
  match = {
    class = "^(pavucontrol|org.pulseaudio.pavucontrol|com.saivert.pwvucontrol)$",
  },
  center = true,
})

apply_window_rule({
  name = "windowrule-075",
  match = {
    class = "^([Ww]hatsapp-for-linux|ZapZap|com.rtosta.zapzap)$",
  },
  center = true,
})

apply_window_rule({
  name = "windowrule-076",
  match = {
    class = "^(nm-connection-editor)$",
  },
  center = true,
})

apply_window_rule({
  name = "windowrule-077",
  match = {
    class = "^(nm-applet)$",
    title = "^(Wi-Fi Network Authentication Required)$",
  },
  center = true,
})

apply_window_rule({
  name = "windowrule-078",
  match = {
    fullscreen = true,
  },
  idle_inhibit = "fullscreen",
})

apply_window_rule({
  name = "windowrule-079",
  match = {
    fullscreen = 1,
  },
  idle_inhibit = "fullscreen",
})

apply_window_rule({
  name = "windowrule-080",
  match = {
    class = ".*",
  },
  idle_inhibit = "fullscreen",
})

apply_window_rule({
  name = "windowrule-081",
  match = {
    title = ".*",
  },
  idle_inhibit = "fullscreen",
})

apply_window_rule({
  name = "windowrule-082",
  match = {
    tag = "browser",
  },
  opacity = "0.99 0.8",
})

apply_window_rule({
  name = "windowrule-083",
  match = {
    tag = "projects",
  },
  opacity = "0.9 0.8",
})

apply_window_rule({
  name = "windowrule-084",
  match = {
    tag = "im",
  },
  opacity = "0.94 0.86",
})

apply_window_rule({
  name = "windowrule-085",
  match = {
    tag = "multimedia",
  },
  opacity = "0.94 0.86",
})

apply_window_rule({
  name = "windowrule-086",
  match = {
    tag = "file-manager",
  },
  opacity = "0.9 0.8",
})

apply_window_rule({
  name = "windowrule-087",
  match = {
    tag = "terminal",
  },
  opacity = "0.9 0.7",
})

apply_window_rule({
  name = "windowrule-088",
  match = {
    class = "^(gedit|org.gnome.TextEditor|mousepad)$",
  },
  opacity = "0.8 0.7",
})

apply_window_rule({
  name = "windowrule-089",
  match = {
    class = "^(deluge)$",
  },
  opacity = "0.9 0.8",
})

apply_window_rule({
  name = "windowrule-090",
  match = {
    class = "^(seahorse)$",
  },
  opacity = "0.9 0.8",
})

apply_window_rule({
  name = "windowrule-091",
  match = {
    class = "^(jetbrains-.*)$",
  },
  no_initial_focus = true,
})

apply_window_rule({
  name = "windowrule-092",
  match = {
    title = "^(wind.*)$",
  },
  no_initial_focus = true,
})

apply_layer_rule({
  name = "layerrule-001",
  match = {
    namespace = "rofi",
  },
  blur = true,
})

apply_layer_rule({
  name = "layerrule-002",
  match = {
    namespace = "notifications",
  },
  blur = true,
})

apply_layer_rule({
  name = "layerrule-003",
  match = {
    namespace = "quickshell:overview",
  },
  blur = true,
})

apply_layer_rule({
  name = "layerrule-004",
  match = {
    namespace = "quickshell:overview",
  },
  ignore_alpha = 0.5,
})

apply_layer_rule({
  name = "layerrule-005",
  match = {
    namespace = "wallpaper",
  },
  blur = true,
})

apply_layer_rule({
  name = "layerrule-006",
  match = {
    namespace = "rofi",
  },
  animation = "slide",
})

apply_layer_rule({
  name = "layerrule-007",
  match = {
    namespace = "notifications",
  },
  animation = "slide",
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
  size = "1248 702",
  move = "336 108",
  pin = true,
})
