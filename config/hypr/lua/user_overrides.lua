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
      for line in legacy:lines() do
        local trimmed = trim(line)
        if trimmed ~= "" and not trimmed:match("^#") then
          local keyword, value = trimmed:match("^([%w_]+)%s*=%s*(.+)$")
          if keyword and value and (keyword:match("^bind") or keyword == "unbind") then
            local cmd = "hyprctl keyword " .. keyword .. " " .. string.format("%q", value)
            pcall(os.execute, cmd)
          end
        end
      end
      legacy:close()
    end
  end
end
