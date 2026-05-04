-- ==================================================
--  KoolDots (2026)
--  Project URL: https://github.com/LinuxBeginnings
--  License: GNU GPLv3
--  SPDX-License-Identifier: GPL-3.0-or-later
-- ==================================================

-- Auto-generated from Keybinds.conf/UserKeybinds.conf for Lua testing
-- Helper internals live in keybind_helpers.lua so this file stays focused on bindings you may edit.
-- To add a binding, copy an existing bind(...) line and change:
--   1) modifiers (e.g. "SUPER SHIFT")
--   2) key (e.g. "Return", "code:10", "mouse_down")
--   3) action (exec_cmd(...) or dispatch(...))
--   4) description text
local keybind_helpers = nil
do
  local source = (debug.getinfo(1, "S") or {}).source or ""
  local source_path = source:match("^@(.+)$")
  local source_dir = source_path and source_path:match("^(.*)/[^/]+$") or nil
  local home = os.getenv("HOME") or ""
  local candidate_paths = {
    source_dir and (source_dir .. "/keybind_helpers.lua") or nil,
    home ~= "" and (home .. "/.config/hypr/lua/keybind_helpers.lua") or nil,
    home ~= "" and (home .. "/.config/hypr/keybind_helpers.lua") or nil,
  }

  local tried_paths = {}
  for _, helper_path in ipairs(candidate_paths) do
    if helper_path then
      table.insert(tried_paths, helper_path)
      local f = io.open(helper_path, "r")
      if f then
        f:close()
        local loaded_ok, loaded_helpers = pcall(dofile, helper_path)
        if loaded_ok and type(loaded_helpers) == "table" and loaded_helpers.unbind_default_keys then
          keybind_helpers = loaded_helpers
          break
        end
      end
    end
  end

  if not keybind_helpers then
    error("Failed to load keybind_helpers.lua from: " .. table.concat(tried_paths, ", "))
  end
end
local window_api = keybind_helpers.window_api
local exec_cmd = keybind_helpers.exec_cmd
local raw_dispatch_cmd = keybind_helpers.raw_dispatch_cmd
local dispatch = keybind_helpers.dispatch
local bind = keybind_helpers.bind
local bindm = keybind_helpers.bindm

-- Mass unbind defaults before rebuilding the Lua keymap.
keybind_helpers.unbind_default_keys()

