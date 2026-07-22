-- ==================================================
--  KoolDots (2026)
--  Project URL: https://github.com/LinuxBeginnings
--  License: GNU GPLv3
--  SPDX-License-Identifier: GPL-3.0-or-later
-- ==================================================

-- System defaults migrated from configs/Keybinds.conf (auto-generated).
-- Add keybinds with bind("MODS", "KEY", fn, opts).
-- Example:
-- bind("SUPER", "Z", exec_cmd("thunar"), { description = "Open file manager" })

local dsp = hl.dsp or hl
local function resolve_cmd(cmd)
  local defaults = rawget(_G, "KOOLDOTS_DEFAULTS") or {}
  local resolved_term = defaults.term or os.getenv("TERMINAL") or "kitty"
  local resolved_files = defaults.files or "thunar"
  local resolved_edit = defaults.edit or os.getenv("EDITOR") or "nano"
  cmd = tostring(cmd)
  cmd = cmd:gsub("%$term", resolved_term)
  cmd = cmd:gsub("%$files", resolved_files)
  cmd = cmd:gsub("%$edit", resolved_edit)
  return cmd
end

local function exec_cmd(cmd)
  local resolved = resolve_cmd(cmd)
  if dsp and dsp.exec_cmd then
    return dsp.exec_cmd(resolved)
  end
  return function()
    hl.exec_cmd(resolved)
  end
end

local function shell_quote(value)
  return "'" .. tostring(value):gsub("'", "'\\''") .. "'"
end

local function raw_dispatch_cmd(command)
  if dsp and dsp.exec_raw then
    return dsp.exec_raw(tostring(command))
  end
  local expression = "hl.dsp.exec_raw(" .. string.format("%q", tostring(command)) .. ")"
  return exec_cmd("hyprctl dispatch " .. shell_quote(expression))
end

local function trim(value)
  return (value or ""):gsub("^%s+", ""):gsub("%s+$", "")
end

local function chord(mods, key)
  mods = trim(mods):gsub("%s+", " + ")
  key = trim(key)
  if mods == "" then
    return key
  end
  return mods .. " + " .. key
end

local function key_variants(key, mods)
  key = trim(key):gsub("^xf86", "XF86")
  local key_aliases = {
    XF86AudioPlayPause = "XF86AudioPlay",
    XF86audiolowervolume = "XF86AudioLowerVolume",
    XF86audiomute = "XF86AudioMute",
    XF86audioraisevolume = "XF86AudioRaiseVolume",
    XF86audiostop = "XF86AudioStop",
  }
  key = key_aliases[key] or key
  local shifted_number_keys = {
    ["code:10"] = "exclam",
    ["code:11"] = "at",
    ["code:12"] = "numbersign",
    ["code:13"] = "dollar",
    ["code:14"] = "percent",
    ["code:15"] = "asciicircum",
    ["code:16"] = "ampersand",
    ["code:17"] = "asterisk",
    ["code:18"] = "parenleft",
    ["code:19"] = "parenright",
  }
  local number_keys = {
    ["code:10"] = "1",
    ["code:11"] = "2",
    ["code:12"] = "3",
    ["code:13"] = "4",
    ["code:14"] = "5",
    ["code:15"] = "6",
    ["code:16"] = "7",
    ["code:17"] = "8",
    ["code:18"] = "9",
    ["code:19"] = "0",
  }
  if mods:match("SHIFT") and shifted_number_keys[key] then
    local number_key = number_keys[key]
    if number_key then
      return { shifted_number_keys[key], number_key }
    end
    return { shifted_number_keys[key] }
  end
  if number_keys[key] then
    return { number_keys[key] }
  end
  return { key }
end

local function workspace_value(value)
  value = trim(value)
  return tonumber(value) or value
end

local function direction(value)
  local directions = {
    l = "left",
    r = "right",
    u = "up",
    d = "down",
    left = "left",
    right = "right",
    up = "up",
    down = "down",
  }
  return directions[trim(value)] or trim(value)
end

