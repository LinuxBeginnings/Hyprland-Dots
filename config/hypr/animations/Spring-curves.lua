-- Spring Curves
-- HL 0.56+ advances springs by real wall-clock time (no min tick floor).
-- Pre-0.56 soft values (mass ~2, stiffness ~15-30) feel sluggish now.
-- Speed on spring animations is largely ignored; stiffness/mass/dampening set pace.
hl.curve("spring_fast", { type = "spring", mass = 1, stiffness = 280, dampening = 26 })
hl.curve("spring_slow", { type = "spring", mass = 1, stiffness = 160, dampening = 24 })

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
