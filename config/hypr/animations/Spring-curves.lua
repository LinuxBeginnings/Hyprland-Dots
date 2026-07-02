-- Spring Curves
hl.curve("spring_fast", { type = "spring", mass = 2, stiffness = 30, dampening = 15 })
hl.curve("spring_slow", { type = "spring", mass = 2, stiffness = 15, dampening = 10 })

-- Window animations
hl.animation({ leaf = "windows", enabled = true, speed = 1, spring = "spring_fast" })
hl.animation({ leaf = "windowsIn", enabled = true, speed = 1, spring = "spring_fast", style = "popin 50%" })
hl.animation({ leaf = "windowsOut", enabled = true, speed = 1, spring = "spring_fast", style = "popin" })

-- Border animations
hl.animation({ leaf = "border", enabled = true, speed = 1, spring = "spring_slow" })
hl.animation({ leaf = "borderangle", enabled = false })

-- Fade
hl.animation({ leaf = "fade", enabled = true, speed = 1, spring = "spring_slow" })

-- Zoom cursor
hl.animation({ leaf = "zoomFactor", enabled = true, speed = 6, spring = "spring_fast" })

-- Layer animations
hl.animation({ leaf = "layersIn", enabled = true, speed = 3, spring = "spring_fast", style = "slide" })
hl.animation({ leaf = "layersOut", enabled = true, speed = 1.6, spring = "spring_fast", style = "slide" })
hl.animation({ leaf = "fadeLayersIn", enabled = true, speed = 2, spring = "spring_fast" })
hl.animation({ leaf = "fadeLayersOut", enabled = true, speed = 1.6, spring = "spring_fast" })

-- Workspace animations
hl.animation({ leaf = "workspaces", enabled = true, speed = 1, spring = "spring_slow", style = "slide" })
hl.animation({ leaf = "specialWorkspace", enabled = true, speed = 1, spring = "spring_slow", style = "slidevert 80%" })
