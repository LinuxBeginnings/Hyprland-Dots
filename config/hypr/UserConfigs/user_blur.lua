-- ==================================================
--  KoolDots (2026)
--  Project URL: https://github.com/LinuxBeginnings
--  License: GNU GPLv3
--  SPDX-License-Identifier: GPL-3.0-or-later
-- ==================================================
-- Available configuration settings for blur variants.
hl.config({
  decoration = {
    blur = {
      acrylic = {
        aberration = 0.008, -- 0.0-0.25
        bulb = 128.0,       -- 4.0-256.0
        clarity = 0.90,     -- 0.0-1.0
        refraction = 40.0,  -- 0.0-48.0
        tint = 0x14EEF5FF,
      },
      aurora = {
        color1 = 0x29F0A0FF,
        color2 = 0x7A4DFFFF,
        intensity = 0.35,   -- 0.0-1.0
        speed = 1.0,        -- 0.0-10.0
      },
      drops = {
        speed = 3.0,        -- 0.0-10.0
      },
      fluid_jar = {
        color = 0xCC3399FF,
        distortion = 8.0,   -- 0.0-10.0
        fill_amount = 0.5,  -- 0.0-1.0
        mass = 1.4,         -- 0.1-10.0
        precision = 2.0,    -- 0.5-8.0
        speed = 3.7,        -- 0.0-10.0
        turbulence = 1.2,   -- 0.0-5.0
      },
      glass = {
        -- Not a valid variant, but is used by aurora, drops, heat_shimmer, and prism.
        refraction = 20.0,  -- 0.0-20.0
        roughness = 0.85,   -- 0.0-1.0
        size = 64.0,        -- 4.0-512.0
      },
      haze = {
        intensity = 0.1,    -- 0.0-1.0
        iridescence = 0.8,  -- 0.0-1.0
      },
      heat_shimmer = {
        speed = 1.0,        -- 0.0-1.0
      },
      ripple = {
        duration = 0.45,    -- 0.05-5.0
        radius = 400.0,     -- 1.0-1000.0
        strength = 30.0,    -- 0.0-32.0
        width = 32.0,       -- 1.0-200.0
      },
      water = {
        damping = 0.95,     -- 0.0-1.0
        duration = 12.0,    -- 0.5-60.0
        radius = 20.0,      -- 1.0-1000.0
        speed = 0.70,       -- 0.0-10.0
        strength = 32.0,    -- 0.0-32.0
      },
    },
  },
})