local function dispatch(name, args)
  local window_api = (dsp and dsp.window) or hl.window or {}
  name = trim(name)
  args = trim(args)
  if name == "exec" then
    return exec_cmd(args)
  end
  if name == "killactive" and window_api.close then
    return window_api.close()
  end
  if name == "fullscreen" and window_api.fullscreen then
    if args == "1" then
      return window_api.fullscreen({ mode = "maximized" })
    end
    return window_api.fullscreen({ mode = "fullscreen" })
  end
  if name == "movefocus" and dsp and dsp.focus then
    return function()
      local ok, dispatcher = pcall(dsp.focus, { direction = direction(args) })
      if ok and dispatcher then
        hl.dispatch(dispatcher)
      end
    end
  end
  if name == "cyclenext" then
    if args == "prev" or args == "b" then
      return exec_cmd("$HOME/.config/hypr/scripts/LuaCycleWindow.sh previous")
    end
    return exec_cmd("$HOME/.config/hypr/scripts/LuaCycleWindow.sh next")
  end
  if name == "swapwindow" then
    local swap_direction = trim(args)
    if swap_direction == "" then
      return nil
    end
    return exec_cmd("$HOME/.config/hypr/scripts/LuaSwapWindow.sh " .. swap_direction)
  end
  if name == "workspace" and dsp and dsp.focus then
    return function()
      hl.dispatch(dsp.focus({ workspace = workspace_value(args) }))
    end
  end
  if name == "movetoworkspace" and window_api.move then
    return function()
      hl.dispatch(window_api.move({ workspace = workspace_value(args) }))
    end
  end
  if name == "movetoworkspacesilent" and window_api.move then
    return function()
      hl.dispatch(window_api.move({ workspace = workspace_value(args), follow = false }))
    end
  end
  if name == "togglefloating" and window_api.float then
    return function()
      hl.dispatch(window_api.float({ action = "toggle" }))
    end
  end
  if name == "resizewindow" and window_api.resize then
    return window_api.resize()
  end
  if name == "resizeactive" and window_api.resize then
    local x, y = args:match("^(%-?%d+)%s+(%-?%d+)$")
    if x and y then
      return window_api.resize({ x = tonumber(x) or 0, y = tonumber(y) or 0, relative = true })
    end
  end
  if name == "movewindow" and args == "" and window_api.drag then
    return window_api.drag()
  end
  if args ~= "" then
    return raw_dispatch_cmd(name .. " " .. args)
  end
  return raw_dispatch_cmd(name)
end

local function bind(mods, key, fn, opts)
  local seen = {}
  for _, key_variant in ipairs(key_variants(key, mods)) do
    local key_chord = chord(mods, key_variant)
    if not seen[key_chord] then
      seen[key_chord] = true
      if opts then
        hl.bind(key_chord, fn, opts)
      else
        hl.bind(key_chord, fn)
      end
    end
  end
end

local function unbind(mods, key)
  if hl.unbind then
    local seen = {}
    for _, key_variant in ipairs(key_variants(key, mods)) do
      local key_chord = chord(mods, key_variant)
      if not seen[key_chord] then
        seen[key_chord] = true
        local ok = pcall(hl.unbind, mods, key_variant)
        if not ok then
          pcall(hl.unbind, key_chord)
        end
      end
    end
  end
end

