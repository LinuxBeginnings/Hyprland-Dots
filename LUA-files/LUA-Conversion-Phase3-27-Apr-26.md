# LUA Conversion Phase 3 - 27 Apr 2026
## Summary
Phase 3 focused on stabilizing the Lua conversion after merging current `development` changes into `LUA-conversion`, then fixing runtime behavior under the Hyprland Lua config path.
## Completed fixes
### Startup reliability
- Fixed Lua startup commands so they no longer run before Wayland/Hyprland sockets are ready.
- Moved compositor readiness waiting into a background shell wrapper so Hyprland config loading does not block.
- Confirmed Waybar starts at login again.
- Confirmed wallpaper daemon starts at login again.
- Preserved startup logs under `/tmp/hypr-lua-startup-*.log`.
### Wallpaper daemon compatibility
- Preserved current `awww`/`swww` compatibility from `development`.
- Confirmed wallpaper startup works with the Lua startup wrapper.
### Workspace keybinds
- Fixed `SUPER + number` workspace switching by using the Lua-native focus workspace dispatcher instead of raw legacy workspace dispatch.
- Confirmed workspace switching works after reload.
### Arrow keybinds
- Fixed Lua runtime errors from arrow-based focus/move/swap bindings.
- Updated `movefocus`, `movewindow`, and `swapwindow` Lua dispatch paths to use guarded dispatcher construction and execution.
- This prevents no-target edge cases, including `invalid workspace` errors when only one workspace is occupied.
### Dropterminal
- Removed automatic Dropterminal startup from both legacy and Lua startup configs.
- Preserved Dropterminal keybind/manual behavior.
- Confirmed no `kitty-dropterm` client or process remains after reload unless launched manually.
### Window rules
- Ported `config/hypr/configs/WindowRules.conf` into `config/hypr/lua/window_rules.lua`.
- Converted 126 legacy rules:
  - 119 window rules
  - 7 layer rules
- Preserved the Lua-only Dropterminal positioning rule.
- Validated the generated Lua file with `luac -p`.
- Reloaded Hyprland successfully with no config errors.
### Branch sync
- Merged current `development` updates into `LUA-conversion`.
- Resolved conflicts while preserving Lua branch behavior.
- Kept updated wallpaper, script, Waybar, and rule changes from `development`.
### Boot default
- Set `linux-cachyos 7.0` as the default systemd-boot entry.
## Validation performed
- `hyprctl reload` returned `ok` after each major change.
- `hyprctl configerrors` is clean.
- Rolling log checks showed no fresh Lua/runtime errors after the latest patches.
- Waybar and wallpaper startup were confirmed working.
- Dropterminal no longer autostarts.
## Known remaining issue
### Waybar workspace click support
Waybar workspace scrolling has been made Lua-compatible, but clicking a workspace in the built-in `hyprland/workspaces` module still uses Waybar's internal legacy Hyprland dispatch behavior.
Under the Lua config path, those legacy workspace click dispatches may not switch workspaces reliably.
## Next steps
### 1. Fix Waybar workspace clicks
Replace or supplement the built-in Waybar workspace click behavior with a custom module/script approach.
Suggested location:
- `config/waybar/ModulesCustom/`
Possible approach:
- Add a custom workspace module or scripts that call Lua-compatible workspace dispatches.
- Example command shape:
  - `hyprctl dispatch 'hl.dsp.focus({ workspace = 2 })'`
- Generate clickable workspace entries from `hyprctl workspaces -j`.
- Use custom click handlers so selecting a workspace switches with the Lua-native dispatcher instead of Waybar's built-in legacy dispatcher.
### 2. Harden Lua window-rule generation
- Add or improve a repo helper to regenerate `config/hypr/lua/window_rules.lua` from `config/hypr/configs/WindowRules.conf`.
- Keep the Dropterminal Lua-only rule appended after generation.
- Validate with `luac -p` and `hyprctl reload`.
### 3. Audit remaining legacy dispatches
Search Lua modules for raw or legacy dispatches that may still be unreliable under the Lua config path.
Priority areas:
- Waybar scripts
- workspace movement
- layout switching
- monitor/workspace scripts
### 4. Reboot validation
After the current fixes are committed:
- Reboot from SDDM.
- Confirm Waybar starts automatically.
- Confirm wallpaper starts automatically.
- Confirm Dropterminal does not autostart.
- Confirm `SUPER + number`, `SUPER CTRL + arrows`, and `SUPER ALT + arrows` behave without Lua runtime errors.
### 5. Commit current Lua branch fixes
Before committing:
- Review `git diff`.
- Run syntax checks for changed shell/Lua files.
- Confirm `hyprctl configerrors` remains clean.
- Commit with an appropriate message for Phase 3 Lua stabilization.
