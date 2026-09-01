-- ==================================================
--  KoolDots (2026)
--  Project URL: https://github.com/LinuxBeginnings
--  License: GNU GPLv3
--  SPDX-License-Identifier: GPL-3.0-or-later
-- ==================================================

-- Base workspace configuration for Lua mode.
-- User/persisted workspace rules are loaded from UserConfigs/workspaces.lua.

-- Load user workspace rules from UserConfigs when present.
do
    local configHome = os.getenv("XDG_CONFIG_HOME") or ((os.getenv("HOME") or "") .. "/.config")
    local userWorkspaces = configHome .. "/hypr/UserConfigs/workspaces.lua"
    local ok, err = pcall(dofile, userWorkspaces)
    if not ok and err and tostring(err):find("No such file or directory", 1, true) == nil then
        print("[WARN] Unable to load user workspace rules from " .. userWorkspaces .. ": " .. tostring(err))
    end
end