-- ==================================================
-- User-editable bindings
-- ==================================================
-- Section: Application launchers and utility scripts
local app_binds = {
  { "SUPER", "D", "pkill rofi || true && rofi -show drun -modi drun,filebrowser,run,window", "app launcher" },
  { "SUPER", "B", 'xdg-open "https://"', "open default browser" },
  { "SUPER", "A", "$HOME/.config/hypr/scripts/OverviewToggle.sh", "desktop overview" },
  { "SUPER", "Return", "kitty", "Open terminal" },
  { "SUPER", "E", "thunar", "file manager" },
  { "SUPER", "C", "$HOME/.config/hypr/scripts/rofi-ssh-menu.sh", "SSH session manager" },
  { "SUPER", "T", "$HOME/.config/hypr/scripts/ThemeChanger.sh", "Global theme switcher using Wallust" },
  { "SUPER", "H", "$HOME/.config/hypr/scripts/KeyHints.sh", "help / cheat sheet" },
  { "SUPER ALT", "R", "$HOME/.config/hypr/scripts/Refresh.sh", "refresh bar and menus" },
  { "SUPER ALT", "E", "$HOME/.config/hypr/scripts/RofiEmoji.sh", "emoji menu" },
  { "SUPER", "S", "$HOME/.config/hypr/scripts/RofiSearch.sh", "web search" },
  { "SUPER CTRL", "S", "rofi -show window", "window switcher" },
  { "SUPER ALT", "O", "$HOME/.config/hypr/scripts/ChangeBlur.sh", "toggle blur" },
  { "SUPER SHIFT", "G", "$HOME/.config/hypr/scripts/GameMode.sh", "toggle game mode" },
  { "SUPER ALT", "L", "$HOME/.config/hypr/scripts/ChangeLayout.sh toggle", "toggle layouts" },
  { "SUPER ALT", "V", "$HOME/.config/hypr/scripts/ClipManager.sh", "clipboard manager" },
  { "SUPER CTRL", "R", "$HOME/.config/hypr/scripts/RofiThemeSelector.sh", "rofi theme selector" },
  {
    "SUPER CTRL SHIFT",
    "R",
    "pkill rofi || true && $HOME/.config/hypr/scripts/RofiThemeSelector-modified.sh",
    "rofi theme selector (modified)",
  },
  { "SUPER CTRL", "K", "$HOME/.config/hypr/scripts/Kitty_themes.sh", "Kitty theme selector" },
  {
    "SUPER SHIFT",
    "B",
    "$HOME/.config/hypr/UserScripts/RainbowBorders-low-cpu.sh  --run-once",
    "Set static Rainbow Border",
  },
  {
    "SUPER SHIFT",
    "H",
    "$HOME/.config/hypr/scripts/Toggle-Active-Window-Audio.sh",
    "Toggle Mute/Unmute for Active-Window",
  },
  {
    "ALT SHIFT",
    "S",
    "$HOME/.config/hypr/scripts/hyprshot.sh -m region -o $HOME/Pictures/Screenshots",
    "Hyprshot Screen Capture",
  },
  { "SUPER ALT", "SPACE", "$HOME/.config/hypr/scripts/Float-all-Windows.sh", "Float all windows" },
  { "SUPER SHIFT", "Return", "$HOME/.config/hypr/scripts/Dropterminal.sh kitty", "DropDown terminal" },
  {
    "SUPER ALT",
    "mouse_down",
    "hyprctl keyword cursor:zoom_factor \"$(hyprctl getoption cursor:zoom_factor | awk 'NR==1 {factor = $2; if (factor < 1) {factor = 1}; print factor * 2.0}')\"",
    "zoom in",
  },
  {
    "SUPER ALT",
    "mouse_up",
    "hyprctl keyword cursor:zoom_factor \"$(hyprctl getoption cursor:zoom_factor | awk 'NR==1 {factor = $2; if (factor < 1) {factor = 1}; print factor / 2.0}')\"",
    "zoom out",
  },
  { "SUPER CTRL ALT", "B", "pkill -SIGUSR1 waybar", "toggle waybar on/off" },
  { "SUPER CTRL", "B", "$HOME/.config/hypr/scripts/WaybarStyles.sh", "waybar styles menu" },
  { "SUPER ALT", "B", "$HOME/.config/hypr/scripts/WaybarLayout.sh", "waybar layout menu" },
  { "SUPER", "N", "$HOME/.config/hypr/scripts/Hyprsunset.sh toggle", "toggle night light" },
  { "SUPER SHIFT", "M", "$HOME/.config/hypr/UserScripts/RofiBeats.sh", "online music" },
  { "SUPER", "W", "$HOME/.config/hypr/UserScripts/WallpaperSelect.sh", "select wallpaper" },
  { "SUPER SHIFT", "W", "$HOME/.config/hypr/UserScripts/WallpaperEffects.sh", "wallpaper effects" },
  { "CTRL ALT", "W", "$HOME/.config/hypr/UserScripts/WallpaperRandom.sh", "random wallpaper" },
  { "SUPER SHIFT", "K", "$HOME/.config/hypr/scripts/KeyBinds.sh", "search keybinds" },
  { "SUPER SHIFT", "A", "$HOME/.config/hypr/scripts/Animations.sh", "animations menu" },
  { "SUPER SHIFT", "O", "$HOME/.config/hypr/UserScripts/ZshChangeTheme.sh", "change oh-my-zsh theme" },
  { "SUPER ALT", "C", "$HOME/.config/hypr/UserScripts/RofiCalc.sh", "calculator" },
}
for _, app in ipairs(app_binds) do
  bind(app[1], app[2], exec_cmd(app[3]), { description = app[4] })
