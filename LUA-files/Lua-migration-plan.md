# Hyprland Lua migration plan
## Upstream status and constraints
- Upstream PR: https://github.com/hyprwm/Hyprland/pull/13817 (draft, WIP).
- Lua config is used automatically if `hyprland.lua` exists next to `hyprland.conf` and is only checked at startup.
- The PR explicitly notes missing hyprlang parity and requests feedback; verify gaps in `src/config` before finalizing.
- The example Lua config in `LUA-files/hyprland.lua` matches the PR sample style (`hl.*` API).

## Current config structure in this repo
Entry point:
- `config/hypr/hyprland.conf` sources the following files in order:
  - `config/hypr/configs/Keybinds.conf`
  - `config/hypr/configs/Startup_Apps.conf`
  - `config/hypr/UserConfigs/Startup_Apps.conf`
  - `config/hypr/configs/ENVariables.conf`
  - `config/hypr/UserConfigs/ENVariables.conf`
  - `config/hypr/configs/Laptops.conf`
  - `config/hypr/UserConfigs/Laptops.conf`
  - `config/hypr/UserConfigs/LaptopDisplay.conf`
  - `config/hypr/configs/WindowRules.conf`
  - `config/hypr/UserConfigs/WindowRules.conf`
  - `config/hypr/configs/SystemSettings.conf`
  - `config/hypr/UserConfigs/UserDecorations.conf`
  - `config/hypr/UserConfigs/UserAnimations.conf`
  - `config/hypr/UserConfigs/UserKeybinds.conf`
  - `config/hypr/UserConfigs/UserSettings.conf`
  - `config/hypr/UserConfigs/01-UserDefaults.conf`
  - `config/hypr/monitors.conf`
  - `config/hypr/workspaces.conf`

Key areas to migrate:
- Environment variables: `configs/ENVariables.conf`, `UserConfigs/ENVariables.conf`
- Startup commands: `configs/Startup_Apps.conf`, `UserConfigs/Startup_Apps.conf`
- Settings: `configs/SystemSettings.conf`, `UserConfigs/UserSettings.conf`
- Decorations/animations: `UserConfigs/UserDecorations.conf`, `UserConfigs/UserAnimations.conf`
- Keybinds: `configs/Keybinds.conf`, `UserConfigs/UserKeybinds.conf`, `configs/Laptops.conf`, `UserConfigs/Laptops.conf`
- Window/layer rules: `configs/WindowRules.conf`, `UserConfigs/WindowRules.conf`
- Monitor/workspace rules: `monitors.conf`, `workspaces.conf`, `UserConfigs/LaptopDisplay.conf`
- Wallust colors: `config/hypr/wallust/wallust-hyprland.conf` is sourced by `UserDecorations.conf`

## Migration approach
### 1) Establish Lua entry point
- Create `config/hypr/hyprland.lua` and keep `config/hypr/hyprland.conf` temporarily for fallback.
- Mirror the current include order using `require` and/or Lua module functions.
- Use `LUA-files/hyprland.lua` as a template for overall layout.

### 2) Split into Lua modules aligned with current files
Create a Lua structure that mirrors the current modular layout for maintainability:
- `config/hypr/lua/env.lua` (env vars)
- `config/hypr/lua/startup.lua` (exec-once)
- `config/hypr/lua/settings.lua` (general/input/misc/dwindle/master/scrolling/etc)
- `config/hypr/lua/decorations.lua`
- `config/hypr/lua/animations.lua`
- `config/hypr/lua/keybinds.lua`
- `config/hypr/lua/window_rules.lua`
- `config/hypr/lua/monitors.lua`
- `config/hypr/lua/workspaces.lua`
- `config/hypr/lua/user_defaults.lua`
- `config/hypr/lua/laptops.lua`
- `config/hypr/lua/user_overrides.lua` (optional, for user-specific overrides)