-- Converted from configs/Keybinds.conf
bind(
  "SUPER",
  "D",
  exec_cmd("pkill rofi || true; $HOME/.config/hypr/scripts/RofiFocusedWallpaperLink.sh >/dev/null 2>&1 || true; rofi -show drun -modi drun, filebrowser,run,window"),
  { description = "app launcher" }
)
bind("SUPER", "B", exec_cmd('xdg-open "https://"'), { description = "open default browser" })
bind("SUPER", "A", exec_cmd("$HOME/.config/hypr/scripts/OverviewToggle.sh"), { description = "desktop overview" })
bind(
  "SUPER",
  "Return",
  exec_cmd("$HOME/.config/hypr/scripts/LaunchTerminal.sh '$term'"),
  { description = "Open terminal" }
)
bind(
  "SUPER",
  "E",
  exec_cmd("$HOME/.config/hypr/scripts/LaunchFileManager.sh '$files' '$term'"),
  { description = "file manager" }
)
bind("SUPER", "C", exec_cmd("$HOME/.config/hypr/scripts/rofi-ssh-menu.sh"), { description = "SSH session manager" })
bind(
  "SUPER",
  "T",
  exec_cmd("$HOME/.config/hypr/scripts/ThemeChanger.sh"),
  { description = "Global theme switcher using Wallust" }
)
bind("SUPER", "H", exec_cmd("$HOME/.config/hypr/scripts/KeyHints.sh"), { description = "help / cheat sheet" })
bind("SUPER ALT", "R", exec_cmd("$HOME/.config/hypr/scripts/Refresh.sh"), { description = "refresh bar and menus" })
bind("SUPER ALT", "E", exec_cmd("$HOME/.config/hypr/scripts/RofiEmoji.sh"), { description = "emoji menu" })
bind("SUPER", "S", exec_cmd("$HOME/.config/hypr/scripts/RofiSearch.sh"), { description = "web search" })
bind(
  "SUPER CTRL",
  "S",
  exec_cmd("$HOME/.config/hypr/scripts/RofiFocusedWallpaperLink.sh >/dev/null 2>&1 || true; rofi -show window"),
  { description = "window switcher" }
)
bind("SUPER ALT", "O", exec_cmd("$HOME/.config/hypr/scripts/ChangeBlur.sh"), { description = "toggle blur" })
bind("SUPER SHIFT", "G", exec_cmd("$HOME/.config/hypr/scripts/GameMode.sh"), { description = "toggle game mode" })
bind(
  "SUPER ALT",
  "L",
  exec_cmd("$HOME/.config/hypr/scripts/ChangeLayout.sh toggle"),
  { description = "toggle layouts" }
)
bind("SUPER ALT", "V", exec_cmd("$HOME/.config/hypr/scripts/ClipManager.sh"), { description = "clipboard manager" })
bind(
  "SUPER CTRL",
  "R",
  exec_cmd("$HOME/.config/hypr/scripts/RofiThemeSelector.sh"),
  { description = "rofi theme selector" }
)
bind(
  "SUPER CTRL SHIFT",
  "R",
  exec_cmd("pkill rofi || true && $HOME/.config/hypr/scripts/RofiThemeSelector-modified.sh"),
  { description = "rofi theme selector (modified)" }
)
bind(
  "SUPER CTRL",
  "K",
  exec_cmd("$HOME/.config/hypr/scripts/Kitty_themes.sh"),
  { description = "Kitty theme selector" }
)
bind(
  "SUPER SHIFT",
  "B",
  exec_cmd("$HOME/.config/hypr/UserScripts/RainbowBorders-low-cpu.sh  --run-once"),
  { description = "Set static Rainbow Border" }
)
bind(
  "SUPER SHIFT",
  "H",
  exec_cmd("$HOME/.config/hypr/scripts/Toggle-Active-Window-Audio.sh"),
  { description = "Toggle Mute/Unmute for Active-Window" }
)
bind(
  "ALT SHIFT",
  "S",
  exec_cmd("$HOME/.config/hypr/scripts/hyprshot.sh -m region -o $HOME/Pictures/Screenshots"),
  { description = "Hyprshot Screen Capture" }
)
bind("SUPER SHIFT", "F", dispatch("fullscreen", ""), { description = "fullscreen" })
bind("SUPER", "F", dispatch("fullscreen", "1"), { description = "maximize window" })
bind("SUPER", "SPACE", dispatch("togglefloating", ""), { description = "Float current window" })
bind(
  "SUPER ALT",
  "SPACE",
  exec_cmd("$HOME/.config/hypr/scripts/Float-all-Windows.sh"),
  { description = "Float all windows" }
)
bind(
  "SUPER SHIFT",
  "Return",
  exec_cmd("$HOME/.config/hypr/scripts/Dropterminal.sh kitty"),
  { description = "DropDown terminal" }
)
bind(
  "SUPER ALT",
  "mouse_down",
  exec_cmd(
    "hyprctl keyword cursor:zoom_factor \"$(hyprctl getoption cursor:zoom_factor | awk 'NR==1 {factor = $2; if (factor < 1) {factor = 1}; print factor * 2.0}')\""
  ),
  { description = "zoom in" }
)
bind(
  "SUPER ALT",
  "mouse_up",
  exec_cmd(
    "hyprctl keyword cursor:zoom_factor \"$(hyprctl getoption cursor:zoom_factor | awk 'NR==1 {factor = $2; if (factor < 1) {factor = 1}; print factor / 2.0}')\""
  ),
  { description = "zoom out" }
)
bind("SUPER CTRL ALT", "B", exec_cmd("pkill -SIGUSR1 waybar"), { description = "toggle waybar on/off" })
bind("SUPER CTRL", "B", exec_cmd("$HOME/.config/hypr/scripts/WaybarStyles.sh"), { description = "waybar styles menu" })
bind("SUPER ALT", "B", exec_cmd("$HOME/.config/hypr/scripts/WaybarLayout.sh"), { description = "waybar layout menu" })
bind(
  "SUPER",
  "N",
  exec_cmd("$HOME/.config/hypr/scripts/Hyprsunset.sh toggle"),
  { description = "Toggle Hyprsunset - night light" }
)
bind("SUPER SHIFT", "M", exec_cmd("$HOME/.config/hypr/UserScripts/RofiBeats.sh"), { description = "online music" })
bind("SUPER", "W", exec_cmd("$HOME/.config/hypr/scripts/WallpaperSelect.sh"), { description = "select wallpaper" })
bind(
  "SUPER SHIFT",
  "W",
  exec_cmd("$HOME/.config/hypr/scripts/WallpaperEffects.sh"),
  { description = "wallpaper effects" }
)
bind(
  "CTRL ALT",
  "W",
  exec_cmd("$HOME/.config/hypr/UserScripts/WallpaperRandom.sh"),
  { description = "random wallpaper" }
)
bind("SUPER CTRL", "O", dispatch("setprop", "active opaque toggle"), { description = "toggle active window opacity" })
bind("SUPER SHIFT", "K", exec_cmd("$HOME/.config/hypr/scripts/KeyBinds.sh"), { description = "search keybinds" })
bind("SUPER SHIFT", "A", exec_cmd("$HOME/.config/hypr/scripts/Animations.sh"), { description = "animations menu" })
bind(
  "SUPER SHIFT",
  "R",
  exec_cmd("$HOME/.config/hypr/scripts/ZshChangeTheme.sh"),
  { description = "change oh-my-zsh theme" }
)
bind(
  "ALT_L",
  "SHIFT_L",
  exec_cmd("$HOME/.config/hypr/scripts/KeyboardLayout.sh switch"),
  { description = "switch keyboard layout globally", locked = true }
)
bind(
  "SHIFT_L",
  "ALT_L",
  exec_cmd("$HOME/.config/hypr/scripts/Tak0-Per-Window-Switch.sh"),
  { description = "switch keyboard layout per-window", locked = true }
)
bind("SUPER ALT", "C", exec_cmd("$HOME/.config/hypr/UserScripts/RofiCalc.sh"), { description = "calculator" })
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
bind("CTRL ALT", "Delete", exec_cmd("$HOME/.config/hypr/scripts/Logout.sh"), { description = "exit Hyprland" })
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
bind("SUPER CTRL", "D", dispatch("layoutmsg", "removemaster"), { description = "remove master" })
bind("SUPER", "I", dispatch("layoutmsg", "addmaster"), { description = "add master" })
bind(
  "SUPER",
  "j",
  exec_cmd("$HOME/.config/hypr/scripts/LayoutKeybindDispatch.sh cycle-next"),
  { description = "cycle next (layout-aware)" }
)
bind(
  "SUPER",
  "k",
  exec_cmd("$HOME/.config/hypr/scripts/LayoutKeybindDispatch.sh cycle-prev"),
  { description = "cycle previous (layout-aware)" }
)
bind("SUPER CTRL", "Return", dispatch("layoutmsg", "swapwithmaster"), { description = "swap with master" })
bind("SUPER SHIFT", "I", dispatch("layoutmsg", "togglesplit"), { description = "toggle split (dwindle)" })
bind("SUPER", "P", dispatch("pseudo", ""), { description = "toggle pseudo (dwindle)" })
bind("SUPER", "M", exec_cmd("hyprctl dispatch splitratio 0.3"), { description = "set split ratio 0.3" })
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
-- "smartgrid", "justified", "masonry", "bands", "hero", "spiral"
-- "satellite", "staggered", "columnar", "vortex", "random"
local qs_hyprview_layout = "smartgrid"
bind(
  "CTRL",
  "tab",
  exec_cmd("$HOME/.config/hypr/scripts/toggle-qs-hyprview.sh"),
  { description = "qs-hyprview toggle" }
)
bind("ALT", "Tab", dispatch("cyclenext", ""), { description = "cycle next window" })
bind("ALT", "Tab", dispatch("bringactivetotop", ""), { description = "bring active to top" })
bind(
  "",
  "xf86audioraisevolume",
  exec_cmd("$HOME/.config/hypr/scripts/Volume.sh --inc"),
  { description = "volume up", locked = true, ["repeat"] = true }
)
bind(
  "",
  "xf86audiolowervolume",
  exec_cmd("$HOME/.config/hypr/scripts/Volume.sh --dec"),
  { description = "volume down", locked = true, ["repeat"] = true }
)
bind(
  "ALT",
  "xf86audioraisevolume",
  exec_cmd("$HOME/.config/hypr/scripts/Volume.sh --inc-precise"),
  { description = "volume up precise", locked = true, ["repeat"] = true }
)
bind(
  "ALT",
  "xf86audiolowervolume",
  exec_cmd("$HOME/.config/hypr/scripts/Volume.sh --dec-precise"),
  { description = "volume down precise", locked = true, ["repeat"] = true }
)
bind(
  "",
  "xf86AudioMicMute",
  exec_cmd("$HOME/.config/hypr/scripts/Volume.sh --toggle-mic"),
  { description = "toggle mic mute", locked = true }
)
bind(
  "",
  "xf86audiomute",
  exec_cmd("$HOME/.config/hypr/scripts/Volume.sh --toggle"),
  { description = "toggle mute", locked = true }
)
bind("", "xf86Sleep", exec_cmd("systemctl suspend"), { description = "sleep", locked = true })
bind(
  "",
  "xf86Rfkill",
  exec_cmd("$HOME/.config/hypr/scripts/AirplaneMode.sh"),
  { description = "airplane mode", locked = true }
)
bind(
  "",
  "xf86AudioPlayPause",
  exec_cmd("$HOME/.config/hypr/scripts/MediaCtrl.sh --pause"),
  { description = "play/pause", locked = true }
)
bind(
  "",
  "xf86AudioPause",
  exec_cmd("$HOME/.config/hypr/scripts/MediaCtrl.sh --pause"),
  { description = "pause", locked = true }
)
bind(
  "",
  "xf86AudioPlay",
  exec_cmd("$HOME/.config/hypr/scripts/MediaCtrl.sh --pause"),
  { description = "play", locked = true }
)
bind(
  "",
  "xf86AudioNext",
  exec_cmd("$HOME/.config/hypr/scripts/MediaCtrl.sh --nxt"),
  { description = "next track", locked = true }
)
bind(
  "",
  "xf86AudioPrev",
  exec_cmd("$HOME/.config/hypr/scripts/MediaCtrl.sh --prv"),
  { description = "previous track", locked = true }
)
bind(
  "",
  "xf86audiostop",
  exec_cmd("$HOME/.config/hypr/scripts/MediaCtrl.sh --stop"),
  { description = "stop", locked = true }
)
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
bind("SUPER SHIFT", "left", dispatch("resizeactive", "-50 0"), { description = "resize left (-50)", ["repeat"] = true })
bind(
  "SUPER SHIFT",
  "right",
  dispatch("resizeactive", "50 0"),
  { description = "resize right (+50)", ["repeat"] = true }
)
bind("SUPER SHIFT", "up", dispatch("resizeactive", "0 -50"), { description = "resize up (-50)", ["repeat"] = true })
bind("SUPER SHIFT", "down", dispatch("resizeactive", "0 50"), { description = "resize down (+50)", ["repeat"] = true })
bind("SUPER CTRL", "left", dispatch("movewindow", "l"), { description = "move window left" })
bind("SUPER CTRL", "right", dispatch("movewindow", "r"), { description = "move window right" })
bind("SUPER CTRL", "up", dispatch("movewindow", "u"), { description = "move window up" })
bind("SUPER CTRL", "down", dispatch("movewindow", "d"), { description = "move window down" })
bind("SUPER ALT", "left", dispatch("swapwindow", "l"), { description = "swap window left" })
bind("SUPER ALT", "right", dispatch("swapwindow", "r"), { description = "swap window right" })
bind("SUPER ALT", "up", dispatch("swapwindow", "u"), { description = "swap window up" })
bind("SUPER ALT", "down", dispatch("swapwindow", "d"), { description = "swap window down" })
bind("SUPER", "G", dispatch("togglegroup", ""), { description = "toggle group" })
bind("SUPER", "Tab", dispatch("changegroupactive", "f"), { description = "Change Group Forward" })
bind("SUPER CTRL", "tab", dispatch("changegroupactive", ""), { description = "change active in group" })
bind("SUPER SHIFT", "Tab", dispatch("changegroupactive", "b"), { description = "Change Group Back" })
bind("SUPER CTRL", "K", dispatch("moveintogroup", "l"), { description = "Move left into group" })
bind("SUPER CTRL", "L", dispatch("moveintogroup", "r"), { description = "Move Right into group" })
bind("SUPER CTRL", "H", dispatch("moveoutofgroup", ""), { description = "Move active out of group" })
bind(
  "SUPER",
  "left",
  exec_cmd("$HOME/.config/hypr/scripts/LayoutKeybindDispatch.sh focus-left"),
  { description = "focus left (layout-aware)" }
)
bind(
  "SUPER",
  "right",
  exec_cmd("$HOME/.config/hypr/scripts/LayoutKeybindDispatch.sh focus-right"),
  { description = "focus right (layout-aware)" }
)
bind(
  "SUPER",
  "up",
  exec_cmd("$HOME/.config/hypr/scripts/LayoutKeybindDispatch.sh focus-up"),
  { description = "focus up (layout-aware)" }
)
bind(
  "SUPER",
  "down",
  exec_cmd("$HOME/.config/hypr/scripts/LayoutKeybindDispatch.sh focus-down"),
  { description = "focus down (layout-aware)" }
)
bind("SUPER", "tab", dispatch("workspace", "m+1"), { description = "next workspace" })
bind("SUPER SHIFT", "tab", dispatch("workspace", "m-1"), { description = "previous workspace" })
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
bind(
  "SUPER CTRL",
  "bracketleft",
  dispatch("movetoworkspacesilent", "-1"),
  { description = "move silently to previous workspace" }
)
bind(
  "SUPER CTRL",
  "bracketright",
  dispatch("movetoworkspacesilent", "+1"),
  { description = "move silently to next workspace" }
)
bind("SUPER", "mouse_down", dispatch("workspace", "e+1"), { description = "next workspace" })
bind("SUPER", "mouse_up", dispatch("workspace", "e-1"), { description = "previous workspace" })
bind("SUPER", "period", dispatch("workspace", "e+1"), { description = "next workspace" })
bind("SUPER", "comma", dispatch("workspace", "e-1"), { description = "previous workspace" })
bind("SUPER", "mouse:272", dispatch("movewindow", ""), { description = "move window" })
bind("SUPER", "mouse:273", dispatch("resizewindow", ""), { description = "resize window" })