end
--
--
-- These are examples of how to bind to a TUI/CLI apps
-- The specific keybinds are just examples
-- Do not user as-is as it will break exisitng keybinds
--
--
-- TUI Apps Configuration (commented options from LUA-files/hyprland-key-bindings-example.lua).
-- local terminal = "uwsm-app -- " .. (os.getenv("TERMINAL") or "")
-- local browser = "omarchy-launch-browser"
-- local tui_apps = {
--   { "CTRL + ALT + O", "opencode", "a opencode", "OpenCode" },
--   { "CTRL + ALT + SHIFT + A", "cline", "-e cline", "OpenCode" },
--   { "CTRL + ALT + B", "btop", "-e btop", "Task Manager" },
--   { "CTRL + ALT + SHIFT + B", "bluetui", "-e bluetui", "BlueTUI" },
--   { "CTRL + ALT + E", "spf", "-e spf", "SuperFile Manager" },
--   { "CTRL + ALT + L", "lazygit", "-e lazygit", "LazyGit" },
--   { "CTRL + ALT + N", "nvtop", "-e nvtop", "Nvtop" },
--   { "CTRL + ALT + SHIFT + N", "ncdu", "-e ncdu", "Ncdu" },
--   { "CTRL + ALT + W", "impala", "-e impala", "Impala Wi-Fi" },
--   { "CTRL + ALT + P", "pacseek", "-e pacseek", "PacSeek" },
--   { "CTRL + ALT + SHIFT + P", "pacsea", "-e pacsea", "PacSea" },
--   { "CTRL + ALT + R", "fzf-uninstall", "-e ~/.config/hypr/fzfpurge", "Fzf Uninstaller" },
--   { "CTRL + ALT + V", "wiremix", "-e wiremix", "WireMix Volume" },
--   { "CTRL + ALT + SHIFT + H", "htop", "-e htop", "Htop" },
-- }
-- for _, app in ipairs(tui_apps) do
--   hl.bind(app[1], hl.dsp.exec_cmd(terminal .. " --title=" .. app[2] .. " " .. app[3]), { description = app[4] })
-- end

--
--
-- These are examples of how to bind webpages
-- The specific keybinds are just examples
-- Do not user as-is as it will break exisitng keybinds
--
--
-- Web Apps Configuration (commented options from LUA-files/hyprland-key-bindings-example.lua).
-- local web_apps = {
--   { "SUPER + A", "https://gemini.google.com", "Gemini AI" },
--   { "SUPER + Y", "https://youtube.com", "YouTube" },
--   { "SUPER + T", "https://tiktok.com", "TikTok" },
--   { "SUPER + X", "https://x.com", "X.com" },
--   { "SUPER + U", "http://10.24.1.1", "Unifi" },
--   { "SUPER + I", "https://instagram.com", "Instagram" },
--   { "SUPER + P", "https://mail.proton.me", "Proton Mail" },
-- }
-- for _, web in ipairs(web_apps) do
--   hl.bind(web[1], hl.dsp.exec_cmd([[omarchy-launch-webapp "]] .. web[2] .. [["]]), { description = web[3] })
-- end

-- Manual example actions not currently active in this config.
-- hl.bind("SUPER + F", hl.dsp.window.fullscreen({ mode = "fullscreen" }), { description = "Fullscreen Window" })
-- hl.bind("ALT + SPACE", hl.dsp.window.float({ action = "toggle" }), { description = "Toggle floating" })
-- hl.bind("CTRL + ALT + return", hl.dsp.exec_cmd("uwsm-app -- kitty"), { description = "Kitty terminal" })
-- hl.bind(
--   "CTRL + ALT + SHIFT + return",
--   hl.dsp.exec_cmd([[uwsm-app -- xdg-terminal-exec --dir="$(omarchy-cmd-terminal-cwd)" tmux new]]),
--   { description = "Tmux" }
-- )

