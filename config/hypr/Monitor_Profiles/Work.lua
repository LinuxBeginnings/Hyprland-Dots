-- ==================================================
--  KoolDots (2026)
--  Project URL: https://github.com/LinuxBeginnings
--  License: GNU GPLv3
--  SPDX-License-Identifier: GPL-3.0-or-later
-- ==================================================

-- Work profile: one rule per output, matched by PORT.
--
-- How to apply it: Quick Settings (SUPER + SHIFT + E) -> Choose Monitor
-- Profiles -> Work. That applies these rules, then saves what is on screen as a
-- layout called Work for the monitors you have connected, so SUPER + ALT + W
-- applies it from then on.
--
-- Why by port, and not by device like a layout: a profile is a set of rules, and
-- Hyprland ignores a rule whose output is not connected. So this one file covers
-- the laptop alone, a dock with two screens, and the full desk, without needing a
-- separate saved layout for each combination. The trade-off is that a monitor
-- moved to a different port is not recognised here - save a layout from the menu
-- if you want an arrangement that follows the device.
--
-- To modify:
--   * delete the blocks for outputs you do not have, or copy one for an output
--     you do. `hyprctl monitors all` lists the names.
--   * mode: "preferred" is the panel's own EDID choice, and the safest default.
--     Also accepted: "highrr" (highest refresh), "highres" (highest resolution),
--     or an explicit "1920x1080@60". Prefer "preferred" unless you need one of
--     the others: "highres" takes the largest mode the panel reports whether or
--     not the cable will actually carry it.
--   * position: "auto" lays the outputs out left to right. "auto-left",
--     "auto-right", "auto-up" and "auto-down" place them relative to the outputs
--     already configured, or pin one exactly with "1920x0".
--   * scale: "1" is native. "1.25" / "1.5" / "2" scale up for a HiDPI panel.
--   * transform: 1 = 90 degrees, 2 = 180, 3 = 270. Uncomment to rotate.
--   * disabled = true switches the output off instead of configuring it.
--
-- A rule that never matches is harmless, so leaving blocks in for outputs you do
-- not have yet costs nothing.

-- Laptop panel.
hl.monitor({
    output = "eDP-1",
    mode = "preferred",
    position = "auto",
    scale = "1",
    -- transform = 1,
})

-- Docking station outputs.
hl.monitor({
    output = "DP-1",
    mode = "preferred",
    position = "auto",
    scale = "1",
})

hl.monitor({
    output = "DP-2",
    mode = "preferred",
    position = "auto",
    scale = "1",
})

hl.monitor({
    output = "DP-3",
    mode = "preferred",
    position = "auto",
    scale = "1",
})

-- HDMI outputs.
hl.monitor({
    output = "HDMI-A-1",
    mode = "preferred",
    position = "auto",
    scale = "1",
})

hl.monitor({
    output = "HDMI-A-2",
    mode = "preferred",
    position = "auto",
    scale = "1",
})
