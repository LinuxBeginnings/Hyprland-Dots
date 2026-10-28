-- ==================================================
--  KoolDots (2026)
--  Project URL: https://github.com/LinuxBeginnings
--  License: GNU GPLv3
--  SPDX-License-Identifier: GPL-3.0-or-later
-- ==================================================

-- Base workspace configuration for Lua mode.
-- User/persisted workspace rules are loaded from UserConfigs/workspaces.lua.

-- Inset the special workspace so it reads as an overlay over the current
-- workspace, instead of covering it. This replaces the deprecated
-- `dwindle.special_scale_factor`, which Hyprland 0.57 flags in
-- `hyprctl deprecated-config`.
--
-- A system default, so it lives here and every install gets it on update. It
-- is emitted before UserConfigs/workspaces.lua is loaded, so a user rule for
-- `special:special` there is registered after this one.
--
-- `special:scratchpad` needs no rule: the dropdown terminal there is floating.
-- Gaps are absolute pixels, so unlike the old 0.8 factor this does not scale
-- with resolution. Raise `gaps_out` on a display larger than 1080p.
hl.workspace_rule({
  workspace = "special:special",
  gaps_in = 8,
  gaps_out = 80,
})

-- Load user workspace rules from UserConfigs when present.
do
    local configHome = os.getenv("XDG_CONFIG_HOME") or ((os.getenv("HOME") or "") .. "/.config")
    local userWorkspaces = configHome .. "/hypr/UserConfigs/workspaces.lua"
    local ok, err = pcall(dofile, userWorkspaces)
    if not ok and err and tostring(err):find("No such file or directory", 1, true) == nil then
        print("[WARN] Unable to load user workspace rules from " .. userWorkspaces .. ": " .. tostring(err))
    end
end
