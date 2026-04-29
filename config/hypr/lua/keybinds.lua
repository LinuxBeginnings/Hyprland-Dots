-- Auto-generated from Keybinds.conf/UserKeybinds.conf for Lua testing
local function trim(value)
  return (value or ""):gsub("^%s+", ""):gsub("%s+$", "")
end
local dsp = hl.dsp or hl
local window_api = (dsp and dsp.window) or hl.window or {}
local workspace_api = (dsp and dsp.workspace) or {}
local group_api = (dsp and dsp.group) or {}

local function exec_cmd(cmd)
  if dsp and dsp.exec_cmd then
    return dsp.exec_cmd(cmd)
  end
  return function()
    hl.exec_cmd(cmd)
  end
end

local function shell_quote(value)
  return "'" .. tostring(value):gsub("'", "'\\''") .. "'"
end

local function raw_dispatch_cmd(command)
  local expression = "hl.dsp.exec_raw(" .. string.format("%q", tostring(command)) .. ")"
  return exec_cmd("hyprctl dispatch " .. shell_quote(expression))
end

local function exec_now(cmd)
  if dsp and dsp.exec_cmd and hl.dispatch then
    hl.dispatch(dsp.exec_cmd(cmd))
  elseif hl.dispatch and hl.exec_cmd then
    hl.dispatch(hl.exec_cmd(cmd))
  elseif hl.exec_cmd then
    hl.exec_cmd(cmd)
  end
end

local function workspace_dispatch(value)
  if dsp and dsp.focus then
    return function()
      hl.dispatch(dsp.focus({ workspace = value }))
    end
  end
  return raw_dispatch_cmd("workspace " .. tostring(value))
end

local known_dispatchers = {
  bringactivetotop = true,
  changegroupactive = true,
  cyclenext = true,
  fullscreen = true,
  killactive = true,
  layoutmsg = true,
  movefocus = true,
  moveintogroup = true,
  moveoutofgroup = true,
  movecurrentworkspacetomonitor = true,
  movetoworkspace = true,
  movetoworkspacesilent = true,
  movewindow = true,
  pseudo = true,
  resizeactive = true,
  setprop = true,
  swapwindow = true,
  togglegroup = true,
  togglefloating = true,
  togglespecialworkspace = true,
  workspace = true,
}
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

local function workspace_value(value)
  value = trim(value)
  return tonumber(value) or value
end
local function dispatch_safely(dispatcher)
  if dispatcher then
    pcall(hl.dispatch, dispatcher)
  end
end
local function dispatch_factory_safely(factory)
  pcall(function()
    local dispatcher = factory()
    if dispatcher then
      hl.dispatch(dispatcher)
    end
  end)
end

