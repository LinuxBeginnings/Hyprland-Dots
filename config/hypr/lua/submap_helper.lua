-- ==================================================
--  KoolDots (2026)
--  Project URL: https://github.com/LinuxBeginnings
--  License: GNU GPLv3
--  SPDX-License-Identifier: GPL-3.0-or-later
-- ==================================================
--
-- Submap helper: creates and wires up Hyprland keybind submaps.
--
-- Public API (exposed as `submap` by UserConfigs/user_keybinds.lua):
--   submap.auto.release(name, keybind, fn)    -- hold the key to stay in the submap
--   submap.auto.toggle(name, keybind, fn)     -- press to enter, press again to leave
--   submap.man(name, entry, exit, fn)         -- enter with `entry`, leave with `exit`
--   submap.create(name, keybind, fn)          -- only create the submap entry bind
--   submap.define(name, keybind, fn)          -- create the entry bind + register the body
--
-- IMPORTANT: `hl` is resolved lazily on every call, never captured at load time.
-- Hyprland only guarantees the `hl` global while it is executing config files,
-- and it rebuilds the entire Lua state on reload. Caching `hl` (or
-- `hl.dsp`/`hl.bind`) into locals at module load means one bad load permanently
-- disables every submap - silently, or with confusing nil errors - until
-- Hyprland restarts. Resolving per call keeps the module immune to load order.

local Submap = {
  auto = {},
}

-- Recognised modifiers, mirroring user_keybinds_helper.lua plus MOD2/MOD3.
-- Values are the canonical spelling emitted in the keybind chord.
local MODIFIER_ALIASES = {
  super = "SUPER",
  super_l = "SUPER",
  super_r = "SUPER",
  meta = "META",
  meta_l = "META",
  meta_r = "META",
  ctrl = "CTRL",
  ctrl_l = "CTRL",
  ctrl_r = "CTRL",
  control = "CTRL",
  control_l = "CTRL",
  control_r = "CTRL",
  crtl = "CTRL", -- common typo for CTRL
  alt = "ALT",
  alt_l = "ALT",
  alt_r = "ALT",
  shift = "SHIFT",
  shift_l = "SHIFT",
  shift_r = "SHIFT",
  mod1 = "MOD1",
  mod2 = "MOD2",
  mod3 = "MOD3",
  mod4 = "MOD4",
  mod5 = "MOD5",
}

-- Resolve Hyprland's `hl` API at call time and fail loudly if it is missing
-- instead of degrading to an empty table (which yields silent no-ops).
local function require_hl()
  local api = rawget(_G, "hl")
  if type(api) ~= "table" then
    error(
      "[submap_helper] Hyprland's 'hl' API is not available. This module must run "
        .. "inside Hyprland's Lua config and cannot be executed standalone.",
      3
    )
  end
  return api
end

local function require_hl_function(field)
  local api = require_hl()
  if type(api[field]) ~= "function" then
    error(string.format("[submap_helper] Hyprland's 'hl.%s' API is not available in this Hyprland build.", field), 3)
  end
  return api[field]
end

-- `hl.dsp.submap(name)` is a dispatcher factory: it must be RETURNED and handed
-- to hl.bind. Calling it and discarding the result binds a nil dispatcher.
local function submap_dispatcher(target)
  local dsp = require_hl().dsp
  if type(dsp) ~= "table" or type(dsp.submap) ~= "function" then
    error("[submap_helper] Hyprland's 'hl.dsp.submap' API is not available in this Hyprland build.", 3)
  end
  return dsp.submap(target)
end

local function submap_bind(chord, dispatcher, opts)
  local bind = require_hl_function("bind")
  if opts then
    return bind(chord, dispatcher, opts)
  end
  return bind(chord, dispatcher)
end

local function submap_define(name, body)
  return require_hl_function("define_submap")(name, body)
end

local function require_callable(fn, what)
  if type(fn) == "function" then
    return fn
  end
  error(string.format("Submap Error: %s must be a function, got %s.", what or "argument", type(fn)), 3)
end

