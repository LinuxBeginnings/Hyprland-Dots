-- ==================================================
--  KoolDots (2026)
--  Project URL: https://github.com/LinuxBeginnings
--  License: GNU GPLv3
--  SPDX-License-Identifier: GPL-3.0-or-later
-- ==================================================

local function load_wallust_colors(path)
  local colors = {}
  local handle = io.open(path, "r")
  if not handle then
    return colors
  end

  for line in handle:lines() do
    local name, hex = line:match("^%s*%$([%w_]+)%s*=%s*rgb%(([0-9A-Fa-f]+)%)")
    if name and hex and hex ~= "" then
      colors[string.lower(name)] = "rgb(" .. string.upper(hex) .. ")"
    end
  end

  handle:close()
  return colors
end

-- True when the running compositor has a config option. hl.get_config answers
-- nil for a key the build does not know, so the option itself is the test: no
-- version string to parse, and a backport or a later release needs no edit.
-- Older builds (or a missing binding) answer false.
local function has_config_option(key)
  if type(hl) ~= "table" or type(hl.get_config) ~= "function" then
    return false
  end

  local ok, value = pcall(hl.get_config, key)
  return ok and value ~= nil
end

return {
  load_wallust_colors = load_wallust_colors,
  has_config_option = has_config_option,
}