-- Section: Window/session controls
bind("SUPER SHIFT", "F", dispatch("fullscreen", ""), { description = "fullscreen" })
bind("SUPER CTRL", "F", dispatch("fullscreen", "1"), { description = "maximize window" })
bind("SUPER", "SPACE", dispatch("togglefloating", ""), { description = "Float current window" })
bind("SUPER CTRL", "O", dispatch("setprop", "active opaque toggle"), { description = "toggle active window opacity" })
bind(
  "ALT_L",
  "SHIFT_L",
  dispatch("switch keyboard layout globally", "exec, $HOME/.config/hypr/scripts/KeyboardLayout.sh switch"),
  { locked = true, description = "switch keyboard layout globally" }
)
bind(
  "SHIFT_L",
  "ALT_L",
  dispatch("switch keyboard layout per-window", "exec, $HOME/.config/hypr/scripts/Tak0-Per-Window-Switch.sh"),
  { locked = true, description = "switch keyboard layout per-window" }
)
bind(
  "SUPER CTRL",
  "F9",
  dispatch("movecurrentworkspacetomonitor", "l"),
  { description = "move workspace to left monitor" }
)
bind(
  "SUPER CTRL",
  "F10",
  dispatch("movecurrentworkspacetomonitor", "r"),
  { description = "move workspace to right monitor" }
)
bind(
  "SUPER CTRL",
  "F11",
  dispatch("movecurrentworkspacetomonitor", "u"),
  { description = "move workspace to up monitor" }
)
bind(
  "SUPER CTRL",
  "F12",
  dispatch("movecurrentworkspacetomonitor", "d"),
  { description = "move workspace to down monitor" }
)
bind("CTRL ALT", "Delete", raw_dispatch_cmd("exit"), { description = "exit Hyprland" })
bind("SUPER", "Q", dispatch("killactive", ""), { description = "close active window" })
bind(
  "SUPER SHIFT",
  "Q",
  exec_cmd("$HOME/.config/hypr/scripts/KillActiveProcess.sh"),
  { description = "Terminate active process" }
)
bind("CTRL ALT", "L", exec_cmd("$HOME/.config/hypr/scripts/LockScreen.sh"), { description = "lock screen" })
bind("CTRL ALT", "P", exec_cmd("$HOME/.config/hypr/scripts/Wlogout.sh"), { description = "powermenu" })
bind("SUPER SHIFT", "N", exec_cmd("swaync-client -t -sw"), { description = "notification panel" })
bind(
  "SUPER SHIFT",
  "E",
  exec_cmd("$HOME/.config/hypr/scripts/Kool_Quick_Settings.sh"),
  { description = "Quick settings menu" }
)

-- Section: Layout and tiling controls
bind("SUPER CTRL", "D", dispatch("layoutmsg", "removemaster"), { description = "remove master" })
bind("SUPER", "I", dispatch("layoutmsg", "addmaster"), { description = "add master" })
bind("SUPER", "j", exec_cmd("$HOME/.config/hypr/scripts/LuaCycleWindow.sh next"), { description = "cycle next" })
bind(
  "SUPER",
  "k",
  exec_cmd("$HOME/.config/hypr/scripts/LuaCycleWindow.sh previous"),
  { description = "cycle previous" }
)
bind("SUPER CTRL", "Return", dispatch("layoutmsg", "swapwithmaster"), { description = "swap with master" })
bind("SUPER SHIFT", "I", dispatch("layoutmsg", "togglesplit"), { description = "toggle split (dwindle)" })
bind("SUPER", "P", dispatch("pseudo", ""), { description = "toggle pseudo (dwindle)" })
bind("SUPER", "M", raw_dispatch_cmd("splitratio 0.3"), { description = "set split ratio 0.3" })
bind(
  "SUPER ALT",
  "1",
  exec_cmd("$HOME/.config/hypr/scripts/ChangeLayout.sh dwindle"),
  { description = "layout dwindle" }
)
bind("SUPER ALT", "2", exec_cmd("$HOME/.config/hypr/scripts/ChangeLayout.sh master"), { description = "layout master" })
bind(
  "SUPER ALT",
  "3",
  exec_cmd("$HOME/.config/hypr/scripts/ChangeLayout.sh scrolling"),
  { description = "layout scrolling" }
)
bind(
  "SUPER ALT",
  "4",
  exec_cmd("$HOME/.config/hypr/scripts/ChangeLayout.sh monocle"),
  { description = "layout monocle" }
)
bind("SUPER SHIFT", "period", dispatch("layoutmsg", "move +col"), { description = "move to right column" })
bind("SUPER SHIFT", "comma", dispatch("layoutmsg", "move -col"), { description = "move to left column" })
bind("SUPER ALT", "comma", dispatch("layoutmsg", "swapcol l"), { description = "swap columns left" })
bind("SUPER ALT", "period", dispatch("layoutmsg", "swapcol r"), { description = "swap columns right" })
bind(
  "SUPER ALT",
  "H",
  exec_cmd("hyprctl keyword scrolling:direction right"),
  { description = "Horizonal scroll right" }
)
bind("SUPER ALT", "V", exec_cmd("hyprctl keyword scrolling:direction down"), { description = "Vertical Scroll down" })
bind(
  "SUPER ALT",
  "S",
  exec_cmd(
    'bash -c \'[[ $(hyprctl getoption scrolling:direction -j | jq -r ".str") == "right" ]] && hyprctl keyword scrolling:direction down || hyprctl keyword scrolling:direction right\''
  ),
  { description = "toggle scrolling V/H" }
)
bind("ALT", "Tab", exec_cmd("$HOME/.config/hypr/scripts/LuaCycleWindow.sh next"), { description = "cycle next window" })

