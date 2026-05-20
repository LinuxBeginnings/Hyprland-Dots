-- ==================================================
--  KoolDots (2026)
--  Project URL: https://github.com/LinuxBeginnings
--  License: GNU GPLv3
--  SPDX-License-Identifier: GPL-3.0-or-later
-- ==================================================

-- Converted from config/hypr/monitors.conf (active monitor entries only).

hl.monitor({
    output = "",
    mode = "preferred",
    position = "auto",
    scale = "1",
})

hl.monitor({
    output = "",
    mode = "highrr",
    position = "auto",
    scale = "1",
})

hl.monitor({
    output = "",
    mode = "highres",
    position = "auto",
    scale = "1",
})

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
