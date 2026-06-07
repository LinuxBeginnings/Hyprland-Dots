-- ==================================================
--  KoolDots (2026)
--  Project URL: https://github.com/LinuxBeginnings
--  License: GNU GPLv3
--  SPDX-License-Identifier: GPL-3.0-or-later
-- ==================================================

local dsp = hl.dsp or hl

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
  if mods and mods:match("SHIFT") and shifted_number_keys[key] then
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

local function dispatch_factory_safely(factory)
  pcall(function()
    local dispatcher = factory()
    if dispatcher then
      hl.dispatch(dispatcher)
    end
  end)
end

local function dispatch(name, args)
  local window_api = (dsp and dsp.window) or hl.window or {}
  name = trim(name)
  args = trim(args)

  if args:match("^exec%s*,") then
    return exec_cmd(trim(args:gsub("^exec%s*,", "", 1)))
  end
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
      dispatch_factory_safely(function()
        return dsp.focus({ direction = direction(args) })
      end)
    end
  end
  if name == "movewindow" and window_api.move then
    return function()
      dispatch_factory_safely(function()
        return window_api.move({ direction = direction(args) })
      end)
    end
  end
  if name == "workspace" and dsp and dsp.focus then
    return function() hl.dispatch(dsp.focus({ workspace = workspace_value(args) })) end
  end
  if name == "movetoworkspace" and window_api.move then
    return function() hl.dispatch(window_api.move({ workspace = workspace_value(args) })) end
  end
  if name == "movetoworkspacesilent" and window_api.move then
    return function() hl.dispatch(window_api.move({ workspace = workspace_value(args), follow = false })) end
  end
  if name == "togglefloating" and window_api.float then
    return function() hl.dispatch(window_api.float({ action = "toggle" })) end
  end
  if name == "resizewindow" and window_api.resize then
    return window_api.resize()
  end
  if name == "resizeactive" then
    return raw_dispatch_cmd("resizeactive " .. args)
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
        -- Hyprland Lua APIs vary by build: some accept unbind("MOD + KEY"),
        -- others unbind("MOD", "KEY"), and some no-op one form silently.
        -- Call both forms to make unbind behavior deterministic.
        pcall(hl.unbind, key_chord)
        pcall(hl.unbind, mods, key_variant)
      end
    end
  end
end

return {
  exec_cmd = exec_cmd,
  trim = trim,
  chord = chord,
  key_variants = key_variants,
  workspace_value = workspace_value,
  raw_dispatch_cmd = raw_dispatch_cmd,
  dispatch = dispatch,
  bind = bind,
  unbind = unbind,
}
