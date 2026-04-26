# Lua conversion phase 2
Date: 2026-04-26
Branch: LUA-conversion
## Scope
Phase 2 focused on making the Lua entrypoint usable on the current Hyprland Lua-enabled build and adding an opt-in migration helper for installed configs.
The normal `hyprland.conf` path remains available as fallback. This phase does not make Lua the default installer path.
## Files updated
- `config/hypr/hyprland.lua`
- `config/hypr/lua/keybinds.lua`
- `config/hypr/lua/startup.lua`
- `config/hypr/lua/settings.lua`
- `config/hypr/lua/animations.lua`
- `scripts/migrate-hypr-to-lua.sh`
## Entrypoint fix
`config/hypr/hyprland.lua` now loads modules with `dofile()` from the active config directory instead of `require("lua.*")`.
Reason:
- Hyprland's embedded Lua package path did not resolve `require("lua.startup")` and similar module names reliably.
- The runtime config error output showed repeated `module 'lua.*' not found` messages even when the module files existed in `~/.config/hypr/lua`.
Current approach:
- Resolve config root from `XDG_CONFIG_HOME` or `$HOME/.config`.
- Build `hyprDir = configHome .. "/hypr"`.
- Load modules with `dofile(hyprDir .. "/lua/<module>.lua")`.
## Keybind fixes
`config/hypr/lua/keybinds.lua` now wraps generated binds with a compatibility layer.
Fixes applied:
- Changed generated binds from separate argument style to the current Lua API shape:
  - old generated shape: `hl.bind(mods, key, fn, opts)`
  - new wrapped shape: `hl.bind("MOD + key", fn, opts)`
- Normalizes modifier strings such as `SUPER CTRL SHIFT` to `SUPER + CTRL + SHIFT`.
- Converts `code:10` through `code:19` to `1` through `0` because Lua key parsing rejected `code:*` names.
- Normalizes common XF86 key casing.
- Maps `XF86AudioPlayPause` to `XF86AudioPlay` because the current Lua key parser rejected `XF86AudioPlayPause`.
- Converts generated `exec, ...` dispatcher arguments into command execution.
- Adds fallback handling for generated description/dispatcher mixups such as mouse move/resize binds.
Known limitation:
- The Lua branch key parser does not currently appear to accept every legacy hyprlang key token exactly as-is. The wrapper maps the keys that caused startup errors, but future generated keybinds may need more aliases.
Follow-up after runtime testing:
- A direct `exec_cmd(cmd) -> hl.exec_cmd(cmd)` helper was tested and reverted because it destabilized Hyprland during config load.
- The safer callback form is retained for command fallback paths:
  - `return function() hl.exec_cmd(cmd) end`
- Known Lua-native helpers are now used for core non-shell actions instead of routing those through `hyprctl dispatch`:
  - `killactive` -> `hl.window.close()`
  - `togglefloating` -> `hl.window.float({ action = "toggle" })`
  - `pseudo` -> `hl.window.pseudo()`
  - `workspace` -> `hl.workspace(...)`
  - `movetoworkspace` -> `hl.window.move({ workspace = ... })`
  - `movefocus` -> `hl.focus({ direction = ... })`
  - `layoutmsg` -> `hl.layout(...)`
  - mouse `movewindow` -> `hl.window.drag()`
  - mouse `resizewindow` -> `hl.window.resize()`
