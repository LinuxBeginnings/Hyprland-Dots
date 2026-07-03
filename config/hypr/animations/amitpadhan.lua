-- 💫 https://github.com/LinuxBeginnings 💫
-- Inspired by amitpadhan525
-- https://github.com/amitpadhan525

hl.config({
  animations = {
    enabled = true,
  },
})

hl.curve("myBezier", { type = "bezier", points = { { 0.05, 0.9 }, { 0.1, 1.0 } } })

hl.animation({ leaf = "windows", enabled = true, speed = 5, bezier = "myBezier" })
hl.animation({ leaf = "windowsIn", enabled = true, speed = 5, bezier = "myBezier" })
hl.animation({ leaf = "windowsOut", enabled = true, speed = 5, bezier = "myBezier" })
hl.animation({ leaf = "windowsMove", enabled = true, speed = 5, bezier = "myBezier" })
hl.animation({ leaf = "layers", enabled = true, speed = 5, bezier = "myBezier" })
hl.animation({ leaf = "layersIn", enabled = true, speed = 5, bezier = "myBezier" })
hl.animation({ leaf = "layersOut", enabled = true, speed = 5, bezier = "myBezier" })
hl.animation({ leaf = "border", enabled = true, speed = 10, bezier = "default" })
hl.animation({ leaf = "borderangle", enabled = true, speed = 8, bezier = "default" })
hl.animation({ leaf = "fade", enabled = true, speed = 5, bezier = "default" })
hl.animation({ leaf = "fadeLayersIn", enabled = true, speed = 5, bezier = "myBezier" })
hl.animation({ leaf = "fadeLayersOut", enabled = true, speed = 5, bezier = "myBezier" })
hl.animation({ leaf = "workspaces", enabled = true, speed = 5, bezier = "myBezier", style = "slidefade 20%" })
hl.animation({ leaf = "workspacesIn", enabled = true, speed = 5, bezier = "myBezier", style = "slide" })
hl.animation({ leaf = "workspacesOut", enabled = true, speed = 5, bezier = "myBezier", style = "slide" })
hl.animation({ leaf = "specialWorkspace", enabled = true, speed = 5, bezier = "myBezier", style = "slidevert" })
