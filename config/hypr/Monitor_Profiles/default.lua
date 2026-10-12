-- ==================================================
--  KoolDots (2026)
--  Project URL: https://github.com/LinuxBeginnings
--  License: GNU GPLv3
--  SPDX-License-Identifier: GPL-3.0-or-later
-- ==================================================

-- default Monitor config
-- Monitor Configuration
-- See Hyprland wiki for more details
-- https://wiki.hyprland.org/Configuring/Monitors/
--
-- One wildcard rule, "preferred": the panel's own EDID choice, which is always a
-- mode the output can carry. Chaining "highrr" or "highres" after it does not
-- add a fallback - the last matching rule wins - so a chain ending in "highres"
-- would ask every output for the largest mode it advertises.
hl.monitor({
    output = "",
    mode = "preferred",
    position = "auto",
    scale = "1",
})