local function dispatch(name, args)
  name = trim(name)
  args = trim(args)

  if args:match("^exec%s*,") then
    return exec_cmd(trim(args:gsub("^exec%s*,", "", 1)))
  end

  if name == "exec" then
    return exec_cmd(args)
  end

  if known_dispatchers[args] and not known_dispatchers[name] then
    if args == "movewindow" and window_api.drag then
      return window_api.drag()
    end
    if args == "resizewindow" and window_api.resize then
      return window_api.resize()
    end
    return raw_dispatch_cmd(args)
  end

  if name == "killactive" and window_api.close then
    return window_api.close()
  end
  if name == "togglefloating" and window_api.float then
    return window_api.float({ action = "toggle" })
  end
  if name == "fullscreen" and window_api.fullscreen then
    if args == "1" then
      return window_api.fullscreen({ mode = "maximized" })
    end
    return window_api.fullscreen({ mode = "fullscreen" })
  end
  if name == "pseudo" and window_api.pseudo then
    return window_api.pseudo()
  end
  if name == "workspace" then
    return workspace_dispatch(workspace_value(args))
  end
  if name == "movetoworkspace" then
    if window_api.move then
      return function()
        hl.dispatch(window_api.move({ workspace = workspace_value(args) }))
      end
    end
    return raw_dispatch_cmd("movetoworkspace " .. args)
  end
  if name == "movetoworkspacesilent" then
    if window_api.move then
      return function()
        hl.dispatch(window_api.move({ workspace = workspace_value(args), follow = false }))
      end
    end
    return raw_dispatch_cmd("movetoworkspacesilent " .. args)
  end
  if name == "resizeactive" then
    return raw_dispatch_cmd("resizeactive " .. args)
  end
  if name == "movecurrentworkspacetomonitor" then
    return raw_dispatch_cmd("movecurrentworkspacetomonitor " .. args)
  end
  if name == "movefocus" then
    if dsp and dsp.focus then
      return function()
        dispatch_factory_safely(function()
          return dsp.focus({ direction = direction(args) })
        end)
      end
    end
    return raw_dispatch_cmd("movefocus " .. args)
  end
  if name == "movewindow" then
    if window_api.move then
      return function()
        dispatch_factory_safely(function()
          return window_api.move({ direction = direction(args) })
        end)
      end
    end
    return raw_dispatch_cmd("movewindow " .. args)
  end
  if name == "swapwindow" then
    local swap_direction = trim(args)
    if swap_direction == "" then
      return nil
    end
    return exec_cmd("$HOME/.config/hypr/scripts/LuaSwapWindow.sh " .. swap_direction)
  end
  if name == "togglegroup" and group_api.toggle then
    return group_api.toggle()
  end
  if name == "changegroupactive" and group_api.next and group_api.prev then
    if args == "b" or args == "prev" or args == "-1" then
      return group_api.prev()
    end
    return group_api.next()
  end
  if name == "moveintogroup" and window_api.move then
    return window_api.move({ into_group = direction(args) })
  end
  if name == "moveoutofgroup" and window_api.move then
    return window_api.move({ out_of_group = true })
  end
  if name == "layoutmsg" and dsp and dsp.layout then
    return dsp.layout(args)
  end
  if name == "bringactivetotop" and window_api.bring_to_top then
    return window_api.bring_to_top()
  end
  if name == "setprop" and window_api.set_prop then
    local prop, value = args:match("^(%S+)%s+(.+)$")
    if prop and value then
      return window_api.set_prop({ prop = prop, value = value })
    end
  end

  if args ~= "" then
    return raw_dispatch_cmd(name .. " " .. args)
  end
  return raw_dispatch_cmd(name)
end

local function chord(mods, key)
  mods = trim(mods):gsub("%s+", " + ")
  key = trim(key)
  key = key:gsub("^xf86", "XF86")
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
    key = shifted_number_keys[key]
  else
    key = number_keys[key] or key
  end
  if mods == "" then
    return key
  end
  return mods .. " + " .. key
end
local function bind(mods, key, fn, opts)
  if opts and opts.mouse then
    return
  end
  if opts then
    hl.bind(chord(mods, key), fn, opts)
  else
    hl.bind(chord(mods, key), fn)
  end
  if mods:match("SHIFT") then
    local number_key = ({
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
    })[key]
    if number_key then
      if opts then
        hl.bind(chord(mods, number_key), fn, opts)
      else
        hl.bind(chord(mods, number_key), fn)
      end
    end
  end
end
local function unbind_chord(key_chord)
  if hl.unbind then
    pcall(hl.unbind, key_chord)
  end
end
local function bindm(mods, key, dispatcher, description)
  bind(mods, key, dispatch("mouse " .. dispatcher, dispatcher), { description = description })
