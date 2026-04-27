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
  return function() hl.exec_cmd(cmd) end
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
    return function() hl.dispatch(dsp.focus({ workspace = value })) end
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
      return function() hl.dispatch(window_api.move({ workspace = workspace_value(args) })) end
    end
    return raw_dispatch_cmd("movetoworkspace " .. args)
  end
  if name == "movetoworkspacesilent" then
    if window_api.move then
      return function() hl.dispatch(window_api.move({ workspace = workspace_value(args), follow = false })) end
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
      return function() dispatch_factory_safely(function() return dsp.focus({ direction = direction(args) }) end) end
    end
    return raw_dispatch_cmd("movefocus " .. args)
  end
  if name == "movewindow" then
    if window_api.move then
      return function() dispatch_factory_safely(function() return window_api.move({ direction = direction(args) }) end) end
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
local function bindm(mods, key, dispatcher)
  bind(mods, key, dispatch("mouse " .. dispatcher, dispatcher))
end
bind("SUPER", "D", exec_cmd("pkill rofi || true && rofi -show drun -modi drun,filebrowser,run,window"))
bind("SUPER", "B", exec_cmd("xdg-open \"https://\""))
bind("SUPER", "A", exec_cmd("$HOME/.config/hypr/scripts/OverviewToggle.sh"))
bind("SUPER", "Return", exec_cmd("kitty"))
bind("SUPER", "E", exec_cmd("thunar"))
bind("SUPER", "C", exec_cmd("$HOME/.config/hypr/scripts/rofi-ssh-menu.sh"))
bind("SUPER", "T", exec_cmd("$HOME/.config/hypr/scripts/ThemeChanger.sh"))
bind("SUPER", "H", exec_cmd("$HOME/.config/hypr/scripts/KeyHints.sh"))
bind("SUPER ALT", "R", exec_cmd("$HOME/.config/hypr/scripts/Refresh.sh"))
bind("SUPER ALT", "E", exec_cmd("$HOME/.config/hypr/scripts/RofiEmoji.sh"))
bind("SUPER", "S", exec_cmd("$HOME/.config/hypr/scripts/RofiSearch.sh"))
bind("SUPER CTRL", "S", exec_cmd("rofi -show window"))
bind("SUPER ALT", "O", exec_cmd("$HOME/.config/hypr/scripts/ChangeBlur.sh"))
bind("SUPER SHIFT", "G", exec_cmd("$HOME/.config/hypr/scripts/GameMode.sh"))
bind("SUPER ALT", "L", exec_cmd("$HOME/.config/hypr/scripts/ChangeLayout.sh toggle"))
bind("SUPER ALT", "V", exec_cmd("$HOME/.config/hypr/scripts/ClipManager.sh"))
bind("SUPER CTRL", "R", exec_cmd("$HOME/.config/hypr/scripts/RofiThemeSelector.sh"))
bind("SUPER CTRL SHIFT", "R", exec_cmd("pkill rofi || true && $HOME/.config/hypr/scripts/RofiThemeSelector-modified.sh"))
bind("SUPER CTRL", "K", exec_cmd("$HOME/.config/hypr/scripts/Kitty_themes.sh"))
bind("SUPER SHIFT", "B", exec_cmd("$HOME/.config/hypr/UserScripts/RainbowBorders-low-cpu.sh  --run-once"))
bind("SUPER SHIFT", "H", exec_cmd("$HOME/.config/hypr/scripts/Toggle-Active-Window-Audio.sh"))
bind("ALT SHIFT", "S", exec_cmd("$HOME/.config/hypr/scripts/hyprshot.sh -m region -o $HOME/Pictures/Screenshots"))
bind("SUPER SHIFT", "F", dispatch("fullscreen", ""))
bind("SUPER CTRL", "F", dispatch("fullscreen", "1"))
bind("SUPER", "SPACE", dispatch("togglefloating", ""))
bind("SUPER ALT", "SPACE", exec_cmd("$HOME/.config/hypr/scripts/Float-all-Windows.sh"))
bind("SUPER SHIFT", "Return", exec_cmd("$HOME/.config/hypr/scripts/Dropterminal.sh kitty"))
bind("SUPER ALT", "mouse_down", exec_cmd("hyprctl keyword cursor:zoom_factor \"$(hyprctl getoption cursor:zoom_factor | awk 'NR==1 {factor = $2; if (factor < 1) {factor = 1}; print factor * 2.0}')\""))
bind("SUPER ALT", "mouse_up", exec_cmd("hyprctl keyword cursor:zoom_factor \"$(hyprctl getoption cursor:zoom_factor | awk 'NR==1 {factor = $2; if (factor < 1) {factor = 1}; print factor / 2.0}')\""))
bind("SUPER CTRL ALT", "B", exec_cmd("pkill -SIGUSR1 waybar"))
bind("SUPER CTRL", "B", exec_cmd("$HOME/.config/hypr/scripts/WaybarStyles.sh"))
bind("SUPER ALT", "B", exec_cmd("$HOME/.config/hypr/scripts/WaybarLayout.sh"))
bind("SUPER", "N", exec_cmd("$HOME/.config/hypr/scripts/Hyprsunset.sh toggle"))
bind("SUPER SHIFT", "M", exec_cmd("$HOME/.config/hypr/UserScripts/RofiBeats.sh"))
bind("SUPER", "W", exec_cmd("$HOME/.config/hypr/UserScripts/WallpaperSelect.sh"))
bind("SUPER SHIFT", "W", exec_cmd("$HOME/.config/hypr/UserScripts/WallpaperEffects.sh"))
bind("CTRL ALT", "W", exec_cmd("$HOME/.config/hypr/UserScripts/WallpaperRandom.sh"))
bind("SUPER CTRL", "O", dispatch("setprop", "active opaque toggle"))
bind("SUPER SHIFT", "K", exec_cmd("$HOME/.config/hypr/scripts/KeyBinds.sh"))
bind("SUPER SHIFT", "A", exec_cmd("$HOME/.config/hypr/scripts/Animations.sh"))
bind("SUPER SHIFT", "O", exec_cmd("$HOME/.config/hypr/UserScripts/ZshChangeTheme.sh"))
bind("ALT_L", "SHIFT_L", dispatch("switch keyboard layout globally", "exec, $HOME/.config/hypr/scripts/KeyboardLayout.sh switch"), { locked = true })
bind("SHIFT_L", "ALT_L", dispatch("switch keyboard layout per-window", "exec, $HOME/.config/hypr/scripts/Tak0-Per-Window-Switch.sh"), { locked = true })
bind("SUPER ALT", "C", exec_cmd("$HOME/.config/hypr/UserScripts/RofiCalc.sh"))
bind("SUPER CTRL", "F9", dispatch("movecurrentworkspacetomonitor", "l"))
bind("SUPER CTRL", "F10", dispatch("movecurrentworkspacetomonitor", "r"))
bind("SUPER CTRL", "F11", dispatch("movecurrentworkspacetomonitor", "u"))
bind("SUPER CTRL", "F12", dispatch("movecurrentworkspacetomonitor", "d"))
bind("CTRL ALT", "Delete", raw_dispatch_cmd("exit 0"))
bind("SUPER", "Q", dispatch("killactive", ""))
bind("SUPER SHIFT", "Q", exec_cmd("$HOME/.config/hypr/scripts/KillActiveProcess.sh"))
bind("CTRL ALT", "L", exec_cmd("$HOME/.config/hypr/scripts/LockScreen.sh"))
bind("CTRL ALT", "P", exec_cmd("$HOME/.config/hypr/scripts/Wlogout.sh"))
bind("SUPER SHIFT", "N", exec_cmd("swaync-client -t -sw"))
bind("SUPER SHIFT", "E", exec_cmd("$HOME/.config/hypr/scripts/Kool_Quick_Settings.sh"))
bind("SUPER CTRL", "D", dispatch("layoutmsg", "removemaster"))
bind("SUPER", "I", dispatch("layoutmsg", "addmaster"))
bind("SUPER", "j", exec_cmd("$HOME/.config/hypr/scripts/LuaCycleWindow.sh next"))
bind("SUPER", "k", exec_cmd("$HOME/.config/hypr/scripts/LuaCycleWindow.sh previous"))
bind("SUPER CTRL", "Return", dispatch("layoutmsg", "swapwithmaster"))
bind("SUPER SHIFT", "I", dispatch("layoutmsg", "togglesplit"))
bind("SUPER", "P", dispatch("pseudo", ""))
bind("SUPER", "M", raw_dispatch_cmd("splitratio 0.3"))
bind("SUPER ALT", "1", exec_cmd("$HOME/.config/hypr/scripts/ChangeLayout.sh dwindle"))
bind("SUPER ALT", "2", exec_cmd("$HOME/.config/hypr/scripts/ChangeLayout.sh master"))
bind("SUPER ALT", "3", exec_cmd("$HOME/.config/hypr/scripts/ChangeLayout.sh scrolling"))
bind("SUPER ALT", "4", exec_cmd("$HOME/.config/hypr/scripts/ChangeLayout.sh monocle"))
bind("SUPER SHIFT", "period", dispatch("layoutmsg", "move +col"))
bind("SUPER SHIFT", "comma", dispatch("layoutmsg", "move -col"))
bind("SUPER ALT", "comma", dispatch("layoutmsg", "swapcol l"))
bind("SUPER ALT", "period", dispatch("layoutmsg", "swapcol r"))
bind("SUPER ALT", "H", exec_cmd("hyprctl keyword scrolling:direction right"))
bind("SUPER ALT", "V", exec_cmd("hyprctl keyword scrolling:direction down"))
bind("SUPER ALT", "S", exec_cmd("bash -c '[[ $(hyprctl getoption scrolling:direction -j | jq -r \".str\") == \"right\" ]] && hyprctl keyword scrolling:direction down || hyprctl keyword scrolling:direction right'"))
bind("ALT", "Tab", exec_cmd("$HOME/.config/hypr/scripts/LuaCycleWindow.sh next"))
bind("", "xf86audioraisevolume", dispatch("volume up", "exec, $HOME/.config/hypr/scripts/Volume.sh --inc"))
bind("", "xf86audiolowervolume", dispatch("volume down", "exec, $HOME/.config/hypr/scripts/Volume.sh --dec"))
bind("ALT", "xf86audioraisevolume", dispatch("volume up precise", "exec, $HOME/.config/hypr/scripts/Volume.sh --inc-precise"))
bind("ALT", "xf86audiolowervolume", dispatch("volume down precise", "exec, $HOME/.config/hypr/scripts/Volume.sh --dec-precise"))
bind("", "xf86AudioMicMute", dispatch("toggle mic mute", "exec, $HOME/.config/hypr/scripts/Volume.sh --toggle-mic"), { locked = true })
bind("", "xf86audiomute", dispatch("toggle mute", "exec, $HOME/.config/hypr/scripts/Volume.sh --toggle"), { locked = true })
bind("", "xf86Sleep", dispatch("sleep", "exec, systemctl suspend"), { locked = true })
bind("", "xf86Rfkill", dispatch("airplane mode", "exec, $HOME/.config/hypr/scripts/AirplaneMode.sh"), { locked = true })
bind("", "xf86AudioPlayPause", dispatch("play/pause", "exec, $HOME/.config/hypr/scripts/MediaCtrl.sh --pause"), { locked = true })
bind("", "xf86AudioPause", dispatch("pause", "exec, $HOME/.config/hypr/scripts/MediaCtrl.sh --pause"), { locked = true })
bind("", "xf86AudioPlay", dispatch("play", "exec, $HOME/.config/hypr/scripts/MediaCtrl.sh --pause"), { locked = true })
bind("", "xf86AudioNext", dispatch("next track", "exec, $HOME/.config/hypr/scripts/MediaCtrl.sh --nxt"), { locked = true })
bind("", "xf86AudioPrev", dispatch("previous track", "exec, $HOME/.config/hypr/scripts/MediaCtrl.sh --prv"), { locked = true })
bind("", "xf86audiostop", dispatch("stop", "exec, $HOME/.config/hypr/scripts/MediaCtrl.sh --stop"), { locked = true })
bind("SUPER", "Print", exec_cmd("$HOME/.config/hypr/scripts/ScreenShot.sh --now"))
bind("SUPER SHIFT", "Print", exec_cmd("$HOME/.config/hypr/scripts/ScreenShot.sh --area"))
bind("SUPER CTRL", "Print", exec_cmd("$HOME/.config/hypr/scripts/ScreenShot.sh --in5"))
bind("SUPER CTRL SHIFT", "Print", exec_cmd("$HOME/.config/hypr/scripts/ScreenShot.sh --in10"))
bind("ALT", "Print", exec_cmd("$HOME/.config/hypr/scripts/ScreenShot.sh --active"))
bind("SUPER SHIFT", "S", exec_cmd("$HOME/.config/hypr/scripts/ScreenShot.sh --swappy"))
bind("SUPER SHIFT", "left", dispatch("resizeactive", "-50 0"))
bind("SUPER SHIFT", "right", dispatch("resizeactive", "50 0"))
bind("SUPER SHIFT", "up", dispatch("resizeactive", "0 -50"))
bind("SUPER SHIFT", "down", dispatch("resizeactive", "0 50"))
bind("SUPER CTRL", "left", exec_cmd("$HOME/.config/hypr/scripts/LuaMoveWindowDirectional.sh left"))
bind("SUPER CTRL", "right", exec_cmd("$HOME/.config/hypr/scripts/LuaMoveWindowDirectional.sh right"))
bind("SUPER CTRL", "up", dispatch("movewindow", "u"))
bind("SUPER CTRL", "down", dispatch("movewindow", "d"))
bind("SUPER ALT", "left", exec_cmd("$HOME/.config/hypr/scripts/LuaSwapWindow.sh l"))
bind("SUPER ALT", "right", exec_cmd("$HOME/.config/hypr/scripts/LuaSwapWindow.sh r"))
bind("SUPER ALT", "up", exec_cmd("$HOME/.config/hypr/scripts/LuaSwapWindow.sh u"))
bind("SUPER ALT", "down", exec_cmd("$HOME/.config/hypr/scripts/LuaSwapWindow.sh d"))
bind("SUPER", "G", dispatch("togglegroup", ""))
bind("SUPER", "Tab", dispatch("changegroupactive", "f"))
bind("SUPER CTRL", "tab", dispatch("changegroupactive", ""))
bind("SUPER SHIFT", "Tab", dispatch("changegroupactive", "b"))
bind("SUPER CTRL", "K", dispatch("moveintogroup", "l"))
bind("SUPER CTRL", "L", dispatch("moveintogroup", "r"))
bind("SUPER CTRL", "H", dispatch("moveoutofgroup", ""))
bind("SUPER", "left", dispatch("movefocus", "l"))
bind("SUPER", "right", dispatch("movefocus", "r"))
bind("SUPER", "up", dispatch("movefocus", "u"))
bind("SUPER", "down", dispatch("movefocus", "d"))
bind("SUPER", "tab", exec_cmd("$HOME/.config/hypr/scripts/LuaFocusWorkspaceRelative.sh next"))
bind("SUPER SHIFT", "tab", exec_cmd("$HOME/.config/hypr/scripts/LuaFocusWorkspaceRelative.sh previous"))
bind("SUPER SHIFT", "U", dispatch("movetoworkspace", "special"))
bind("SUPER", "U", dispatch("togglespecialworkspace", ""))
bind("SUPER", "code:10", dispatch("workspace", "1"))
bind("SUPER", "code:11", dispatch("workspace", "2"))
bind("SUPER", "code:12", dispatch("workspace", "3"))
bind("SUPER", "code:13", dispatch("workspace", "4"))
bind("SUPER", "code:14", dispatch("workspace", "5"))
bind("SUPER", "code:15", dispatch("workspace", "6"))
bind("SUPER", "code:16", dispatch("workspace", "7"))
bind("SUPER", "code:17", dispatch("workspace", "8"))
bind("SUPER", "code:18", dispatch("workspace", "9"))
bind("SUPER", "code:19", dispatch("workspace", "10"))
bind("SUPER SHIFT", "code:10", dispatch("movetoworkspace", "1"))
bind("SUPER SHIFT", "code:11", dispatch("movetoworkspace", "2"))
bind("SUPER SHIFT", "code:12", dispatch("movetoworkspace", "3"))
bind("SUPER SHIFT", "code:13", dispatch("movetoworkspace", "4"))
bind("SUPER SHIFT", "code:14", dispatch("movetoworkspace", "5"))
bind("SUPER SHIFT", "code:15", dispatch("movetoworkspace", "6"))
bind("SUPER SHIFT", "code:16", dispatch("movetoworkspace", "7"))
bind("SUPER SHIFT", "code:17", dispatch("movetoworkspace", "8"))
bind("SUPER SHIFT", "code:18", dispatch("movetoworkspace", "9"))
bind("SUPER SHIFT", "code:19", dispatch("movetoworkspace", "10"))
bind("SUPER SHIFT", "bracketleft", exec_cmd("$HOME/.config/hypr/scripts/LuaMoveWindowWorkspaceRelative.sh previous"))
bind("SUPER SHIFT", "bracketright", exec_cmd("$HOME/.config/hypr/scripts/LuaMoveWindowWorkspaceRelative.sh next"))
bind("SUPER CTRL", "code:10", dispatch("movetoworkspacesilent", "1"))
bind("SUPER CTRL", "code:11", dispatch("movetoworkspacesilent", "2"))
bind("SUPER CTRL", "code:12", dispatch("movetoworkspacesilent", "3"))
bind("SUPER CTRL", "code:13", dispatch("movetoworkspacesilent", "4"))
bind("SUPER CTRL", "code:14", dispatch("movetoworkspacesilent", "5"))
bind("SUPER CTRL", "code:15", dispatch("movetoworkspacesilent", "6"))
bind("SUPER CTRL", "code:16", dispatch("movetoworkspacesilent", "7"))
bind("SUPER CTRL", "code:17", dispatch("movetoworkspacesilent", "8"))
bind("SUPER CTRL", "code:18", dispatch("movetoworkspacesilent", "9"))
bind("SUPER CTRL", "code:19", dispatch("movetoworkspacesilent", "10"))
bind("SUPER CTRL", "bracketleft", exec_cmd("$HOME/.config/hypr/scripts/LuaMoveWindowWorkspaceRelative.sh previous"))
bind("SUPER CTRL", "bracketright", exec_cmd("$HOME/.config/hypr/scripts/LuaMoveWindowWorkspaceRelative.sh next"))
bind("SUPER", "mouse_down", exec_cmd("$HOME/.config/hypr/scripts/LuaFocusWorkspaceRelative.sh next"))
bind("SUPER", "mouse_up", exec_cmd("$HOME/.config/hypr/scripts/LuaFocusWorkspaceRelative.sh previous"))
bind("SUPER", "period", exec_cmd("$HOME/.config/hypr/scripts/LuaFocusWorkspaceRelative.sh next"))
bind("SUPER", "comma", exec_cmd("$HOME/.config/hypr/scripts/LuaFocusWorkspaceRelative.sh previous"))
bindm("SUPER", "mouse:272", "movewindow")
bindm("SUPER", "mouse:273", "resizewindow")
