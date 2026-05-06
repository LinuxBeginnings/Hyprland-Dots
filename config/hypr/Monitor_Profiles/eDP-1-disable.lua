-- ==================================================
--  KoolDots (2026)
--  Project URL: https://github.com/LinuxBeginnings
--  License: GNU GPLv3
--  SPDX-License-Identifier: GPL-3.0-or-later
-- ==================================================

-- Disable eDP-1 (laptop panel)

hl.monitor({
    output = "eDP-1",
    mode = "disable",
})
