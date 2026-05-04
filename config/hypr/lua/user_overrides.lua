-- ==================================================
--  KoolDots (2026)
--  Project URL: https://github.com/LinuxBeginnings
--  License: GNU GPLv3
--  SPDX-License-Identifier: GPL-3.0-or-later
-- ==================================================

-- Loads split user-editable Lua override files from ~/.config/hypr/UserConfigs.
-- Files are loaded in this order so behavior is predictable.
local configHome = os.getenv("XDG_CONFIG_HOME") or ((os.getenv("HOME") or "") .. "/.config")
local userDir = configHome .. "/hypr/UserConfigs"
local files = {
  "system_env.lua",
  "system_startup.lua",
  "system_window_rules.lua",
  "system_keybinds.lua",
  "system_settings.lua",
  "system_laptops.lua",
  "user_env.lua",
  "user_startup.lua",
  "user_window_rules.lua",
  "user_layer_rules.lua",
  "user_keybinds.lua",
  "user_settings.lua",
  "user_decorations.lua",
  "user_animations.lua",
  "user_laptops.lua",
  "user_overrides.lua", -- legacy single-file support
}
for _, file in ipairs(files) do
  local path = userDir .. "/" .. file
  local ok, err = pcall(dofile, path)
  if not ok and err and tostring(err):find("No such file or directory", 1, true) == nil then
    print("[WARN] Unable to load user override file " .. path .. ": " .. tostring(err))
  end
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
