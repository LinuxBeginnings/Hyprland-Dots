-- ==================================================
--  KoolDots (2026)
--  Project URL: https://github.com/LinuxBeginnings
--  License: GNU GPLv3
--  SPDX-License-Identifier: GPL-3.0-or-later
-- ==================================================
-- User layer-rule overrides template.
-- Use this file to customize background blur, shadows, animations, and opacity on layer-shell surfaces.
--
-- =============================================================================
-- LAYER RULE SYNTAX & PROPERTIES (KoolDots Lua)
-- =============================================================================
--
-- • apply_layer_rule({
--     name = "unique-rule-identifier",       -- Unique string identifier for this rule
--     match = {
--       namespace = "regex_pattern",         -- Matches layer namespace (e.g. "rofi", "waybar", "swaync.*")
--       address = "regex_pattern",           -- Optional: matches layer address
--     },
--     -- Action properties:
--     blur = true | false,                   -- Enable / disable background blur behind surface
--     ignore_alpha = 0.0 to 1.0,             -- Transparent areas with alpha below this won't be blurred
--     animation = "slide" | "popin" | "fade",-- Animation style for this layer surface
--     dim_around = true | false,             -- Dim background behind this layer surface
--     xray = true | false,                   -- Direct background blur mode
--     order = 1,                             -- Stacking / rendering priority order
--   })
--
-- TIP: Run `hyprctl layers` in a terminal to see the exact `namespace` of all running layer-shell surfaces!
--
-- =============================================================================
-- EXAMPLES OF COMMON LAYER RULES
-- =============================================================================
--
-- 1. ROFI / APP LAUNCHER:
--    apply_layer_rule({
--      name = "user-rofi-blur",
--      match = { namespace = "^(rofi)$" },
--      blur = true,
--      ignore_alpha = 0,
--      animation = "popin 80%",
--      dim_around = true,
--    })
--
-- 2. SWAYNC NOTIFICATION CENTER & POPUPS:
--    apply_layer_rule({
--      name = "user-swaync-control-center",
--      match = { namespace = "^(swaync-control-center)$" },
--      blur = true,
--      ignore_alpha = 0.2,
--      animation = "slide right",
--    })
--
--    apply_layer_rule({
--      name = "user-swaync-notifications",
--      match = { namespace = "^(swaync-notification-window)$" },
--      blur = true,
--      ignore_alpha = 0.2,
--      animation = "slide right",
--    })
--
-- 3. WAYBAR / STATUS BAR:
--    apply_layer_rule({
--      name = "user-waybar-blur",
--      match = { namespace = "^(waybar)$" },
--      blur = true,
--      ignore_alpha = 0.5,
--    })
--
-- 4. QUICKSHELL (OVERVIEW & EXPOSE):
--    apply_layer_rule({
--      name = "user-quickshell-overview",
--      match = { namespace = "^(quickshell:overview)$" },
--      blur = true,
--      ignore_alpha = 0.5,
--      animation = "fade",
--    })
--
--    apply_layer_rule({
--      name = "user-quickshell-expose",
--      match = { namespace = "^(quickshell:expose)$" },
--      blur = true,
--      dim_around = true,
--      xray = true,
--    })
--
-- 5. LOGOUT DIALOGS (WLOGOUT / LOGOUT_DIALOG):
--    apply_layer_rule({
--      name = "user-logout-dialog",
--      match = { namespace = "^(logout_dialog|wlogout)$" },
--      blur = true,
--      dim_around = true,
--      animation = "fade",
--    })
--
-- 6. KEYBINDINGS CHEATSHEET HELPER:
--    apply_layer_rule({
--      name = "user-keybinds-help",
--      match = { namespace = "^(com.aurora.keybinds_help)$" },
--      blur = true,
--      ignore_alpha = 0,
--      dim_around = true,
--    })
--
-- =============================================================================

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