Then in `hyprland.lua`:
- `require("lua.env")`, `require("lua.startup")`, etc., in the same order currently used by `hyprland.conf`.

### 3) Mapping rules (hyprlang → Lua)
Use the upstream Lua API (from PR 13817 / `LUA-files/hyprland.lua`):
- `monitor = ...` → `hl.monitor({ ... })`
- `env = KEY,VALUE` → `hl.env("KEY", "VALUE")`
- `exec-once = CMD` → `hl.exec_once("CMD")` (or `hl.exec_once(cmd_var)` for variables)
- `general { ... }` → `hl.config({ general = { ... } })`
- `decoration { ... }` → `hl.config({ decoration = { ... } })`
- `animations { ... }` → `hl.config({ animations = { ... } })` plus `hl.curve(...)` / `hl.animation(...)`
- `input { ... }` → `hl.config({ input = { ... } })` + `hl.device({ ... })` as needed
- `dwindle`, `master`, `scrolling`, `misc`, `cursor`, `render`, `xwayland`, `binds` → `hl.config({ section = { ... } })`
- `gesture = ...` → `hl.gesture({ ... })`
- `bind* = ...` → `hl.bind(...)` (verify the exact Lua binding helpers and options in the PR source)
- `windowrule` blocks → `hl.window_rule({ name = "...", match = { ... }, ... })`
- `layerrule = ...` → verify `hl.layer_rule(...)` or equivalent in the PR source (not shown in the sample)

### 4) Handle `source` and external generated files
`UserDecorations.conf` currently sources `wallust-hyprland.conf` (hyprlang).
Options:
- Preferred: have Wallust generate a Lua file (if supported) and `require` it.
- Alternative: expose colors via environment variables (Wallust can export), then refer to those in Lua.
- Last resort: keep a small hyprlang file and check if Lua supports `hl.source(...)` or similar (requires verifying upstream support).

### 5) Convert keybinds thoughtfully
Keybinds are heavy and use `bindd`, `bindld`, `bindlnd`, `bindmd`, etc.
Plan:
- Build a mapping table for each bind type and its equivalent Lua options (repeat, locked, mouse, etc).
- Move shared variables (`$mainMod`, `$scriptsDir`, `$UserScripts`) into Lua locals.
- Convert in batches (e.g., standard binds, system binds, layouts, media keys, workspace binds).
- Verify with existing tooling: `config/hypr/scripts/keybinds_parser.py` can be adapted or replaced for Lua if needed.

### 6) Convert window rules and layer rules
The rule sets are large and use both single-line rules and block-style rules.
Plan:
- First convert single-line rules into `hl.window_rule({ match = { ... }, ... })`.
- Then convert named blocks (`windowrule { name = ... }`) to equivalent Lua table calls.
- For `layerrule` entries, confirm Lua API support and mirror semantics.

### 7) Validate with upstream gaps
Before final cutover:
- Diff your needed keywords against the PR list in `src/config` (since the PR notes missing hyprlang parity).
- Track any missing features as temporary fallbacks or TODOs in the Lua files.

### 8) Cutover and verification
- Place `config/hypr/hyprland.lua` alongside `hyprland.conf`.
- Start Hyprland and verify that Lua config is picked up.
- Compare runtime behavior: keybinds, workspace rules, animations, window rules, and env vars.
- Use `hyprctl` to verify applied settings.

## Phased migration checklist
Phase 1 (low-risk):
- env vars
- monitors
- basic settings (general/input/misc/dwindle/master/scrolling)
Phase 2:
- startup apps
- decorations/animations
Phase 3:
- keybinds
- window rules / layer rules
Phase 4:
- workspace rules
- laptop-specific overrides
Phase 5:
- remove or archive `hyprland.conf` once parity is confirmed

