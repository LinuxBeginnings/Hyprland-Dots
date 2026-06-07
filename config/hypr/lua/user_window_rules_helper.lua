-- ==================================================
--  KoolDots (2026)
--  Project URL: https://github.com/LinuxBeginnings
--  License: GNU GPLv3
--  SPDX-License-Identifier: GPL-3.0-or-later
-- ==================================================

local function apply_window_rule(rule)
  if hl.window_rule then
    hl.window_rule(rule)
  end
end

return {
  apply_window_rule = apply_window_rule,
}