-- Normalise a keybind spec into a Hyprland chord string.
-- Accepts "SUPER SHIFT E", "SUPER, SHIFT, E", "SUPER + SHIFT + E" or a table.
local function parse_keybind(spec)
  local tokens = {}
  if type(spec) == "string" and spec ~= "" then
    for token in spec:gmatch("[^%s,+]+") do
      tokens[#tokens + 1] = token
    end
  elseif type(spec) == "table" then
    for _, token in ipairs(spec) do
      tokens[#tokens + 1] = tostring(token)
    end
  end

  if #tokens == 0 then
    error("Submap Error: a keybind is required, e.g. \"SUPER + E\" or \"mouse:274\".", 3)
  end

  local mods, keys = {}, {}
  for _, token in ipairs(tokens) do
    local canonical = MODIFIER_ALIASES[tostring(token):lower()]
    if canonical then
      mods[#mods + 1] = canonical
    else
      keys[#keys + 1] = tostring(token)
    end
  end

  if #keys ~= 1 then
    error(
      string.format(
        "Submap Error: a keybind needs exactly one non-modifier key, got %d (%s). "
          .. "Supported modifiers: SUPER, CTRL, ALT, SHIFT, MOD1-MOD5, META.",
        #keys,
        tostring(spec)
      ),
      3
    )
  end
  if #mods > 2 then
    error(string.format("Submap Error: a maximum of 2 modifiers is supported, got %d (%s).", #mods, tostring(spec)), 3)
  end

  if #mods == 0 then
    return keys[1]
  end
  return table.concat(mods, " + ") .. " + " .. keys[1]
end

-- Shared validation. `opt` is the separate exit chord for submap.man(); when it
-- is a function it is the submap body instead (auto.release / auto.toggle).
local function submap_logic(name, entry_spec, opt, fn)
  local exit_spec
  if type(opt) == "function" then
    fn = opt
  else
    exit_spec = opt
  end

  local checked_name = tostring(name or "")
  if checked_name == "" or checked_name == "nil" then
    error("Submap Error: submap name cannot be empty.", 3)
  end

  return {
    name = checked_name,
    entry_chord = parse_keybind(entry_spec),
    exit_chord = exit_spec ~= nil and parse_keybind(exit_spec) or nil,
    body = fn,
  }
end

-- Only create the submap: bind the entry chord to the submap dispatcher.
local function create_submap(ctx)
  return submap_bind(ctx.entry_chord, submap_dispatcher(ctx.name))
end

-- Register the submap body. Hyprland runs `body` in the submap's context, so any
-- binds created inside it are only active while the submap is active.
local function define_body(ctx)
  return submap_define(ctx.name, require_callable(ctx.body, "the submap body"))
end

local function toggle_submap(ctx)
  create_submap(ctx)
  submap_define(ctx.name, function()
    submap_bind(ctx.entry_chord, submap_dispatcher("reset"))
    require_callable(ctx.body, "the submap body")()
  end)
end

local function release_submap(ctx)
  create_submap(ctx)
  submap_define(ctx.name, function()
    -- Binds registered in the parent submap are inactive once this submap is
    -- active, so the release-to-exit bind has to live inside the submap body.
    submap_bind(ctx.entry_chord, submap_dispatcher("reset"), { release = true })
    require_callable(ctx.body, "the submap body")()
  end)
end

local function separate_binds(ctx)
  if not ctx.exit_chord then
    error("Submap Error: submap.man() requires separate entry and exit keybinds.", 3)
  end
  create_submap(ctx)
  submap_define(ctx.name, function()
    submap_bind(ctx.exit_chord, submap_dispatcher("reset"))
    require_callable(ctx.body, "the submap body")()
  end)
end

function Submap.auto.release(name, binds, fn)
  return release_submap(submap_logic(name, binds, fn))
end

function Submap.auto.toggle(name, binds, fn)
  return toggle_submap(submap_logic(name, binds, fn))
end

function Submap.man(name, bind1, bind2, fn)
  return separate_binds(submap_logic(name, bind1, bind2, fn))
end

function Submap.create(name, binds, fn)
  return create_submap(submap_logic(name, binds, fn))
end

function Submap.define(name, binds, fn)
  local ctx = submap_logic(name, binds, nil, fn)
  create_submap(ctx)
  return define_body(ctx)
end

return { submap = Submap }
