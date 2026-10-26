-- ==================================================
--  KoolDots (2026)
--  Project URL: https://github.com/LinuxBeginnings
--  License: GNU GPLv3
--  SPDX-License-Identifier: GPL-3.0-or-later
-- ==================================================
--
-- Keybind index: the list behind the SUPER SHIFT K rofi menu.
--
-- Why this exists
-- ---------------
-- scripts/keybinds_parser.py regexed the keybind files and printed what the
-- source text said, so it could only report what the config *intended*. It
-- missed the chords the helpers derive (key variants), the lid-switch binds
-- written with a bare hl.bind, and anything registered by another module.
--
-- Hyprland's Lua API has no call that lists the bind table, so the compositor
-- cannot be asked for it directly. The next best thing is to record every bind
-- in the VM that registers it, which is what this module does. It sees the real
-- chords because it is handed them, and it is filled by the same config load
-- that registers the binds, so it cannot describe a bind state that never
-- existed.
--
-- Two rules to keep
-- -----------------
-- 1. Never keep the HL.Keybind handle that hl.bind returns. unbind() frees it,
--    and reading a freed handle segfaults the compositor - reproduced twice on
--    0.56.2 by reading .enabled after an unbind. Only the chord and the
--    description are stored, and both are copied at bind time.
-- 2. Install the hook with rawset. `hl` is a table, and rawset cannot run a
--    metamethod, so a build that protects that table cannot turn the hook into
--    a crash: it either takes effect or leaves hl.bind exactly as it was.
--
-- The file this writes is a transport, not a source of truth. KeyBinds.sh asks
-- the live VM to rewrite it before every run, so a bind added with
-- `hyprctl eval` after the last reload still reaches the menu.

local M = {
  order = {},   -- normalized chords, in registration order
  entries = {}, -- normalized chord -> description
}

local SEPARATOR = " — "

-- "SUPER + SHIFT + K" -> "SUPER+SHIFT+K", the shape the menu has always
-- printed. Key case is left alone, so SUPER+j and SUPER+Return stay as the
-- config wrote them.
local function normalize_chord(chord)
  local normalized = tostring(chord or ""):gsub("%s*%+%s*", "+")
  return (normalized:gsub("^%s+", ""):gsub("%s+$", ""))
end

local function forget(chord)
  local key = normalize_chord(chord)
  if M.entries[key] == nil then
    return
  end
  M.entries[key] = nil
  for index = #M.order, 1, -1 do
    if M.order[index] == key then
      table.remove(M.order, index)
    end
  end
end

-- The description can arrive as opts.description, as opts.desc, or not at all
-- (the lid-switch binds in user_laptops.lua pass no options). Every argument is
-- scanned rather than a fixed position assumed, so the hook stays correct if a
-- future build changes the signature.
local function describe(...)
  for index = 1, select("#", ...) do
    local value = select(index, ...)
    if type(value) == "table" then
      local candidate = value.description or value.desc
      if type(candidate) == "string" and candidate ~= "" then
        return candidate
      end
    end
  end
  return ""
end

local function record(chord, ...)
  local key = normalize_chord(chord)
  if key == "" then
    return
  end
  -- Rebinding an existing chord moves it to the end of the list. That is the
  -- ordering the old parser produced, and the one users are used to: their
  -- overrides sit at the bottom of the menu.
  forget(key)
  M.entries[key] = describe(...)
  M.order[#M.order + 1] = key
end

-- hl.unbind is called both ways by the keybind helpers - unbind("MOD + KEY") and
-- unbind("MOD", "KEY") - so both forms have to normalize to the same key or the
-- entry would survive the unbind.
local function forget_any(...)
  local count = select("#", ...)
  if count == 0 then
    return
  end
  if count == 1 then
    forget(select(1, ...))
    return
  end
  forget(tostring(select(1, ...)) .. " + " .. tostring(select(2, ...)))
end

local function install()
  local api = rawget(_G, "hl")
  if type(api) ~= "table" then
    print("[WARN] keybind_index: Hyprland's 'hl' API is not available; "
      .. "the keybind menu will read the bind table directly instead.")
    return false
  end

  local original_bind = api.bind
  if type(original_bind) ~= "function" then
    print("[WARN] keybind_index: hl.bind is not a function in this build; "
      .. "the keybind menu will read the bind table directly instead.")
    return false
  end

  -- Forward every argument and return the value unchanged: the hook has to be
  -- invisible to its callers.
  local bind_hooked = pcall(rawset, api, "bind", function(...)
    local result = original_bind(...)
    pcall(record, ...)
    return result
  end)

  local original_unbind = api.unbind
  if type(original_unbind) == "function" then
    pcall(rawset, api, "unbind", function(...)
      local result = original_unbind(...)
      pcall(forget_any, ...)
      return result
    end)
  end

  if not bind_hooked then
    print("[WARN] keybind_index: could not hook hl.bind; "
      .. "the keybind menu will read the bind table directly instead.")
    return false
  end
  return true
end

local function cache_path()
  local runtime_dir = os.getenv("XDG_RUNTIME_DIR")
  if not runtime_dir or runtime_dir == "" then
    runtime_dir = "/tmp"
  end
  return runtime_dir .. "/kooldots-keybinds.txt"
end

-- Renders the list rofi shows. Called at the end of hyprland.lua, so the file
-- exists without asking the compositor, and by KeyBinds.sh through
-- `hyprctl eval` before every run, so the list is never a reload behind.
function M.write_cache()
  local lines = {}
  for _, chord in ipairs(M.order) do
    local description = M.entries[chord]
    if description and description ~= "" then
      lines[#lines + 1] = chord .. SEPARATOR .. description
    else
      lines[#lines + 1] = chord
    end
  end

  local path = cache_path()
  local file, err = io.open(path, "w")
  if not file then
    print("[WARN] keybind_index: cannot write " .. path .. ": " .. tostring(err))
    return false
  end
  file:write(table.concat(lines, "\n"))
  if #lines > 0 then
    file:write("\n")
  end
  file:close()
  return true
end

M.hooked = install()

rawset(_G, "KOOLDOTS_KEYBIND_INDEX", M)