end
-- Mass unbind defaults before rebuilding the Lua keymap.
local keys_to_unbind = {
  "SUPER + V",
  "SUPER + W",
  "SUPER + P",
  "SUPER + N",
  "SUPER + T",
  "SUPER + X",
  "SUPER + CTRL + S",
  "SUPER + G",
  "SUPER + ALT + S",
  "SUPER + F",
  "SUPER + ALT + F",
  "SUPER + CTRL + F",
  "SUPER + CTRL + A",
  "SUPER + CTRL + B",
  "SUPER + CTRL + W",
  "SUPER + CTRL + T",
  "ALT + TAB",
  "SUPER + mouse_down",
  "SUPER + mouse_up",
  "SUPER + SLASH",
  "SUPER + code:61",
  "SUPER + ALT + code:61",
}
for _, key in ipairs(keys_to_unbind) do
  unbind_chord(key)
end

-- Application and script binds.
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

-- Manual actions kept explicit for clarity.
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
bind("CTRL ALT", "Delete", raw_dispatch_cmd("exit 0"), { description = "exit Hyprland" })
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
bind("SUPER SHIFT", "left", dispatch("resizeactive", "-50 0"), { description = "resize left (-50)" })
bind("SUPER SHIFT", "right", dispatch("resizeactive", "50 0"), { description = "resize right (+50)" })
bind("SUPER SHIFT", "up", dispatch("resizeactive", "0 -50"), { description = "resize up (-50)" })
bind("SUPER SHIFT", "down", dispatch("resizeactive", "0 50"), { description = "resize down (+50)" })
bind(
  "SUPER CTRL",
  "left",
  exec_cmd("$HOME/.config/hypr/scripts/LuaMoveWindowDirectional.sh left"),
  { description = "move window left" }
)
bind(
  "SUPER CTRL",
  "right",
  exec_cmd("$HOME/.config/hypr/scripts/LuaMoveWindowDirectional.sh right"),
  { description = "move window right" }
)
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
bind(
  "SUPER",
  "tab",
  exec_cmd("$HOME/.config/hypr/scripts/LuaFocusWorkspaceRelative.sh next"),
  { description = "next workspace" }
)
bind(
  "SUPER SHIFT",
  "tab",
  exec_cmd("$HOME/.config/hypr/scripts/LuaFocusWorkspaceRelative.sh previous"),
  { description = "previous workspace" }
)
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
bind(
  "SUPER SHIFT",
  "bracketleft",
  exec_cmd("$HOME/.config/hypr/scripts/LuaMoveWindowWorkspaceRelative.sh previous"),
  { description = "move to previous workspace" }
)
bind(
  "SUPER SHIFT",
  "bracketright",
  exec_cmd("$HOME/.config/hypr/scripts/LuaMoveWindowWorkspaceRelative.sh next"),
  { description = "move to next workspace" }
)
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
  exec_cmd("$HOME/.config/hypr/scripts/LuaMoveWindowWorkspaceRelative.sh previous"),
  { description = "move silently to previous workspace" }
)
bind(
  "SUPER CTRL",
  "bracketright",
  exec_cmd("$HOME/.config/hypr/scripts/LuaMoveWindowWorkspaceRelative.sh next"),
  { description = "move silently to next workspace" }
)
bind(
  "SUPER",
  "mouse_down",
  exec_cmd("$HOME/.config/hypr/scripts/LuaFocusWorkspaceRelative.sh next"),
  { description = "next workspace" }
)
bind(
  "SUPER",
  "mouse_up",
  exec_cmd("$HOME/.config/hypr/scripts/LuaFocusWorkspaceRelative.sh previous"),
  { description = "previous workspace" }
)
bind(
  "SUPER",
  "period",
  exec_cmd("$HOME/.config/hypr/scripts/LuaFocusWorkspaceRelative.sh next"),
  { description = "next workspace" }
)
bind(
  "SUPER",
  "comma",
  exec_cmd("$HOME/.config/hypr/scripts/LuaFocusWorkspaceRelative.sh previous"),
  { description = "previous workspace" }
)
bindm("SUPER", "mouse:272", "movewindow", "move window")
bindm("SUPER", "mouse:273", "resizewindow", "resize window")
