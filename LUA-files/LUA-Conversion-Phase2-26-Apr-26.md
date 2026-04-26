# Lua conversion phase 2
Date: 2026-04-26
Branch: LUA-conversion
## Scope
Phase 2 focused on making the Lua entrypoint usable on the current Hyprland Lua-enabled build and adding an opt-in migration helper for installed configs.
The normal `hyprland.conf` path remains available as fallback. This phase does not make Lua the default installer path.
## References
- Hyprland Lua branch source: https://github.com/vaxerski/Hyprland/tree/lua-lua-lua-lua-lua-lua-lua
- Hyprland Lua utilities wiki: https://wiki.hypr.land/Configuring/Advanced-and-Cool/Expanding-functionality/#lua-utilities
## Files updated
- `config/hypr/hyprland.lua`
- `config/hypr/lua/keybinds.lua`
- `config/hypr/lua/startup.lua`
- `config/hypr/lua/settings.lua`
- `config/hypr/lua/animations.lua`
- `config/waybar/ModulesWorkspaces`
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
- Converts unshifted `code:10` through `code:19` to `1` through `0` because Lua key parsing rejected `code:*` names.
- Converts shifted number-row workspace move binds to shifted XKB keysyms so `SUPER SHIFT 3` maps to `numbersign` instead of unshifted `3`.
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
- Confirmed current dispatcher API is under `hl.dsp`.
- Known Lua-native helpers are now used for core non-shell actions instead of routing those through `hyprctl dispatch`:
  - `killactive` -> `hl.dsp.window.close()`
  - `togglefloating` -> `hl.dsp.window.float({ action = "toggle" })`
  - `fullscreen` -> `hl.dsp.window.fullscreen({ mode = "fullscreen" })`
  - `pseudo` -> `hl.dsp.window.pseudo()`
  - `workspace` -> `hl.dsp.focus({ workspace = ... })`
  - `movetoworkspace` -> `hl.dsp.window.move({ workspace = ... })`
  - `movetoworkspacesilent` -> `hl.dsp.window.move({ workspace = ..., follow = false })`
  - `movefocus` -> `hl.dsp.focus({ direction = ... })`
  - `layoutmsg` -> `hl.dsp.layout(...)`
  - keyboard `resizeactive` -> `hl.dsp.window.resize({ x = ..., y = ..., relative = true })`
  - mouse `movewindow` -> `hl.dsp.window.drag()`
  - mouse `resizewindow` -> `hl.dsp.window.resize()`
- `swapwindow`, group actions, and monitor workspace moves have Lua helper mappings in the wrapper but still need runtime smoke testing before treating Lua parity as complete.
- Runtime testing should keep `~/.config/hypr/hyprland.lua` disabled by default and only enable Lua inside a disposable VM snapshot.
Follow-up after shifted workspace bind testing:
- `SUPER SHIFT 3` failed when generated `code:12` was converted to unshifted `3`; the Lua key parser matches XKB keysyms, so shifted number-row binds must use shifted keysyms.
- After reboot testing, `SUPER SHIFT 2` still failed with only `at` registered. The wrapper now registers a second shifted number-row fallback using the unshifted digit key as well, so `SUPER SHIFT 2` has both `at` and `2` Lua bind variants.
- Current shifted code map is:
  - `code:10` -> `exclam`
  - `code:11` -> `at`
  - `code:12` -> `numbersign`
  - `code:13` -> `dollar`
  - `code:14` -> `percent`
  - `code:15` -> `asciicircum`
  - `code:16` -> `ampersand`
  - `code:17` -> `asterisk`
  - `code:18` -> `parenleft`
  - `code:19` -> `parenright`
