local M = {}

local function trim(value)
  return (value or ""):gsub("^%s+", ""):gsub("%s+$", "")
end
local dsp = hl.dsp or hl
local window_api = (dsp and dsp.window) or hl.window or {}
local workspace_api = (dsp and dsp.workspace) or {}
local group_api = (dsp and dsp.group) or {}

local function resolve_cmd(cmd)
  local defaults = rawget(_G, "KOOLDOTS_DEFAULTS") or {}
  local resolved_term = defaults.term or os.getenv("TERMINAL") or "kitty"
  local resolved_files = defaults.files or "thunar"
  local resolved_edit = defaults.edit or os.getenv("EDITOR") or "nano"
  local resolved_visual = defaults.visual or os.getenv("VISUAL") or ""
  cmd = tostring(cmd)
  cmd = cmd:gsub("%$term", resolved_term)
  cmd = cmd:gsub("%$files", resolved_files)
  cmd = cmd:gsub("%$edit", resolved_edit)
  cmd = cmd:gsub("%$visual", resolved_visual)
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

  if name == "killactive" then
    if window_api.close then
      return function()
        hl.dispatch(window_api.close())
      end
    end
    if window_api.kill then
      return function()
        hl.dispatch(window_api.kill())
      end
    end
    return raw_dispatch_cmd("killactive")
  end
  if name == "togglefloating" and window_api.float then
    return function()
      hl.dispatch(window_api.float({ action = "toggle" }))
    end
  end
  if name == "fullscreen" then
    if window_api.fullscreen then
      if args == "1" then
        return function()
          hl.dispatch(window_api.fullscreen({ mode = "maximized" }))
        end
      end
      return function()
        hl.dispatch(window_api.fullscreen({ mode = "fullscreen" }))
      end
    end
    if args == "1" then
      return exec_cmd("hyprctl dispatch 'hl.dsp.window.fullscreen({ mode = \\\"maximized\\\" })'")
    end
    return exec_cmd("hyprctl dispatch 'hl.dsp.window.fullscreen({ mode = \\\"fullscreen\\\" })'")
  end
  if name == "pseudo" and window_api.pseudo then
    return function()
      hl.dispatch(window_api.pseudo())
    end
  end
  if name == "workspace" then
    return workspace_dispatch(workspace_value(args))
  end
  if name == "movetoworkspace" then
    if args == "special" or args:match("^special:") then
      return function()
        local win = hl.get_active_window and hl.get_active_window()
        local ws = win and win.workspace
        -- If active window is already in a special workspace, move it back to the current active regular workspace
        if ws and (ws.special == true or (type(ws.name) == "string" and ws.name:match("^special"))) then
          local mon = hl.get_active_monitor and hl.get_active_monitor()
          local active_ws = hl.get_active_workspace and hl.get_active_workspace(mon and mon.id)
          local target_id = (active_ws and not active_ws.special and active_ws.id) or "+0"
          if window_api.move then
            hl.dispatch(window_api.move({ workspace = target_id }))
          else
            hl.dispatch(dsp.exec_raw("movetoworkspace " .. tostring(target_id)))
          end
          return
        end
        if window_api.move then
          hl.dispatch(window_api.move({ workspace = workspace_value(args) }))
        else
          hl.dispatch(dsp.exec_raw("movetoworkspace " .. args))
        end
      end
    end
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
    return function()
      hl.dispatch(group_api.toggle())
    end
  end
  if name == "changegroupactive" and group_api.next and group_api.prev then
    if args == "b" or args == "prev" or args == "-1" then
      return function()
        hl.dispatch(group_api.prev())
      end
    end
    return function()
      hl.dispatch(group_api.next())
    end
  end
  if name == "moveintogroup" and window_api.move then
    return function()
      hl.dispatch(window_api.move({ into_group = direction(args) }))
    end
  end
  if name == "moveoutofgroup" and window_api.move then
    return function()
      hl.dispatch(window_api.move({ out_of_group = true }))
    end
  end
  if (name == "layoutmsg" or name == "layout") and dsp and dsp.layout then
    return function()
      dispatch_factory_safely(function()
        return dsp.layout(args)
      end)
    end
  end
  if name == "togglesplit" and dsp and dsp.layout then
    return function()
      dispatch_factory_safely(function()
        return dsp.layout("togglesplit")
      end)
    end
  end
  if name == "togglespecialworkspace" then
    if workspace_api and workspace_api.toggle_special then
      return function()
        dispatch_factory_safely(function()
          if args ~= "" then
            return workspace_api.toggle_special({ name = args })
          end
          return workspace_api.toggle_special()
        end)
      end
    end
    if args ~= "" then
      return raw_dispatch_cmd("togglespecialworkspace " .. args)
    end
    return raw_dispatch_cmd("togglespecialworkspace")
  end
  if name == "bringactivetotop" and window_api.bring_to_top then
    return function()
      hl.dispatch(window_api.bring_to_top())
    end
  end
  if name == "setprop" and window_api.set_prop then
    local _win, prop, value = args:match("^(%S+)%s+(%S+)%s+(.+)$")
    if prop and value then
      return function()
        hl.dispatch(window_api.set_prop({ prop = prop, value = value }))
      end
    end
  end

  if args ~= "" then
    return raw_dispatch_cmd(name .. " " .. args)
  end
  return raw_dispatch_cmd(name)
end

local function normalize_mods(mods)
  mods = trim(mods)
  if mods == "" then
    return ""
  end
  local known = {
    super = "SUPER",
    super_l = "SUPER_L",
    super_r = "SUPER_R",
    shift = "SHIFT",
    shift_l = "SHIFT_L",
    shift_r = "SHIFT_R",
    ctrl = "CTRL",
    control = "CTRL",
    ctrl_l = "CTRL_L",
    ctrl_r = "CTRL_R",
    control_l = "CTRL_L",
    control_r = "CTRL_R",
    alt = "ALT",
    alt_l = "ALT_L",
    alt_r = "ALT_R",
    meta = "META",
    meta_l = "META_L",
    meta_r = "META_R",
    mod2 = "MOD2",
    mod3 = "MOD3",
    mod5 = "MOD5",
  }
  local parts = {}
  for token in mods:gmatch("%S+") do
    parts[#parts + 1] = known[token:lower()] or token
  end
  return table.concat(parts, " ")
end

local function chord(mods, key)
  mods = normalize_mods(mods):gsub("%s+", " + ")
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
  if mods:upper():match("SHIFT") and shifted_number_keys[key] then
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
  if opts then
    hl.bind(chord(mods, key), fn, opts)
  else
    hl.bind(chord(mods, key), fn)
  end
  if mods:upper():match("SHIFT") then
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
  local action = nil
  if dispatcher == "movewindow" and window_api.drag then
    action = window_api.drag()
  elseif dispatcher == "resizewindow" then
    if window_api.resize then
      action = window_api.resize()
    else
      action = raw_dispatch_cmd("resizewindow")
    end
  else
    action = raw_dispatch_cmd(dispatcher)
  end
  bind(mods, key, action, { description = description, mouse = true })
end

local keys_to_unbind = {
  "SUPER + V",
  "SUPER + W",
  "SUPER + P",
  "SUPER + R",
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

local function unbind_default_keys()
  for _, key in ipairs(keys_to_unbind) do
    unbind_chord(key)
  end
end

M.window_api = window_api
M.workspace_api = workspace_api
M.group_api = group_api
M.exec_cmd = exec_cmd
M.raw_dispatch_cmd = raw_dispatch_cmd
M.dispatch = dispatch
M.bind = bind
M.bindm = bindm
M.unbind_default_keys = unbind_default_keys

return M