-- Section: Audio, media, and hardware keys
bind(
  "",
  "xf86audioraisevolume",
  dispatch("volume up", "exec, $HOME/.config/hypr/scripts/Volume.sh --inc"),
  { description = "volume up" }
)
bind(
  "",
  "xf86audiolowervolume",
  dispatch("volume down", "exec, $HOME/.config/hypr/scripts/Volume.sh --dec"),
  { description = "volume down" }
)
bind(
  "ALT",
  "xf86audioraisevolume",
  dispatch("volume up precise", "exec, $HOME/.config/hypr/scripts/Volume.sh --inc-precise"),
  { description = "volume up precise" }
)
bind(
  "ALT",
  "xf86audiolowervolume",
  dispatch("volume down precise", "exec, $HOME/.config/hypr/scripts/Volume.sh --dec-precise"),
  { description = "volume down precise" }
)
bind(
  "",
  "xf86AudioMicMute",
  dispatch("toggle mic mute", "exec, $HOME/.config/hypr/scripts/Volume.sh --toggle-mic"),
  { locked = true, description = "toggle mic mute" }
)
bind(
  "",
  "xf86audiomute",
  dispatch("toggle mute", "exec, $HOME/.config/hypr/scripts/Volume.sh --toggle"),
  { locked = true, description = "toggle mute" }
)
bind("", "xf86Sleep", dispatch("sleep", "exec, systemctl suspend"), { locked = true, description = "sleep" })
bind(
  "",
  "xf86Rfkill",
  dispatch("airplane mode", "exec, $HOME/.config/hypr/scripts/AirplaneMode.sh"),
  { locked = true, description = "airplane mode" }
)
bind(
  "",
  "xf86AudioPlayPause",
  dispatch("play/pause", "exec, $HOME/.config/hypr/scripts/MediaCtrl.sh --pause"),
  { locked = true, description = "play/pause" }
)
bind(
  "",
  "xf86AudioPause",
  dispatch("pause", "exec, $HOME/.config/hypr/scripts/MediaCtrl.sh --pause"),
  { locked = true, description = "pause" }
)
bind(
  "",
  "xf86AudioPlay",
  dispatch("play", "exec, $HOME/.config/hypr/scripts/MediaCtrl.sh --pause"),
  { locked = true, description = "play" }
)
bind(
  "",
  "xf86AudioNext",
  dispatch("next track", "exec, $HOME/.config/hypr/scripts/MediaCtrl.sh --nxt"),
  { locked = true, description = "next track" }
)
bind(
  "",
  "xf86AudioPrev",
  dispatch("previous track", "exec, $HOME/.config/hypr/scripts/MediaCtrl.sh --prv"),
  { locked = true, description = "previous track" }
)
bind(
  "",
  "xf86audiostop",
  dispatch("stop", "exec, $HOME/.config/hypr/scripts/MediaCtrl.sh --stop"),
  { locked = true, description = "stop" }
)

