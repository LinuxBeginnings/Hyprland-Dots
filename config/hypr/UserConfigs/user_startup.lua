-- ==================================================
--  KoolDots (2026)
--  Project URL: https://github.com/LinuxBeginnings
--  License: GNU GPLv3
--  SPDX-License-Identifier: GPL-3.0-or-later
-- ==================================================
-- User startup overrides template.
-- Add personal exec-once commands here.

local user_startup_helper = nil
do
  local source = (debug.getinfo(1, "S") or {}).source or ""
  local source_path = source:match("^@(.+)$")
  local source_dir = source_path and source_path:match("^(.*)/[^/]+$") or nil
  local home = os.getenv("HOME") or ""
  local candidate_paths = {
    source_dir and (source_dir .. "/../lua/user_startup_helper.lua") or nil,
    home ~= "" and (home .. "/.config/hypr/lua/user_startup_helper.lua") or nil,
    home ~= "" and (home .. "/.config/hypr/user_startup_helper.lua") or nil,
  }

  local tried_paths = {}
  for _, helper_path in ipairs(candidate_paths) do
    if helper_path then
      table.insert(tried_paths, helper_path)
      local f = io.open(helper_path, "r")
      if f then
        f:close()
        local loaded_ok, loaded_helpers = pcall(dofile, helper_path)
        if loaded_ok and type(loaded_helpers) == "table" and loaded_helpers.exec_once then
          user_startup_helper = loaded_helpers
          break
        end
      end
    end
  end

  if not user_startup_helper then
    error("Failed to load user_startup_helper.lua from: " .. table.concat(tried_paths, ", "))
  end
end

local exec_once = user_startup_helper.exec_once

-- Examples:
-- exec_once("blueman-applet")
-- exec_once("$HOME/.config/hypr/UserScripts/RainbowBorders.sh")
