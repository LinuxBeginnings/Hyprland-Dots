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
  "system_layer_rules.lua",
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