-- Section: Screenshot bindings
bind("SUPER", "Print", exec_cmd("$HOME/.config/hypr/scripts/ScreenShot.sh --now"), { description = "screenshot now" })
bind(
  "SUPER SHIFT",
  "Print",
  exec_cmd("$HOME/.config/hypr/scripts/ScreenShot.sh --area"),
  { description = "screenshot (area)" }
)
bind(
  "SUPER CTRL",
  "Print",
  exec_cmd("$HOME/.config/hypr/scripts/ScreenShot.sh --in5"),
  { description = "screenshot in 5s" }
)
bind(
  "SUPER CTRL SHIFT",
  "Print",
  exec_cmd("$HOME/.config/hypr/scripts/ScreenShot.sh --in10"),
  { description = "screenshot in 10s" }
)
bind(
  "ALT",
  "Print",
  exec_cmd("$HOME/.config/hypr/scripts/ScreenShot.sh --active"),
  { description = "screenshot active window" }
)
bind(
  "SUPER SHIFT",
  "S",
  exec_cmd("$HOME/.config/hypr/scripts/ScreenShot.sh --swappy"),
  { description = "screenshot (swappy)" }
)
-- Keep legacy script-based resize bindings commented for quick rollback during Lua API migration.
-- These call ResizeActive.sh and are preserved in case native hl.dsp/hl.window resize behavior regresses.
-- bind(
--   "SUPER SHIFT",
--   "left",
--   exec_cmd("bash $HOME/.config/hypr/scripts/ResizeActive.sh -50 0"),
--   { description = "resize left (-50)" }
-- )
-- bind(
--   "SUPER SHIFT",
--   "right",
--   exec_cmd("bash $HOME/.config/hypr/scripts/ResizeActive.sh 50 0"),
--   { description = "resize right (+50)" }
-- )
-- bind(
--   "SUPER SHIFT",
--   "up",
--   exec_cmd("bash $HOME/.config/hypr/scripts/ResizeActive.sh 0 -50"),
--   { description = "resize up (-50)" }
-- )
-- bind(
--   "SUPER SHIFT",
--   "down",
--   exec_cmd("bash $HOME/.config/hypr/scripts/ResizeActive.sh 0 50"),
--   { description = "resize down (+50)" }
-- )
bind("SUPER SHIFT", "left", window_api.resize({ x = -50, y = 0, relative = true }), { description = "resize left (-50)" })
bind("SUPER SHIFT", "right", window_api.resize({ x = 50, y = 0, relative = true }), { description = "resize right (+50)" })
bind("SUPER SHIFT", "up", window_api.resize({ x = 0, y = -50, relative = true }), { description = "resize up (-50)" })
bind("SUPER SHIFT", "down", window_api.resize({ x = 0, y = 50, relative = true }), { description = "resize down (+50)" })
-- Keep legacy directional move script binds commented for rollback during Lua API migration.
-- Native movewindow dispatch below replaces LuaMoveWindowDirectional.sh usage.
-- bind(
--   "SUPER CTRL",
--   "left",
--   exec_cmd("$HOME/.config/hypr/scripts/LuaMoveWindowDirectional.sh left"),
--   { description = "move window left" }
-- )
-- bind(
--   "SUPER CTRL",
--   "right",
--   exec_cmd("$HOME/.config/hypr/scripts/LuaMoveWindowDirectional.sh right"),
--   { description = "move window right" }
-- )

-- Section: Window resize, move, swap, and grouping
bind("SUPER CTRL", "left", dispatch("movewindow", "l"), { description = "move window left" })
bind("SUPER CTRL", "right", dispatch("movewindow", "r"), { description = "move window right" })
bind("SUPER CTRL", "up", dispatch("movewindow", "u"), { description = "move window up" })
bind("SUPER CTRL", "down", dispatch("movewindow", "d"), { description = "move window down" })
bind(
  "SUPER ALT",
  "left",
  exec_cmd("$HOME/.config/hypr/scripts/LuaSwapWindow.sh l"),
  { description = "swap window left" }
)
bind(
  "SUPER ALT",
  "right",
  exec_cmd("$HOME/.config/hypr/scripts/LuaSwapWindow.sh r"),
  { description = "swap window right" }
)
bind("SUPER ALT", "up", exec_cmd("$HOME/.config/hypr/scripts/LuaSwapWindow.sh u"), { description = "swap window up" })
bind(
  "SUPER ALT",
  "down",
  exec_cmd("$HOME/.config/hypr/scripts/LuaSwapWindow.sh d"),
  { description = "swap window down" }
)
bind("SUPER", "G", dispatch("togglegroup", ""), { description = "toggle group" })
bind("SUPER", "Tab", dispatch("changegroupactive", "f"), { description = "Change Group Forward" })
bind("SUPER CTRL", "tab", dispatch("changegroupactive", ""), { description = "change active in group" })
bind("SUPER SHIFT", "Tab", dispatch("changegroupactive", "b"), { description = "Change Group Back" })
bind("SUPER CTRL", "K", dispatch("moveintogroup", "l"), { description = "Move left into group" })
bind("SUPER CTRL", "L", dispatch("moveintogroup", "r"), { description = "Move Right into group" })
bind("SUPER CTRL", "H", dispatch("moveoutofgroup", ""), { description = "Move active out of group" })
bind("SUPER", "left", dispatch("movefocus", "l"), { description = "focus left" })
bind("SUPER", "right", dispatch("movefocus", "r"), { description = "focus right" })
bind("SUPER", "up", dispatch("movefocus", "u"), { description = "focus up" })
bind("SUPER", "down", dispatch("movefocus", "d"), { description = "focus down" })

