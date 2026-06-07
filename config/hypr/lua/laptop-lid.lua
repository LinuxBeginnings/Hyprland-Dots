-- # ==================================================
-- #  KoolDots (2026)
-- #  Project URL: https://github.com/LinuxBeginnings
-- #  License: GNU GPLv3
-- #  SPDX-License-Identifier: GPL-3.0-or-later
-- # ==================================================
--
-- Sample code to handle disbling eDP-1 when lid closed
-- Code written by @star on TheBlacDon's discord server
-- Thank you
--
-- Lid close: remove laptop panel from layout
hl.bind("switch:on:Lid Switch", function()
  -- hl.dispatch(hl.dsp.dpms({ action = "disable", monitor = "eDP-1" }))
  hl.monitor({ output = "eDP-1", disabled = true })
end)

-- Lid open: restore laptop panel
hl.bind("switch:off:Lid Switch", function()
  -- hl.dispatch(hl.dsp.dpms({ action = "enable", monitor = "eDP-1" }))
  hl.monitor({ output = "eDP-1", disabled = false })
end)