## Phase 2 status update
Completed fixes from the current Lua migration test cycle:
- User-local overrides are now part of the migration path. When present, `~/.config/hypr/UserConfigs/WindowRules.conf` and `~/.config/hypr/UserConfigs/UserKeybinds.conf` are converted into `~/.config/hypr/lua/user_overrides.lua`.
- `SUPER+F` user override now maps legacy `fullscreen, 1` to maximized fullscreen through `config/hypr/scripts/LuaFullscreenMaximized.sh`. This avoids the current Lua window fullscreen helper no-op for maximized mode.
- Duplicate single-letter key variants were removed from the keybind conversion path. This prevents one physical `SUPER+F` press from firing both `F` and `f` bindings and immediately toggling maximized fullscreen back off.
- `SUPER+SHIFT+F` remains the default normal fullscreen binding, while `SUPER+F` is the user maximized fullscreen override.
- Waybar workspace scrolling was converted to Lua-compatible Hyprland dispatch commands using `hyprctl dispatch 'hl.dsp.focus({ workspace = "e+1" })'` and `e-1`.
- Waybar workspace clicks remain blocked by Waybar's built-in `hyprland/workspaces` click dispatcher, which still sends legacy `dispatch workspace <id>` calls. Fixing clicks requires either a Waybar patch/rebuild or replacing the module with custom click handlers.
- Waybar startup now uses a delayed guarded exec-once command: `sh -c "sleep 2; pgrep -x waybar >/dev/null || exec waybar"`. This avoids the reboot/login race where the exec-once marker was created but Waybar exited before staying resident.
- `Virtual-1` monitor mode was verified to accept `1920x1080@60.00Hz`; a reboot resolved the mode application issue after `hl.monitor(...)` eval/reload did not live-apply the change.

Validation notes:
- `hyprctl configerrors` is clean after the latest startup changes.
- `hyprctl reload` successfully loads the updated Lua startup file.
- Waybar starts after reload with the delayed guarded command.
- `SUPER+F` was verified to set the active window to maximized fullscreen state (`fullscreen=1`) after removing duplicate `F`/`f` binds.

Suggested next steps:
- Reboot once more and confirm Waybar starts without manual intervention, since the fix targets login timing.
- Run the migration script from a clean pre-Lua backup and verify that `user_overrides.lua` is generated correctly for both `WindowRules.conf` and `UserKeybinds.conf`.
- Add a small regression check for duplicate letter key variants so future conversion work does not reintroduce double-firing binds.
- Decide whether Waybar workspace click support should be handled by patching Waybar or by replacing the built-in workspace module with custom scripts.
- Continue converting and validating remaining user config files, especially `Startup_Apps.conf`, `Laptops.conf`, `LaptopDisplay.conf`, and any workspace/laptop-specific overrides.
- Track Lua API gaps separately from repo conversion bugs, especially monitor live-apply behavior, mouse resize bindings, and any helpers that require shell fallbacks.

## Is a migration tool worth it?
Recommendation: a full automatic converter is likely not worth the effort right now.
Rationale:
- The Lua API is still WIP and not fully documented (PR is draft).
- This repo has custom constructs (bind variants, block-style window rules, `source` usage, and dynamic scripts) that are hard to transform reliably.
- A naive converter would still require manual cleanup, so the overall time savings would be limited.

If a helper is desired:
- Build a small, focused converter for the easiest wins:
  - `env = KEY,VALUE` → `hl.env("KEY","VALUE")`
  - `exec-once = ...` → `hl.exec_once("...")`
  - simple `monitor = ...` lines → `hl.monitor({ ... })`
  - basic `bind*` lines → Lua bind calls (validate with upstream API)
- Keep it as a one-off script in `config/hypr/scripts/` and document its limitations.

## Open questions / follow-ups
- Confirm Lua equivalents for `bindd`, `bindld`, `bindlnd`, `bindmd`, and `binded`.
- Confirm Lua support for layer rules and for including non-Lua files.
- Decide how Wallust-generated colors will be consumed in Lua.
- Decide final module layout and naming conventions (mirror `configs/` and `UserConfigs/` or merge).