-- Section: Workspace navigation and assignment
-- Keep legacy relative workspace focus script binds commented for rollback during Lua API migration.
-- Native workspace dispatch below replaces LuaFocusWorkspaceRelative.sh usage.
-- bind(
--   "SUPER",
--   "tab",
--   exec_cmd("$HOME/.config/hypr/scripts/LuaFocusWorkspaceRelative.sh next"),
--   { description = "next workspace" }
-- )
-- bind(
--   "SUPER SHIFT",
--   "tab",
--   exec_cmd("$HOME/.config/hypr/scripts/LuaFocusWorkspaceRelative.sh previous"),
--   { description = "previous workspace" }
-- )
bind("SUPER", "tab", dispatch("workspace", "e+1"), { description = "next workspace" })
bind("SUPER SHIFT", "tab", dispatch("workspace", "e-1"), { description = "previous workspace" })
bind("SUPER SHIFT", "U", dispatch("movetoworkspace", "special"), { description = "move to special workspace" })
bind("SUPER", "U", dispatch("togglespecialworkspace", ""), { description = "toggle special workspace" })
bind("SUPER", "code:10", dispatch("workspace", "1"), { description = "workspace 1" })
bind("SUPER", "code:11", dispatch("workspace", "2"), { description = "workspace 2" })
bind("SUPER", "code:12", dispatch("workspace", "3"), { description = "workspace 3" })
bind("SUPER", "code:13", dispatch("workspace", "4"), { description = "workspace 4" })
bind("SUPER", "code:14", dispatch("workspace", "5"), { description = "workspace 5" })
bind("SUPER", "code:15", dispatch("workspace", "6"), { description = "workspace 6" })
bind("SUPER", "code:16", dispatch("workspace", "7"), { description = "workspace 7" })
bind("SUPER", "code:17", dispatch("workspace", "8"), { description = "workspace 8" })
bind("SUPER", "code:18", dispatch("workspace", "9"), { description = "workspace 9" })
bind("SUPER", "code:19", dispatch("workspace", "10"), { description = "workspace 10" })
bind("SUPER SHIFT", "code:10", dispatch("movetoworkspace", "1"), { description = "move to workspace 1" })
bind("SUPER SHIFT", "code:11", dispatch("movetoworkspace", "2"), { description = "move to workspace 2" })
bind("SUPER SHIFT", "code:12", dispatch("movetoworkspace", "3"), { description = "move to workspace 3" })
bind("SUPER SHIFT", "code:13", dispatch("movetoworkspace", "4"), { description = "move to workspace 4" })
bind("SUPER SHIFT", "code:14", dispatch("movetoworkspace", "5"), { description = "move to workspace 5" })
bind("SUPER SHIFT", "code:15", dispatch("movetoworkspace", "6"), { description = "move to workspace 6" })
bind("SUPER SHIFT", "code:16", dispatch("movetoworkspace", "7"), { description = "move to workspace 7" })
bind("SUPER SHIFT", "code:17", dispatch("movetoworkspace", "8"), { description = "move to workspace 8" })
bind("SUPER SHIFT", "code:18", dispatch("movetoworkspace", "9"), { description = "move to workspace 9" })
bind("SUPER SHIFT", "code:19", dispatch("movetoworkspace", "10"), { description = "move to workspace 10" })
-- Keep legacy relative move-to-workspace script binds commented for rollback during Lua API migration.
-- Native movetoworkspace dispatch below replaces LuaMoveWindowWorkspaceRelative.sh usage.
-- bind(
--   "SUPER SHIFT",
--   "bracketleft",
--   exec_cmd("$HOME/.config/hypr/scripts/LuaMoveWindowWorkspaceRelative.sh previous"),
--   { description = "move to previous workspace" }
-- )
-- bind(
--   "SUPER SHIFT",
--   "bracketright",
--   exec_cmd("$HOME/.config/hypr/scripts/LuaMoveWindowWorkspaceRelative.sh next"),
--   { description = "move to next workspace" }
-- )
bind("SUPER SHIFT", "bracketleft", dispatch("movetoworkspace", "-1"), { description = "move to previous workspace" })
bind("SUPER SHIFT", "bracketright", dispatch("movetoworkspace", "+1"), { description = "move to next workspace" })
bind("SUPER CTRL", "code:10", dispatch("movetoworkspacesilent", "1"), { description = "move silently to workspace 1" })
bind("SUPER CTRL", "code:11", dispatch("movetoworkspacesilent", "2"), { description = "move silently to workspace 2" })
bind("SUPER CTRL", "code:12", dispatch("movetoworkspacesilent", "3"), { description = "move silently to workspace 3" })
bind("SUPER CTRL", "code:13", dispatch("movetoworkspacesilent", "4"), { description = "move silently to workspace 4" })
bind("SUPER CTRL", "code:14", dispatch("movetoworkspacesilent", "5"), { description = "move silently to workspace 5" })
bind("SUPER CTRL", "code:15", dispatch("movetoworkspacesilent", "6"), { description = "move silently to workspace 6" })
bind("SUPER CTRL", "code:16", dispatch("movetoworkspacesilent", "7"), { description = "move silently to workspace 7" })
bind("SUPER CTRL", "code:17", dispatch("movetoworkspacesilent", "8"), { description = "move silently to workspace 8" })
bind("SUPER CTRL", "code:18", dispatch("movetoworkspacesilent", "9"), { description = "move silently to workspace 9" })
bind(
  "SUPER CTRL",
  "code:19",
  dispatch("movetoworkspacesilent", "10"),
  { description = "move silently to workspace 10" }
)
-- Keep legacy silent relative move-to-workspace script binds commented for rollback during Lua API migration.
-- Native movetoworkspacesilent dispatch below replaces LuaMoveWindowWorkspaceRelative.sh usage.
-- bind(
--   "SUPER CTRL",
--   "bracketleft",
--   exec_cmd("$HOME/.config/hypr/scripts/LuaMoveWindowWorkspaceRelative.sh previous"),
--   { description = "move silently to previous workspace" }
-- )
-- bind(
--   "SUPER CTRL",
--   "bracketright",
--   exec_cmd("$HOME/.config/hypr/scripts/LuaMoveWindowWorkspaceRelative.sh next"),
--   { description = "move silently to next workspace" }
-- )
bind("SUPER CTRL", "bracketleft", dispatch("movetoworkspacesilent", "-1"), { description = "move silently to previous workspace" })
bind("SUPER CTRL", "bracketright", dispatch("movetoworkspacesilent", "+1"), { description = "move silently to next workspace" })
-- Keep legacy scroll/period/comma workspace focus script binds commented for rollback during Lua API migration.
-- Native workspace dispatch below replaces LuaFocusWorkspaceRelative.sh usage.
-- bind(
--   "SUPER",
--   "mouse_down",
--   exec_cmd("$HOME/.config/hypr/scripts/LuaFocusWorkspaceRelative.sh next"),
--   { description = "next workspace" }
-- )
-- bind(
--   "SUPER",
--   "mouse_up",
--   exec_cmd("$HOME/.config/hypr/scripts/LuaFocusWorkspaceRelative.sh previous"),
--   { description = "previous workspace" }
-- )
-- bind(
--   "SUPER",
--   "period",
--   exec_cmd("$HOME/.config/hypr/scripts/LuaFocusWorkspaceRelative.sh next"),
--   { description = "next workspace" }
-- )
-- bind(
--   "SUPER",
--   "comma",
--   exec_cmd("$HOME/.config/hypr/scripts/LuaFocusWorkspaceRelative.sh previous"),
--   { description = "previous workspace" }
-- )
bind("SUPER", "mouse_down", dispatch("workspace", "e+1"), { description = "next workspace" })
bind("SUPER", "mouse_up", dispatch("workspace", "e-1"), { description = "previous workspace" })
bind("SUPER", "period", dispatch("workspace", "e+1"), { description = "next workspace" })
bind("SUPER", "comma", dispatch("workspace", "e-1"), { description = "previous workspace" })

-- Section: Mouse drag/resize bindings
bindm("SUPER", "mouse:272", "movewindow", "move window")
bindm("SUPER", "mouse:273", "resizewindow", "resize window")
