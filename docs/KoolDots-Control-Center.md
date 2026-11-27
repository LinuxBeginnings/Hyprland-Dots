# KoolDots Control Center

The **KoolDots Control Center** is a native Quickshell GUI settings application designed to provide a unified graphical control center and enhance the traditional Rofi Quick Settings menu (`Kool_Quick_Settings.sh`).

It provides a unified, structured interface for managing all modular configuration files in `~/.config/hypr/UserConfigs/` with pre-flight syntax validation, duplicate keybinding checks, automated backups, instant revert capabilities, and AI-assisted error diagnostics.

---

## Architecture & Layout

### 1. Main Navigation Hierarchy
- **Horizontal Top Bar**:
  - `[ 🏠 Home ]` — System specifications, configuration health, and fast management shortcuts.
  - `[ ⌨ Keybinds ]` — Shortcuts explorer, remapper, duplicate collision validator, and custom bind creator.
  - `[ ⚙ Settings ]` — Modular system settings covering input, touchpad, window decorations, blur, wobble, and defaults.
  - `[ 🪟 Window Rules ]` — Rule inspector, enable/disable toggles, interactive rule builder, and validator.
  - `[ 🚀 Startup ]` — Autostart commands and system daemons manager.
  - `[ 🎚 Toggles ]` — Quick switchboard for weather units, clock format, game mode, and window wobble.
  - `[ 🖥 Monitors ]` — Display layout profiles, multi-monitor visualizer, and resolution overview.
  - `[ 📊 Waybar Editor ]` — Phase 2 visual 3-column Waybar module arranger with bar preview, clone incrementing, and syntax checks.

- **Vertical Subcategory Sidebar**:
  - Contextual sidebar for major tabs (e.g. Settings: Keyboard, Touchpad, Decorations, Wobble, Defaults).

- **Contextual Help Engine (`HelpService.qml`)**:
  - Every tab and sub-section features an expandable help drawer explaining which files in `UserConfigs/` are affected, syntax rules, and troubleshooting tips.

---

## File Mappings Covered

The Control Center directly manages all configuration files in `~/.config/hypr/UserConfigs/`:
- `user_keybinds.lua`: Personal keyboard shortcuts and compositor bindings.
- `user_window_rules.lua` & `user_layer_rules.lua`: Window and layer-surface rules.
- `user_startup.lua`: Once-per-session startup commands (`exec_once`).
- `user_settings.lua`: Input configuration, multi-language layout toggles, mouse and touchpad options.
- `user_decorations.lua`: Borders, gaps, opacities, blur passes, blur variants, and window wobble physics.
- `user_animations.lua`: Bezier curves and animation duration profiles.
- `user_laptops.lua`: Clamshell mode and lid-switch behavior.
- `user_defaults.lua`: Default applications (`$term`, `$edit`, `$visual`, `$files`).
- `user_env.lua`: Toolkit scaling (`GDK_SCALE`, `QT_SCALE_FACTOR`) and Waybar font overrides.
- `monitors.lua` & `display-layouts.json`: Multi-monitor display profiles.
- `ghostty.conf` & `kitty.conf`: Terminal emulator fonts and themes.

---

## Safety & Resilience Engine (`KoolSettingsEngine.sh`)

1. **Pre-flight Syntax Validation**:
   - Every file modification is tested using `luac -p` before writing to disk.
   - For keybindings, the engine checks for duplicate active chords across both user and system tables.

2. **Automated Timestamped Backups**:
   - Before saving any changes, the engine creates a timestamped backup in `~/.local/state/hypr/backups/` and updates `<file>.bak`.

3. **One-Click Revert**:
   - Every tab includes a `Revert File` button to instantly undo broken changes and restore the previous working state.

4. **Error Logging & AI Diagnostic Export**:
   - Failed validations log structured diagnostics to `~/.local/state/hypr/kooldots-settings-errors.log`.
   - The in-GUI error modal includes a **"Copy Error for AI"** button (powered by `wl-copy`) to easily share failure context with AI assistants or issue trackers.

---

## Keybindings & Launchers

- `SUPER + SHIFT + E` — Opens KoolDots Control Center (`KoolControlCenter.sh`)
- `SUPER + ALT + E` — Opens Classic Quick Settings menu (`Kool_Quick_Settings.sh`)
- `SUPER + CTRL + E` — Opens Rofi Emoji selector (`RofiEmoji.sh`)
- **CLI / Manual Testing**:
  - Script: `~/.config/hypr/scripts/KoolControlCenter.sh`
  - Quickshell direct: `qs -p ~/.config/quickshell/control-center` (or `qs -p control-center` from `~/.config/quickshell`)

---

## Phase 2: Waybar Visual Editor

The **Waybar Visual Editor** (`WaybarView.qml`) allows full visual customization and rearrangement of Waybar status bars:

1. **Active Configuration Banner & Discovery**:
   - Displays `Current cfg: <filename>` showing the resolved target of `~/.config/hypr/waybar/config`.
   - Lists all layout configurations from `~/.config/hypr/waybar/configs/` with custom clones sorted to the top.

2. **Automated Cloned Presets (`[Custom-#]`)**:
   - Default system configurations are protected against accidental overwrites.
   - Editing or clicking **Clone Config** automatically clones the layout to `[Custom-#]-<source_name>`.
   - Cloning an existing clone increments the counter (e.g. `[Custom-1]` -> `[Custom-2]`).
   - The `[Custom-#]` prefix ensures user configurations naturally sort together at the top of configuration menus.
   - File names remain editable with an inline dialog.

3. **3-Column Module Arranger & Bar Preview**:
   - Horizontal live visual preview banner displaying Left, Center, and Right module pills in real time.
   - Three distinct management columns matching the bar structure: **Start** (`modules-left`), **Center** (`modules-center`), and **End** (`modules-right`).
   - Each module row includes:
     - Drag/order indicator (`≡`) and contextual icon.
     - Reorder buttons (`▲`/`▼`) to shift ordering within the column.
     - Move buttons (`←`/`→`) and right-click context menu to migrate modules across columns.
     - Edit button (``) to open the module's definition file directly in your default editor (`$EDITOR`).
     - Delete button (`✕`) to remove modules.
   - `+ Add Module` dialog supporting search across all 48+ core and custom Waybar modules.
   - Reset button per column to undo unsaved rearrangements.

4. **Pre-flight Syntax Validation & Instant Apply**:
   - Modifications are validated for clean JSONC syntax before saving.
   - Applying switches the `~/.config/hypr/waybar/config` symlink and seamlessly restarts Waybar.

---

## Next Steps Roadmap
   - Verify Quickshell UI behavior across different screen sizes and display scalings.
   - Validate live `hyprctl reload` response times when writing multiple `UserConfigs` tables simultaneously.
   - Test keybind remapping against non-US keyboard layouts.
