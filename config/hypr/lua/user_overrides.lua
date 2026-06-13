-- ==================================================
--  KoolDots (2026)
--  Project URL: https://github.com/LinuxBeginnings
--  License: GNU GPLv3
--  SPDX-License-Identifier: GPL-3.0-or-later
-- ==================================================

-- Loads split system/user-editable Lua override files.
-- System files are loaded from ~/.config/hypr/configs (with UserConfigs fallback for legacy setups).
local configHome = os.getenv("XDG_CONFIG_HOME") or ((os.getenv("HOME") or "") .. "/.config")
local hyprDir = configHome .. "/hypr"
local systemDir = hyprDir .. "/configs"
local userDir = configHome .. "/hypr/UserConfigs"

local function load_optional(path)
  local ok, err = pcall(dofile, path)
  if ok then
    return true
  end
  if err and tostring(err):find("No such file or directory", 1, true) == nil then
    print("[WARN] Unable to load user override file " .. path .. ": " .. tostring(err))
  end
  return false
end
local loaded_user_split = false

local system_files = {
  "system_env.lua",
  "system_startup.lua",
  "system_window_rules.lua",
  "system_layer_rules.lua",
  "system_keybinds.lua",
  "system_settings.lua",
  "system_laptops.lua",
}
for _, file in ipairs(system_files) do
  local primary = systemDir .. "/" .. file
  local legacy = userDir .. "/" .. file
  if not load_optional(primary) then
    load_optional(legacy)
  end
end

local user_files = {
  "user_env.lua",
  "user_startup.lua",
  "user_window_rules.lua",
  "user_layer_rules.lua",
  "user_keybinds.lua",
  "user_settings.lua",
  "user_decorations.lua",
  "user_animations.lua",
  "user_laptops.lua",
}
for _, file in ipairs(user_files) do
  local path = userDir .. "/" .. file
  if load_optional(path) then
    loaded_user_split = true
  end
end
if not loaded_user_split then
  load_optional(userDir .. "/user_overrides.lua") -- legacy single-file support
end

-- Legacy compatibility: import UserKeybinds.conf when user_keybinds.lua is missing.
do
  local userKeybindsLua = userDir .. "/user_keybinds.lua"
  local legacyUserKeybinds = userDir .. "/UserKeybinds.conf"

  local hasUserLua = io.open(userKeybindsLua, "r")
  if hasUserLua then
    hasUserLua:close()
  else
    local legacy = io.open(legacyUserKeybinds, "r")
    if legacy then
      local function trim(value)
        return (value or ""):gsub("^%s+", ""):gsub("%s+$", "")
      end
      local function strip_inline_comment(value)
        return trim((value or ""):gsub("%s+#.*$", ""))
      end
      local function load_vars_from_file(path, vars)
        local handle = io.open(path, "r")
        if not handle then
          return
        end
        for raw in handle:lines() do
          local line = trim(raw)
          if line ~= "" and not line:match("^#") then
            local name, val = line:match("^%$([%w_]+)%s*=%s*(.+)$")
            if name and val then
              vars[name] = strip_inline_comment(val)
            end
          end
        end
        handle:close()
      end
      local vars = {}
      local raw_lines = {}
      local configDir = configHome .. "/hypr/configs"
      local defaultsFile = userDir .. "/01-UserDefaults.conf"
      local keybindsFile = configDir .. "/Keybinds.conf"
      local systemSettingsFile = configDir .. "/SystemSettings.conf"

      load_vars_from_file(systemSettingsFile, vars)
      load_vars_from_file(keybindsFile, vars)
      load_vars_from_file(defaultsFile, vars)

      for line in legacy:lines() do
        table.insert(raw_lines, line)
        local trimmed = trim(line)
        if trimmed ~= "" and not trimmed:match("^#") then
          local var_name, var_value = trimmed:match("^%$([%w_]+)%s*=%s*(.+)$")
          if var_name and var_value then
            vars[var_name] = strip_inline_comment(var_value)
          end
        end
      end
      legacy:close()

      local function expand_vars(value)
        value = tostring(value or "")
        for _ = 1, 8 do
          local changed = false
          value = value:gsub("%$([%w_]+)", function(name)
            local replacement = vars[name]
            if replacement ~= nil then
              changed = true
              return replacement
            end
            return "$" .. name
          end)
          if not changed then
            break
          end
        end
        return value
      end

      for _, line in ipairs(raw_lines) do
        local trimmed = trim(line)
        if trimmed ~= "" and not trimmed:match("^#") then
          local keyword, value = trimmed:match("^([%w_]+)%s*=%s*(.+)$")
          if keyword and value and (keyword:match("^bind") or keyword == "unbind") then
            local expanded = expand_vars(value)
            local cmd = "hyprctl keyword " .. keyword .. " " .. string.format("%q", expanded)
            local ok = os.execute(cmd)
            if not ok then
              print("[WARN] Failed to apply legacy keybind via: " .. cmd)
            end
          end
        end
      end
    end
  end
end
