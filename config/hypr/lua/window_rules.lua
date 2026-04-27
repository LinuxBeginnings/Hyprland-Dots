-- Placeholder for conversion from:
-- - config/hypr/configs/WindowRules.conf
-- - config/hypr/UserConfigs/WindowRules.conf

hl.window_rule({
  name = "dropterminal",
  match = { class = "kitty-dropterm" },
  float = true,
  size = "1248 702",
  move = "336 108",
  pin = true,
})