Mouse bind fix:
- The generated mouse move/resize binds originally passed `{ mouse = true }`.
- The Lua `hl.bind` API does not read an option named `mouse`.
- The Lua `{ drag = true }` option is not equivalent to legacy `bindm`; it delays the bind until a drag threshold is exceeded and the button is released.
- The wrapper now strips the generated `mouse` option and lets `hl.dsp.window.drag()` / `hl.dsp.window.resize()` run on mouse-button press, which is closer to legacy `bindm` behavior for `SUPER + left mouse` move and `SUPER + right mouse` resize.
- Runtime testing confirmed `SUPER + left mouse` moves windows, but `SUPER + right mouse` resize may still be limited by the current Lua `__lua` dispatcher not preserving the legacy mouse dispatcher press/release path.
Keyboard resize fix:
- `SUPER SHIFT left/right/up/down` originally fell back through shell execution of `hyprctl dispatch resizeactive ...`.
- The wrapper now maps `resizeactive` to native relative Lua resize calls:
  - `resizeactive, -50 0` -> `hl.dsp.window.resize({ x = -50, y = 0, relative = true })`
  - `resizeactive, 50 0` -> `hl.dsp.window.resize({ x = 50, y = 0, relative = true })`
  - `resizeactive, 0 -50` -> `hl.dsp.window.resize({ x = 0, y = -50, relative = true })`
  - `resizeactive, 0 50` -> `hl.dsp.window.resize({ x = 0, y = 50, relative = true })`
## Startup fixes
`config/hypr/lua/startup.lua` no longer assumes `hl.exec_once` exists.
Fixes applied:
- Added local `exec_once(cmd)` wrapper.
- If `hl.exec_once` exists, it is used.
- Otherwise startup commands are executed with `hl.dispatch(hl.dsp.exec_cmd(cmd))`.
- The fallback wraps commands with per-session marker files under `/tmp/hypr-lua-exec-once-*` so reloads do not repeatedly launch startup apps.
Reason:
- Startup failed with `attempt to call a nil value (field 'exec_once')` on the tested build.
- Reboot testing showed Waybar did not start because `hl.exec_cmd(cmd)` returns a dispatcher function on the current Lua branch; it does not execute the command unless dispatched.
Known limitation:
- The marker-file fallback approximates `exec-once` semantics for the current Hyprland session. Revisit this when the upstream Lua API exposes a native once-only startup helper.
## Waybar workspace dispatch caveat
Under the Lua config manager, old external dispatch commands such as `hyprctl dispatch workspace 2` are parsed as Lua and fail with syntax errors.
Confirmed working external syntax:
- `hyprctl dispatch 'hl.dsp.focus({ workspace = "2" })'`
- `hyprctl dispatch 'hl.dsp.focus({ workspace = "e+1" })'`
Fix applied:
- `config/waybar/ModulesWorkspaces` now uses Lua-compatible scroll commands:
  - `on-scroll-up` -> `hyprctl dispatch 'hl.dsp.focus({ workspace = "e+1" })'`
  - `on-scroll-down` -> `hyprctl dispatch 'hl.dsp.focus({ workspace = "e-1" })'`
Known limitation:
- Waybar 0.15's `hyprland/workspaces` button click handler is hardcoded in Waybar and sends Hyprland IPC requests such as `dispatch workspace <id>` directly; it does not use the `on-click` string for individual workspace buttons.
- Because that internal Waybar path still emits legacy dispatcher syntax, workspace clicks can fail under the Lua config manager until Waybar is patched to send Lua dispatcher strings or Hyprland adds a compatibility path for legacy external dispatch syntax.
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
Runtime caveat:
- A later diagnostic session showed `hyprctl binds` output matching `hyprland.conf` descriptions, meaning that session appeared to be using the hyprlang config manager rather than proving Lua entrypoint behavior.
- `hyprctl version` may still report `0.54.0` for a source build because `0.55` has not been released yet; do not treat the version string alone as proof that Lua support is missing.
- On the Lua branch source, regular config discovery should use `hyprland.lua` when present. If `hyprctl binds` continues to show legacy descriptions after installing Lua files, confirm the session was launched after `hyprland.lua` existed and that the binary was built from the Lua-enabled source branch.
## Current status
Lua config can now load without the startup errors seen in phase 2 testing:
- no `require("lua.*")` module lookup errors
- no `XF86AudioPlayPause` parse error
- no `code:10` through `code:19` parse errors
- shifted number-row workspace move binds now map to shifted keysyms for Lua matching
- shifted number-row workspace move binds also register unshifted digit fallbacks for runtime matching
- no missing `hl.exec_once` crash
- Waybar starts from the Lua startup fallback
- mouse move/resize binds run the native Lua mouse dispatchers on button press
- keyboard resize binds use native relative Lua resize calls
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
