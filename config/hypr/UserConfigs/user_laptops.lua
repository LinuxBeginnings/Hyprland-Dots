-- ==================================================
--  KoolDots (2026)
--  Project URL: https://github.com/LinuxBeginnings
--  License: GNU GPLv3
--  SPDX-License-Identifier: GPL-3.0-or-later
-- ==================================================
-- User laptop overrides template.
-- Add lid/display behavior here if you need laptop-specific logic.

-- Examples:
-- Touchpad_Device = "your-touchpad-device-name" -- Optional: TouchPad.sh auto-detects by default
-- hl.monitor({ output = "eDP-1", mode = "preferred", position = "auto", scale = "1" })
-- hl.monitor({ output = "eDP-1", disabled = true })

-- Lid close: remove laptop panel from layout
hl.bind("switch:on:Lid Switch", function()
  os.execute("$HOME/.config/hypr/scripts/LidSwitch.sh close")
end)

-- Lid open: restore laptop panel
hl.bind("switch:off:Lid Switch", function()
  os.execute("$HOME/.config/hypr/scripts/LidSwitch.sh open")
end)