- `fullscreen`, `movetoworkspacesilent`, `swapwindow`, group actions, and other less certain dispatchers remain fallback paths until their Lua API equivalents are confirmed.
- Runtime testing should keep `~/.config/hypr/hyprland.lua` disabled by default and only enable Lua inside a disposable VM snapshot.
## Startup fixes
`config/hypr/lua/startup.lua` no longer assumes `hl.exec_once` exists.
Fixes applied:
- Added local `exec_once(cmd)` wrapper.
- If `hl.exec_once` exists, it is used.
- Otherwise startup commands fall back to `hl.exec_cmd(cmd)`.
Reason:
- Startup failed with `attempt to call a nil value (field 'exec_once')` on the tested build.
Known limitation:
- Falling back to `hl.exec_cmd` may not provide perfect `exec-once` semantics if the Lua API does not expose a true once-only call. This is acceptable for testing but should be revisited when the upstream Lua API stabilizes.
## Settings fixes
`config/hypr/lua/settings.lua` was adjusted for Lua config validation.
Fixes applied:
- `input.touchpad["tap-to-click"]` changed to `input.touchpad.tap_to_click`.
- `misc.enable_swallow = "off"` changed to `misc.enable_swallow = false`.
Reason:
- Hyprland reported `unknown config key 'input.touchpad.tap-to-click'`.
- Hyprland reported `misc.enable_swallow` requires a boolean.
## Animation fixes
`config/hypr/lua/animations.lua` caps `borderangle` speed at `100`.
Reason:
- Hyprland reported `hl.animation("borderangle"): field "speed": value 180 is more than the maximum of 100.00`.
## Migration helper
Added `scripts/migrate-hypr-to-lua.sh`.
Purpose:
- Provide an opt-in way to copy the repo Lua config into an installed Hyprland config directory for testing.
- Keep normal install/upgrade behavior unchanged.
Behavior:
- Detects the source repo config under `config/hypr`.
- Targets `${XDG_CONFIG_HOME:-$HOME/.config}/hypr`.
- Verifies `config/hypr/hyprland.lua` and `config/hypr/lua/` exist.
- Shows detected `Hyprland --version` when available.
- Creates a full backup of the installed Hypr config before changing files:
  - `~/.config/hypr-backup-lua-YYYYMMDD-HHMMSS`
- Copies:
  - `config/hypr/hyprland.lua`
  - `config/hypr/lua/`
- Preserves `hyprland.conf` as fallback.
- Supports:
  - `--yes`
  - `--dry-run`
  - `--help`
Rollback:
- Rename or remove the installed Lua entrypoint:
  - `mv ~/.config/hypr/hyprland.lua ~/.config/hypr/hyprland.lua.disabled`
## Validation performed
Validation commands used during phase 2:
- `luac -p config/hypr/hyprland.lua config/hypr/lua/*.lua`
- `bash -n scripts/migrate-hypr-to-lua.sh`
- `scripts/migrate-hypr-to-lua.sh --dry-run --yes`
- `scripts/migrate-hypr-to-lua.sh --yes`
- `hyprctl reload && hyprctl configerrors`
Observed result after syncing to the active config and reloading:
- `hyprctl reload` returned `ok`.
- `hyprctl configerrors` returned no errors.
## Current status
Lua config can now load without the startup errors seen in phase 2 testing:
- no `require("lua.*")` module lookup errors
- no `XF86AudioPlayPause` parse error
- no `code:10` through `code:19` parse errors
- no missing `hl.exec_once` crash
- no `tap-to-click` unknown key error
- no `enable_swallow` type error
- no `borderangle` speed validation error
## Remaining work
The Lua conversion is still partial. Recommended next steps:
1. Convert window and layer rules.
   - Fill out `config/hypr/lua/window_rules.lua`.
   - Confirm Lua API parity for `windowrule`, `layerrule`, and named rule blocks.
2. Convert Wallust color integration.
   - Replace the current static color fallback in `decorations.lua`.
   - Prefer a Lua-generated Wallust file if the template flow supports it.
3. Convert dynamic Hyprland config writers.
   - `config/hypr/scripts/MonitorProfiles.sh`
   - `config/hypr/scripts/Animations.sh`
   - `config/hypr/scripts/update_WindowRules.sh`
   - `config/hypr/UserScripts/WallpaperSelect.sh`
   - `config/hypr/scripts/ThemeChanger.sh`
   - `config/hypr/scripts/WallustSwww.sh`
4. Improve keybind generation.
   - Move key aliases and dispatcher mapping into the generator instead of only the generated file.
   - Add strict mode so unsupported key names or dispatchers are detected before startup.
   - Confirm native Lua helpers for fullscreen, silent workspace moves, swap window, group actions, and monitor workspace moves before enabling those by default.
5. Decide installer integration.
   - Keep Lua migration opt-in until parity is complete.
   - Later add a `copy.sh` prompt such as `Use experimental Hyprland Lua config? [y/N]`.
6. Add runtime smoke tests.
   - Reload Hyprland and check `hyprctl configerrors`.
   - Test core binds: app launcher, terminal, close active window, workspace switching, media keys, screenshot keys, and mouse move/resize binds.
