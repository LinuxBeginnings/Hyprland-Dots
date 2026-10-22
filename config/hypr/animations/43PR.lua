-- 💫 https://github.com/LinuxBeginnings 💫
-- PR43

hl.config({
  animations = {
    enabled = true,
  },
})

hl.curve("easeOut", { type = "bezier", points = { { 0.05, 0.9 }, { 0.1, 1.0 } } })

hl.animation({ leaf = "windows", enabled = true, speed = 5, bezier = "easeOut" })
hl.animation({ leaf = "windowsOut", enabled = true, speed = 5, bezier = "easeOut" })
hl.animation({ leaf = "border", enabled = true, speed = 5, bezier = "default" })
hl.animation({ leaf = "fade", enabled = true, speed = 4, bezier = "default" })
hl.animation({ leaf = "workspaces", enabled = true, speed = 6, bezier = "default", style = "slidefadevert" })
