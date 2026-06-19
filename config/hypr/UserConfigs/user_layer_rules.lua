-- ==================================================
--  KoolDots (2026)
--  Project URL: https://github.com/LinuxBeginnings
--  License: GNU GPLv3
--  SPDX-License-Identifier: GPL-3.0-or-later
-- ==================================================
-- User layer-rule overrides template.

local user_layer_rules_helper = nil
do
  local source = (debug.getinfo(1, "S") or {}).source or ""
  local source_path = source:match("^@(.+)$")
  local source_dir = source_path and source_path:match("^(.*)/[^/]+$") or nil
  local home = os.getenv("HOME") or ""
  local candidate_paths = {
    source_dir and (source_dir .. "/../lua/user_layer_rules_helper.lua") or nil,
    home ~= "" and (home .. "/.config/hypr/lua/user_layer_rules_helper.lua") or nil,
    home ~= "" and (home .. "/.config/hypr/user_layer_rules_helper.lua") or nil,
  }

  local tried_paths = {}
  for _, helper_path in ipairs(candidate_paths) do
    if helper_path then
      table.insert(tried_paths, helper_path)
      local f = io.open(helper_path, "r")
      if f then
        f:close()
        local loaded_ok, loaded_helpers = pcall(dofile, helper_path)
        if loaded_ok and type(loaded_helpers) == "table" and loaded_helpers.apply_layer_rule then
          user_layer_rules_helper = loaded_helpers
          break
        end
      end
    end
  end

  if not user_layer_rules_helper then
    error("Failed to load user_layer_rules_helper.lua from: " .. table.concat(tried_paths, ", "))
  end
end

local apply_layer_rule = user_layer_rules_helper.apply_layer_rule

-- Example:
-- apply_layer_rule({
--   name = "user-rofi-blur",
--   match = { namespace = "rofi" },
--   blur = true,
--   ignore_alpha = 0,
-- })
