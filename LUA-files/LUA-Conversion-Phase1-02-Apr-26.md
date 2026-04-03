cat > /home/dwilliams/Hyprland-Dots/LUA-files/LUA-conversion-phase1-date.md <<'EOF'
# LUA conversion phase 1 report
Date: 2026-04-03

## Scope completed
Phase 1 conversion was applied to `config/hypr` (live config path), while keeping `LUA-files/` as reference material.

### `LUA-files/` updates
- Renamed existing sample:
  - `LUA-files/hyprland.lua` -> `LUA-files/hyprland-default-cfg.lua`
- Added new reference entry:
  - `LUA-files/hyprland.lua`

### New live Lua config entry
- `config/hypr/hyprland.lua`

### New Lua modules under live config
- `config/hypr/lua/env.lua`
- `config/hypr/lua/startup.lua`
- `config/hypr/lua/settings.lua`
- `config/hypr/lua/decorations.lua`
- `config/hypr/lua/animations.lua`
- `config/hypr/lua/monitors.lua`
- `config/hypr/lua/workspaces.lua`
- `config/hypr/lua/user_defaults.lua`
- `config/hypr/lua/laptops.lua`
- `config/hypr/lua/keybinds.lua` (stub)
- `config/hypr/lua/window_rules.lua` (stub)
- `config/hypr/lua/user_overrides.lua` (stub)

## Converted in phase 1
- Environment variables
- Startup commands
- System settings (general, input, misc, xwayland, render, cursor, layout sections)
- Decorations
- Animations
- Monitor definitions
- Workspace scaffold (no active workspace rules were present to migrate)

## Deferred (parity pending)
- Keybind conversion from `bindd`/`bindld`/`bindlnd`/`binded`/`bindmd` style entries
- Window/layer rules conversion, including named `windowrule { ... }` blocks
- Wallust color source parity from hyprlang sourced file to Lua-native flow

## Validation
- Lua syntax checks passed using `luac -p` on:
  - `config/hypr/hyprland.lua`
  - all files under `config/hypr/lua/*.lua`
  - `LUA-files/hyprland.lua`

## Notes
- `config/hypr/hyprland.conf` remains available as fallback while Lua parity is still incomplete.
- Current Lua setup is intentionally partial but runnable for supported sections.

