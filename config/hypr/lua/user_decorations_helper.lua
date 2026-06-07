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

return {
  load_wallust_colors = load_wallust_colors,
}
