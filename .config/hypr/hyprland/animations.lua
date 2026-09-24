hl.config({
    animations = {
        enabled = true,
    },
})

-- Animation curves
hl.curve("native",    { type = "bezier", points = { { 0.15, 1.0 },  { 0.4, 1.0 } } })
hl.curve("spring",    { type = "bezier", points = { { 0.2, 1.15 },  { 0.4, 1.0 } } })
hl.curve("springWS",  { type = "bezier", points = { { 0.2, 1.25 },  { 0.4, 1.0 } } })
hl.curve("springPop", { type = "bezier", points = { { 0.175, 1.1 }, { 0.32, 1.0 } } })
hl.curve("close",     { type = "bezier", points = { { 0.4, 0.0 },   { 0.75, 0.9 } } })
hl.curve("fadeFlow",  { type = "bezier", points = { { 0.25, 1.0 },  { 0.5, 1.0 } } })
hl.curve("borderPop", { type = "bezier", points = { { 0.2, 1.3 },   { 0.4, 1.0 } } })

-- Animation targets
hl.animation({ leaf = "workspaces",       enabled = true, speed = 6, bezier = "springWS", style = "slidevert" })
hl.animation({ leaf = "specialWorkspace", enabled = true, speed = 5, bezier = "springWS", style = "slidevert" })
hl.animation({ leaf = "windowsIn",        enabled = true, speed = 6, bezier = "spring" })
hl.animation({ leaf = "windowsOut",       enabled = true, speed = 4, bezier = "close" })
hl.animation({ leaf = "windowsMove",      enabled = true, speed = 6, bezier = "spring" })
hl.animation({ leaf = "layersIn",         enabled = true, speed = 5, bezier = "springPop" })
hl.animation({ leaf = "layersOut",        enabled = true, speed = 3, bezier = "close" })
hl.animation({ leaf = "fadeLayers",       enabled = true, speed = 4, bezier = "fadeFlow" })
