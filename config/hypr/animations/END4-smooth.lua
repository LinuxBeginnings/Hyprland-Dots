-- 💫 https://github.com/LinuxBeginnings 💫
-- END4-smooth.lua

hl.config({
  animations = {
    enabled = true,
  },
})

-- Curves
hl.curve("emphasizedDecel", {
  type = "bezier",
  points = { { 0.05, 0.7 }, { 0.1, 1 } },
})
hl.curve("emphasizedAccel", {
  type = "bezier",
  points = { { 0.3, 0 }, { 0.8, 0.15 } },
})
hl.curve("standardDecel", {
  type = "bezier",
  points = { { 0, 0 }, { 0, 1 } },
})
hl.curve("menu_decel", {
  type = "bezier",
  points = { { 0.1, 1 }, { 0, 1 } },
})
hl.curve("menu_accel", {
  type = "bezier",
  points = { { 0.52, 0.03 }, { 0.72, 0.08 } },
})
hl.curve("stall", {
  type = "bezier",
  points = { { 1, -0.1 }, { 0.7, 0.85 } },
})
-- Configs
-- global
-- Upstream leaves this unset, so unlisted leaves (monitorAdded) inherited
-- Hyprland's stock timing rather than the values below.
hl.animation({
  leaf = "global",
  enabled = true,
  speed = 3,
  bezier = "emphasizedDecel",
})
-- windows
hl.animation({
  leaf = "windowsIn",
  enabled = true,
  speed = 4.90,
  bezier = "emphasizedDecel",
  style = "popin 80%",
})
hl.animation({
  leaf = "fadeIn",
  enabled = true,
  speed = 4.90,
  bezier = "emphasizedDecel",
})
hl.animation({
  leaf = "windowsOut",
  enabled = true,
  speed = 2.9,
  bezier = "emphasizedDecel",
  style = "popin 90%",
})
hl.animation({
  leaf = "fadeOut",
  enabled = true,
  speed = 2.9,
  bezier = "emphasizedDecel",
})
hl.animation({
  leaf = "windowsMove",
  enabled = true,
  speed = 3,
  bezier = "emphasizedDecel",
  style = "slide",
})
hl.animation({
  leaf = "border",
  enabled = true,
  speed = 10,
  bezier = "emphasizedDecel",
})

-- layers
hl.animation({
  leaf = "layersIn",
  enabled = true,
  speed = 2.7,
  bezier = "emphasizedDecel",
  style = "popin 93%",
})
hl.animation({
  leaf = "layersOut",
  enabled = true,
  speed = 2.4,
  bezier = "menu_accel",
  style = "popin 94%",
})
-- fade
-- Parent of fadeSwitch/fadeShadow/fadeGlow/fadeDim and the popup fades, which
-- upstream left at Hyprland's stock timing.
hl.animation({
  leaf = "fade",
  enabled = true,
  speed = 3,
  bezier = "emphasizedDecel",
})
hl.animation({
  leaf = "fadeLayersIn",
  enabled = true,
  speed = 0.5,
  bezier = "menu_decel",
})
hl.animation({
  leaf = "fadeLayersOut",
  enabled = true,
  speed = 2.7,
  bezier = "stall",
})
-- workspaces
hl.animation({
  leaf = "workspaces",
  enabled = true,
  speed = 10,
  bezier = "menu_decel",
  style = "slide",
})
-- specialWorkspace
hl.animation({
  leaf = "specialWorkspaceIn",
  enabled = true,
  speed = 2.8,
  bezier = "emphasizedDecel",
  style = "slidevert",
})
hl.animation({
  leaf = "specialWorkspaceOut",
  enabled = true,
  speed = 1.2,
  bezier = "emphasizedAccel",
  style = "slidevert",
})
-- zoom
hl.animation({
  leaf = "zoomFactor",
  enabled = true,
  speed = 3,
  bezier = "standardDecel",
})
