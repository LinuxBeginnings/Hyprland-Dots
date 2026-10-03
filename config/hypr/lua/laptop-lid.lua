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
-- hl.exec_cmd spawns and returns; os.execute blocks the compositor until the
-- script exits.
hl.bind("switch:on:Lid Switch", function()
  if hl and hl.exec_cmd then
    hl.exec_cmd("$HOME/.config/hypr/scripts/LidSwitch.sh close")
  end
end)

-- Lid open: restore laptop panel
hl.bind("switch:off:Lid Switch", function()
  if hl and hl.exec_cmd then
    hl.exec_cmd("$HOME/.config/hypr/scripts/LidSwitch.sh open")
  end
end)
