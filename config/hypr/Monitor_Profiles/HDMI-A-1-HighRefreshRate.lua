-- ==================================================
--  KoolDots (2026)
--  Project URL: https://github.com/LinuxBeginnings
--  License: GNU GPLv3
--  SPDX-License-Identifier: GPL-3.0-or-later
-- ==================================================

-- HDMI-A-1 High Refresh Rate profile
--
-- The mode is spelled out on purpose. Hyprland's "highrr" keyword is not "the
-- highest refresh rate this monitor can do at the resolution it is using": it is
-- the highest refresh rate anywhere in the mode list, whatever the resolution.
-- A 1920x1080@75 panel that also advertises 1024x768@75.03 therefore goes to
-- 1024x768 under "highrr" - the resolution is dropped to chase 0.06Hz. There is
-- no keyword for "the best refresh rate at the current resolution", so this
-- profile asks for one mode by name.
--
-- Edit the mode to match the monitor on this port. `hyprctl monitors all` lists
-- what it advertises, and a value close to an advertised one is matched to it,
-- so "1920x1080@75" reaches a 74.97Hz mode. A mode the monitor does not
-- advertise leaves the panel on its preferred mode instead - Hyprland ignores
-- the rule rather than reporting an error.
hl.monitor({
    output = "HDMI-A-1",
    mode = "1920x1080@75",
    position = "auto",
    scale = "1",
})
