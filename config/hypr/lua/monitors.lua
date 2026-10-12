-- ==================================================
--  KoolDots (2026)
--  Project URL: https://github.com/LinuxBeginnings
--  License: GNU GPLv3
--  SPDX-License-Identifier: GPL-3.0-or-later
-- ==================================================

-- Converted from config/hypr/monitors.conf (active monitor entries only).
--
-- The wildcard default is "preferred": the panel's own EDID choice, which is
-- always a mode the output can actually carry. Do NOT chain "highrr" or
-- "highres" after it: the last matching rule wins, so a chain ending in
-- "highres" asks every output for the largest mode it advertises, which is how
-- a VM's virtual output ends up at 5120x2440@50 instead of a usable mode.
hl.monitor({
    output = "",
    mode = "preferred",
    position = "auto",
    scale = "1",
})

-- Explicit per-output rules override the wildcard above.
hl.monitor({
    output = "Virtual-1",
    mode = "1920x1080@60",
    position = "auto",
    scale = "1",
})

-- Load user monitor overrides from UserConfigs when present.
do
    local configHome = os.getenv("XDG_CONFIG_HOME") or ((os.getenv("HOME") or "") .. "/.config")
    local userMonitors = configHome .. "/hypr/UserConfigs/monitors.lua"
    local ok, err = pcall(dofile, userMonitors)
    if not ok and err and tostring(err):find("No such file or directory", 1, true) == nil then
        print("[WARN] Unable to load user monitor overrides from " .. userMonitors .. ": " .. tostring(err))
    end
end
