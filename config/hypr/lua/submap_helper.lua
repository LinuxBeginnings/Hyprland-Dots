-- ==================================================
--  KoolDots (2026)
--  Project URL: https://github.com/LinuxBeginnings
--  License: GNU GPLv3
--  SPDX-License-Identifier: GPL-3.0-or-later
-- ==================================================
local Submap = {
  auto = {},
}
local hl = hl or {}
local dsp = hl.dsp or {}
local dispatch = hl.dispatch or {}
local bind = hl.bind or {}

local function submap_logic(name, binds, opt, fn)
  if type(opt) == "function" or (type(opt) == "table" and getmetatable(opt) and type(getmetatable(opt).__call) == "function") then
    fn = opt
    opt = nil
  end

  local function check_name(name)
    local checked_name = tostring(name or "")
    if checked_name == "" or checked_name == "nil" then
      error("Submap Error: Name cannot be an empty.")
    end
    return checked_name
  end

  local function check_keys(binds)
    local indiv_keys = {}
    if type(binds) == "string" and binds ~= "" then
      for k in string.gmatch(binds, "[^,%s]+") do
        table.insert(indiv_keys, k)
      end
    elseif type(binds) == "table" then
      for _, v in ipairs(binds) do
        table.insert(indiv_keys, v)
      end
    else
      error("Submap Error: Keybinds cannot be empty and cannot be >3 buttons.")
    end
    local all_mods = {
      SUPER = true,
      CTRL = true,
      CONTROL = true,
      ALT = true,
      SHIFT = true,
      MOD1 = true,
      MOD4 = true,
      MOD5 = true
    }
    local keys = {}
    local mods = {}
    for _, indiv_key in ipairs(indiv_keys) do
      if all_mods[tostring(indiv_key):upper()] then
        table.insert(mods, indiv_key)
      else
        table.insert(keys, indiv_key)
      end
    end
    if #mods > 2 then
      error(string.format("Submap Error: There is a maximum of 2 modifier keys when using submap."))
    elseif #keys ~= 1 then
      error(string.format("Submap Error: There needs to be one non-modifer key when using submap."))
    end
    local mod_str = #mods > 1 and table.concat(mods, " + ") or mods[1] or ""
    local key_str = tostring(keys[1])
    if mod_str ~= "" then
      Keybind = string.format("%s, %s", mod_str, key_str)
    else
      Keybind = string.format("%s", key_str)
    end
    return Keybind
  end

  local function is_callable(fn)
    if type(fn) == "function" or (type(fn) == "table" and getmetatable(fn) and type(getmetatable(fn).__call) == "function") then
      return fn
    else
      error("Submap Error: Function(s) not callable. Please enter valid function(s)")
      return nil
    end
  end

  local function check_function(fn)
    local checked_function = nil
    if not is_callable(fn) then
      error(string.format("Submap Error: %s is not a valid function", tostring(fn)))
    else
      checked_function = fn
    end
    return checked_function
  end
  local checked_name = check_name(name)
  local keybind = check_keys(binds)
  local keybind2 = opt and check_keys(opt) or nil
  local checked_function = check_function(fn)
  if not checked_name or not checked_function or not keybind then
    error("Submap Error: There's been an error checking params set while using submap.")
    return { success = false }
  end
  local function dsp_submap(submap_target)
    local target = submap_target
    if hl and hl.dsp and type(hl.dsp.submap) == "function" then
      hl.dsp.submap(target)
    elseif hl and type(dispatch) == "function" then
      dispatch(submap(target))
    else
      os.execute(string.format("hyprctl dispatch submap %s", target))
    end
  end

  local function create_submap()
    if hl and hl.dsp then
      return bind(keybind, dsp_submap(checked_name))
    end
  end

  local function define_submap(fn)
    if hl and hl.define_submap then
      return hl.define_submap(checked_name, fn)
    end
  end

  local function reset_submap()
    if hl and hl.dsp then
      return dsp_submap("reset")
    end
  end

  local function toggle_submap()
    bind(keybind, dsp.submap(checked_name))
    hl.define_submap(checked_name, function()
      bind(keybind, dsp.submap("reset"))
      checked_function()
    end)
  end

  local function release_submap()
    bind(keybind, dsp.submap(checked_name))
    hl.define_submap(checked_name, checked_function)
    bind(keybind, dsp.submap("reset"), { release = true })
  end

  local function separate_binds()
    bind(keybind, dsp.submap(checked_name))
    hl.define_submap(checked_name, function()
      bind(keybind2, dsp.submap("reset"))
      checked_function()
    end)
  end

  return{
    success = true,
    binds = binds,
    name = checked_name,
    fn = checked_function,
    create = create_submap,
    define = define_submap,
    reset = reset_submap,
    toggle_submap = toggle_submap,
    release_submap = release_submap,
    separate_binds = separate_binds,
  }
end


function Submap.auto.release(name, binds, fn)
  local helper = submap_logic(name, binds, fn)
  if helper and helper.success then
    return helper.release_submap()
  end
end

function Submap.auto.toggle(name, binds, fn)
  local helper = submap_logic(name, binds, fn)
  if helper and helper.success then
    return helper.toggle_submap()
  end
end

function Submap.man(name, bind1, bind2, fn)
  local helper = submap_logic(name, bind1, bind2, fn)
  if helper and helper.success then
    return helper.separate_binds()
  end
end

function Submap.create(name, binds, fn)
  local helper = submap_logic(name, binds, fn)
  if helper and helper.success then
    return helper.create()
  end
end

function Submap.define(name, binds, fn)
  local helper = submap_logic(name, binds, fn)
  if helper and helper.success then
    helper.create()
    helper.define()
  end
end

return { submap = Submap }