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
- `config/hypr/scripts/LuaFullscreenMaximized.sh`
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
User maximized fullscreen override:
- User-local `SUPER+F` from `UserConfigs/UserKeybinds.conf` maps legacy `fullscreen, 1` to maximized fullscreen.
- Native Lua fullscreen helpers were able to handle normal fullscreen but maximized fullscreen did not reliably apply from generated binds on the tested Lua branch.
- The migration helper now converts `fullscreen, 1` to `exec_cmd((os.getenv("HOME") or "") .. "/.config/hypr/scripts/LuaFullscreenMaximized.sh")`.
- `config/hypr/scripts/LuaFullscreenMaximized.sh` runs a short detached helper:
  - `setsid -f sh -c 'sleep 0.2; hyprctl dispatch "hl.dsp.window.fullscreen({ mode = 1 })"' >/dev/null 2>&1`
- Duplicate letter key variants were removed from generated user overrides. Binding both `F` and `f` caused one physical `SUPER+F` press to fire twice and toggle maximized fullscreen back off.
- Runtime validation showed only one `SUPER+F` user override after duplicate removal, while `SUPER+SHIFT+F` remained the default normal fullscreen binding.
- `SUPER+F` was verified by `hyprctl activewindow -j` setting the active window to maximized fullscreen state (`fullscreen=1`, `fullscreenClient=1`).
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
Waybar startup race fix:
- After reboot, Waybar did not stay running even though the `/tmp/hypr-lua-exec-once-*waybar` marker existed.
- Manual foreground startup of `waybar` succeeded, so the issue was treated as a login timing race rather than a Waybar config error.
- The active and repo Lua startup files now launch Waybar with a delayed guarded command:
  - `sh -c "sleep 2; pgrep -x waybar >/dev/null || exec waybar"`
- Validation after `hyprctl reload` showed Waybar and `waybar-weather` running with no config errors.
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
## Monitor runtime note
Manual runtime monitor changes under the Lua config manager require Lua eval syntax rather than legacy `hyprctl keyword monitor ...`.
Commands tested:
- `hyprctl eval 'hl.monitor({ output = "Virtual-1", mode = "1920x1080@60", position = "auto", scale = 1 })'`
- `hyprctl eval 'hl.monitor({ output = "Virtual-1", mode = "1920x1080@60.00Hz", position = "0x0", scale = "1" })'`
Observed behavior:
- `hyprctl monitors all -j` showed `Virtual-1` advertised `1920x1080@60.00Hz`.
- `hl.monitor(...)` eval and `hyprctl reload` returned `ok`, but the live session stayed at `1280x800@74.99`.
- A reboot applied the configured `Virtual-1` resolution.
Follow-up:
- Track this as a Lua runtime/live-apply gap or backend modeset timing issue.
- Prefer config-file monitor changes plus restart/reboot for now when testing monitor rules.
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
- When present, converts user-local config files into `lua/user_overrides.lua` after copying the Lua module directory:
  - `UserConfigs/WindowRules.conf`
  - `UserConfigs/UserKeybinds.conf`
- The user conversion currently handles common one-line and simple named `windowrule` / `layerrule` entries plus `bind*` and `unbind` keybind entries. Converted layer rules are guarded behind `hl.layer_rule` so the generated file remains safe if the tested Lua build does not expose that helper yet.
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
- Waybar started after reload using the delayed guarded startup command.
- `SUPER+F` was verified to set maximized fullscreen after removing duplicate letter bind variants.
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
- Waybar starts from the Lua startup fallback, including the delayed guarded startup command added after reboot testing
- mouse move/resize binds run the native Lua mouse dispatchers on button press
- keyboard resize binds use native relative Lua resize calls
- user-local `WindowRules.conf` and `UserKeybinds.conf` can be converted into `user_overrides.lua`
- `SUPER+F` user maximized fullscreen override works through the helper script
- Waybar workspace scroll actions use Lua-compatible dispatch syntax
- `Virtual-1` monitor resolution applied after reboot when live Lua eval/reload did not apply it
- no `tap-to-click` unknown key error
- no `enable_swallow` type error
- no `borderangle` speed validation error
## Remaining work
The Lua conversion is still partial. Recommended next steps:
1. Reboot once more and confirm Waybar starts without manual intervention.
   - The fix targets login timing, so reload validation is necessary but not sufficient.
2. Regression-test user override migration.
   - Run the migration script from a clean pre-Lua backup.
   - Verify `user_overrides.lua` is generated correctly for both `WindowRules.conf` and `UserKeybinds.conf`.
   - Add a focused check that single-letter keybind conversion does not generate both uppercase and lowercase variants.
3. Decide how to handle Waybar workspace clicks.
   - Patch/rebuild Waybar so the built-in `hyprland/workspaces` module emits Lua dispatcher strings.
   - Or replace the built-in workspace module with custom click handlers/scripts.
4. Finish converting window and layer rules.
   - Fill out `config/hypr/lua/window_rules.lua`.
   - Confirm Lua API parity for `windowrule`, `layerrule`, and named rule blocks.
5. Convert Wallust color integration.
   - Replace the current static color fallback in `decorations.lua`.
   - Prefer a Lua-generated Wallust file if the template flow supports it.
6. Convert dynamic Hyprland config writers.
   - `config/hypr/scripts/MonitorProfiles.sh`
   - `config/hypr/scripts/Animations.sh`
   - `config/hypr/scripts/update_WindowRules.sh`
   - `config/hypr/UserScripts/WallpaperSelect.sh`
   - `config/hypr/scripts/ThemeChanger.sh`
   - `config/hypr/scripts/WallustSwww.sh`
7. Improve keybind generation.
   - Move key aliases and dispatcher mapping into the generator instead of only the generated file.
   - Add strict mode so unsupported key names or dispatchers are detected before startup.
   - Confirm native Lua helpers for fullscreen, silent workspace moves, swap window, group actions, and monitor workspace moves before enabling those by default.
8. Track Lua API gaps separately from repo conversion bugs.
   - Monitor live-apply behavior after `hl.monitor(...)` eval/reload.
   - Mouse resize limitations under Lua `__lua` dispatch.
   - Helper/script fallbacks that are only needed because Lua helpers are incomplete or no-op in the tested branch.
9. Decide installer integration.
   - Keep Lua migration opt-in until parity is complete.
   - Later add a `copy.sh` prompt such as `Use experimental Hyprland Lua config? [y/N]`.
10. Add runtime smoke tests.
   - Reload Hyprland and check `hyprctl configerrors`.
   - Test core binds: app launcher, terminal, close active window, workspace switching, media keys, screenshot keys, and mouse move/resize binds.
