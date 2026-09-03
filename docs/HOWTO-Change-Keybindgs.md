# How to Change and Customize Keybindings in KoolDots (`user_keybinds.lua`)

In **KoolDots (2026)** with the Lua configuration architecture, all personal keybinding additions, overrides, and rebindings are configured in:

```
~/.config/hypr/UserConfigs/user_keybinds.lua
```

This guide explains how keybindings work in the Lua architecture, how system default keybindings are structured in `~/.config/hypr/configs/system_keybinds.lua`, and provides step-by-step instructions with numerous real-world examples.

---

## 1. Overview & Architecture

### System Defaults vs. User Keybindings

- **System Defaults (`~/.config/hypr/configs/system_keybinds.lua`)**  
  Defines the out-of-the-box keybinds for window management, core KoolDots scripts (Waybar menus, Rofi selectors, wallpaper effects, audio control, layouts), and standard workspace navigation. This file is managed by the dotfiles installer and should **not** be edited directly, as future updates may overwrite changes.

- **User Overrides (`~/.config/hypr/UserConfigs/user_keybinds.lua`)**  
  Reserved exclusively for your personal keybinds and overrides. Keybinds declared here take precedence and are **preserved across dotfiles updates**.

---

## 2. Keybinding Syntax & Rules

All keybindings in `user_keybinds.lua` use the following functions:

```lua
bind("MODIFIERS", "KEY", action, [options])
unbind("MODIFIERS", "KEY")
```

### Supported Modifiers
Modifiers are specified as uppercase strings, separated by spaces:
- Single modifiers: `"SUPER"`, `"SHIFT"`, `"CTRL"`, `"ALT"`
- Combined modifiers: `"SUPER SHIFT"`, `"SUPER ALT"`, `"SUPER CTRL"`, `"CTRL ALT"`, `"SUPER CTRL SHIFT"`
- No modifier (e.g. for hardware/media keys): `""`

### Action Types
1. **`exec_cmd("command")`**  
   Executes a shell command, terminal application, or custom script. Supports predefined placeholders such as `'$term'` (default terminal) and `'$files'` (default file manager).
2. **`dispatch("dispatcher", [arg])`**  
   Triggers a built-in Hyprland compositor action (e.g., `killactive`, `togglefloating`, `fullscreen`, `workspace`, `movetoworkspace`).

### Keybinding Options Table (`[options]`)
You can pass an optional Lua table to customize keybind behavior:
- `description = "Text"`: Provides a human-readable title shown in the Key Hints cheat sheet (`SUPER + H`) and Search Keybinds menu (`SUPER + SHIFT + K`).
- `locked = true`: Allows the keybind to trigger even when the screen is locked by Hyprlock (e.g. media controls, volume keys, sleep).
- `repeating = true` (or `["repeat"] = true`): Continuously triggers the action when the key is held down (e.g. volume adjustment, brightness, window resizing).

---

## 3. The Golden Rule: Always `unbind` Before Rebinding

If a key combination is already assigned in `system_keybinds.lua`, **always call `unbind("MODIFIERS", "KEY")` first** before binding it to a new action.

```lua
-- Incorrect: May trigger both actions or produce unexpected conflicts
bind("SUPER", "Return", exec_cmd("ghostty"))

-- Correct: Unbind default action (kitty) first, then bind Ghostty
unbind("SUPER", "Return")
bind("SUPER", "Return", exec_cmd("ghostty"), { description = "Launch Ghostty Terminal" })
```

---

## 4. Step-by-Step Instructions: Modifying Keybindings

### Step 1: Check Default System Keybindings
Before changing a keybind, check what it does by default:
- Press `SUPER + H` to open the visual Key Hints cheat sheet.
- Press `SUPER + SHIFT + K` to search through all registered keybinds.
- Or inspect `~/.config/hypr/configs/system_keybinds.lua`.

### Step 2: Open `user_keybinds.lua`
Open the user configuration file in your editor:

```bash
nano ~/.config/hypr/UserConfigs/user_keybinds.lua
# or
nvim ~/.config/hypr/UserConfigs/user_keybinds.lua
```

### Step 3: Add Your Binds or Overrides
Scroll to the bottom of the file (after the helper loading block) and append your custom bindings.

### Step 4: Validate Lua Syntax
Ensure there are no missing quotes, commas, or parentheses:

```bash
luac -p ~/.config/hypr/UserConfigs/user_keybinds.lua
```

### Step 5: Reload Hyprland
Apply the changes immediately without logging out:
- Press `SUPER + ALT + R` (Refresh hotkey), or
- Run `hyprctl reload` in your terminal.

---

## 5. Comparison: `system_keybinds.lua` vs. `user_keybinds.lua`

Here are common examples comparing the system default in `system_keybinds.lua` with how to customize or override it in `user_keybinds.lua`:

| Action / Feature | System Default (`system_keybinds.lua`) | How to Override in `user_keybinds.lua` |
|---|---|---|
| **Terminal Launcher** | `SUPER + Return` launches `$term` (Kitty) | `unbind("SUPER", "Return")`<br>`bind("SUPER", "Return", exec_cmd("ghostty"))` |
| **App Launcher** | `SUPER + D` launches Rofi Drun | `unbind("SUPER", "D")`<br>`bind("SUPER", "SPACE", exec_cmd("rofi -show drun"))` |
| **File Manager** | `SUPER + E` launches `$files` (Thunar) | `unbind("SUPER", "E")`<br>`bind("SUPER", "E", exec_cmd("nautilus"))` |
| **Close Active Window** | `SUPER + Q` dispatches `killactive` | `unbind("SUPER", "Q")`<br>`bind("SUPER", "C", dispatch("killactive"))` |
| **Toggle Fullscreen** | `SUPER + SHIFT + F` (fullscreen), `SUPER + F` (maximize) | `unbind("SUPER", "F")`<br>`bind("SUPER", "F", dispatch("fullscreen", ""))` |
| **Toggle Floating** | `SUPER + SPACE` dispatches `togglefloating` | `unbind("SUPER", "SPACE")`<br>`bind("SUPER + ALT", "F", dispatch("togglefloating"))` |
| **Browser Launcher** | `SUPER + B` opens default browser | `unbind("SUPER", "B")`<br>`bind("SUPER", "B", exec_cmd("zen-browser"))` |

---

## 6. Practical Examples by Category

### Category A: Adding Brand New Application Shortcuts
Add shortcuts for applications that are not bound by default:

```lua
-- Launch Web Browsers
bind("SUPER", "B", exec_cmd("zen-browser"), { description = "Launch Zen Browser" })
bind("SUPER SHIFT", "C", exec_cmd("google-chrome-stable"), { description = "Launch Chrome" })

-- Launch Code Editors & IDEs
bind("SUPER", "C", exec_cmd("code"), { description = "Launch VS Code" })
bind("SUPER", "E", exec_cmd("emacsclient -c -a 'emacs'"), { description = "Launch Emacs" })
bind("SUPER SHIFT", "V", exec_cmd("kitty -e nvim"), { description = "Launch Neovim in Terminal" })

-- Launch System Tools & GUIs
bind("SUPER SHIFT", "P", exec_cmd("pavucontrol"), { description = "PulseAudio / PipeWire Volume Control" })
bind("SUPER SHIFT", "B", exec_cmd("blueman-manager"), { description = "Bluetooth Manager" })
bind("SUPER CTRL", "T", exec_cmd("missioncenter"), { description = "Mission Center Task Manager" })
```

---

### Category B: Overriding Default Launchers & Apps
Replace standard KoolDots applications with your preferred alternatives:

```lua
-- 1. Replace default Terminal (Kitty) with Ghostty or WezTerm
unbind("SUPER", "Return")
bind("SUPER", "Return", exec_cmd("ghostty"), { description = "Terminal (Ghostty)" })

-- 2. Replace Rofi with Fuzzel or Wofi
unbind("SUPER", "D")
bind("SUPER", "D", exec_cmd("fuzzel"), { description = "App Launcher (Fuzzel)" })

-- 3. Replace Thunar with Dolphin or Yazi
unbind("SUPER", "E")
bind("SUPER", "E", exec_cmd("dolphin"), { description = "File Manager (Dolphin)" })

-- 4. Launch Yazi Terminal File Manager
bind("SUPER SHIFT", "E", exec_cmd("ghostty -e yazi"), { description = "Yazi File Manager" })
```

---

### Category C: Window Management & Compositor Dispatchers
Reconfigure window tiling, floating, and closing behaviors:

```lua
-- Close active window with SUPER+W instead of SUPER+Q
unbind("SUPER", "Q")
bind("SUPER", "W", dispatch("killactive"), { description = "Close active window" })

-- Toggle true fullscreen with SUPER+F (default is maximize)
unbind("SUPER", "F")
unbind("SUPER SHIFT", "F")
bind("SUPER", "F", dispatch("fullscreen", "0"), { description = "Toggle Fullscreen" })
bind("SUPER SHIFT", "F", dispatch("fullscreen", "1"), { description = "Toggle Maximized" })

-- Toggle floating window with SUPER+V
unbind("SUPER", "SPACE")
bind("SUPER", "V", dispatch("togglefloating"), { description = "Toggle Floating Window" })

-- Pin a floating window to remain visible across all workspaces
bind("SUPER SHIFT", "P", dispatch("pin"), { description = "Pin Window Across Workspaces" })

-- Toggle pseudo-tiling (preserve original window dimensions in tile)
unbind("SUPER", "P")
bind("SUPER", "P", dispatch("pseudo"), { description = "Toggle Pseudo Tiling" })
```

---

### Category D: Workspaces, Scratchpads & Multi-Monitor

```lua
-- Switch to workspace 1-5 with SUPER + [1-5]
bind("SUPER", "1", dispatch("workspace", "1"), { description = "Switch to Workspace 1" })
bind("SUPER", "2", dispatch("workspace", "2"), { description = "Switch to Workspace 2" })
bind("SUPER", "3", dispatch("workspace", "3"), { description = "Switch to Workspace 3" })

-- Move active window to workspace silently (without switching focus)
bind("SUPER ALT", "1", dispatch("movetoworkspacesilent", "1"), { description = "Move Window to WS 1 Silently" })
bind("SUPER ALT", "2", dispatch("movetoworkspacesilent", "2"), { description = "Move Window to WS 2 Silently" })

-- Toggle Special Workspace / Scratchpad
bind("SUPER", "U", dispatch("togglespecialworkspace", "scratchpad"), { description = "Toggle Scratchpad" })
bind("SUPER SHIFT", "U", dispatch("movetoworkspace", "special:scratchpad"), { description = "Move Window to Scratchpad" })

-- Move workspace across monitors
bind("SUPER CTRL", "Left", dispatch("movecurrentworkspacetomonitor", "l"), { description = "Move WS to Left Monitor" })
bind("SUPER CTRL", "Right", dispatch("movecurrentworkspacetomonitor", "r"), { description = "Move WS to Right Monitor" })
```

---

### Category E: Window Resizing & Focus Movement (Vim-Style Navigation)

```lua
-- Move window focus using Vim keys (H, J, K, L)
bind("SUPER", "H", dispatch("movefocus", "l"), { description = "Focus Left" })
bind("SUPER", "L", dispatch("movefocus", "r"), { description = "Focus Right" })
bind("SUPER", "K", dispatch("movefocus", "u"), { description = "Focus Up" })
bind("SUPER", "J", dispatch("movefocus", "d"), { description = "Focus Down" })

-- Move/Swap active window position
bind("SUPER SHIFT", "H", dispatch("movewindow", "l"), { description = "Move Window Left" })
bind("SUPER SHIFT", "L", dispatch("movewindow", "r"), { description = "Move Window Right" })
bind("SUPER SHIFT", "K", dispatch("movewindow", "u"), { description = "Move Window Up" })
bind("SUPER SHIFT", "J", dispatch("movewindow", "d"), { description = "Move Window Down" })

-- Resize active window with repeating keypresses
bind("SUPER CTRL", "Right", dispatch("resizeactive", "30 0"), { description = "Resize Wider", repeating = true })
bind("SUPER CTRL", "Left", dispatch("resizeactive", "-30 0"), { description = "Resize Narrower", repeating = true })
bind("SUPER CTRL", "Up", dispatch("resizeactive", "0 -30"), { description = "Resize Taller", repeating = true })
bind("SUPER CTRL", "Down", dispatch("resizeactive", "0 30"), { description = "Resize Shorter", repeating = true })
```

---

### Category F: Media, Volume, Brightness & Hardware Keys

Hardware keys use special XF86 symbols and should usually include `locked = true` and `repeating = true`:

```lua
-- Volume Control (with repeating and locked options)
bind("", "XF86AudioRaiseVolume", exec_cmd("$HOME/.config/hypr/scripts/Volume.sh --inc"), { description = "Volume Up", locked = true, repeating = true })
bind("", "XF86AudioLowerVolume", exec_cmd("$HOME/.config/hypr/scripts/Volume.sh --dec"), { description = "Volume Down", locked = true, repeating = true })
bind("", "XF86AudioMute", exec_cmd("$HOME/.config/hypr/scripts/Volume.sh --toggle"), { description = "Mute Audio", locked = true })
bind("", "XF86AudioMicMute", exec_cmd("$HOME/.config/hypr/scripts/Volume.sh --toggle-mic"), { description = "Mute Microphone", locked = true })

-- Media Playback
bind("", "XF86AudioPlay", exec_cmd("playerctl play-pause"), { description = "Play/Pause Media", locked = true })
bind("", "XF86AudioNext", exec_cmd("playerctl next"), { description = "Next Track", locked = true })
bind("", "XF86AudioPrev", exec_cmd("playerctl previous"), { description = "Previous Track", locked = true })

-- Screen Brightness
bind("", "XF86MonBrightnessUp", exec_cmd("$HOME/.config/hypr/scripts/Brightness.sh --inc"), { description = "Brightness Up", repeating = true })
bind("", "XF86MonBrightnessDown", exec_cmd("$HOME/.config/hypr/scripts/Brightness.sh --dec"), { description = "Brightness Down", repeating = true })
```

---

### Category G: Screenshots & Screen Recording

```lua
-- Custom region screenshot to clipboard & file using Hyprshot
bind("ALT SHIFT", "S", exec_cmd("$HOME/.config/hypr/scripts/hyprshot.sh -m region -o $HOME/Pictures/Screenshots"), { description = "Screenshot Region" })

-- Fullscreen capture directly to clipboard
bind("", "Print", exec_cmd("$HOME/.config/hypr/scripts/hyprshot.sh -m output --clipboard-only"), { description = "Screenshot Full Screen to Clipboard" })

-- Active window capture
bind("SUPER", "Print", exec_cmd("$HOME/.config/hypr/scripts/hyprshot.sh -m window -o $HOME/Pictures/Screenshots"), { description = "Screenshot Active Window" })
```

---

## 7. Finding Key Names and Keycodes

If you are unsure of the exact key name for a special or non-standard key:

1. Open a terminal and run the Wayland event viewer:
   ```bash
   wev
   ```
2. Press the key while focusing the `wev` test window.
3. Look for the `sym:` field in the terminal output:
   ```
   [14: sym: XF86AudioRaiseVolume (0x1008113), utf8: '' ]
   ```
4. Use that exact symbol name as the `KEY` parameter in `bind(...)` and `unbind(...)`.

---

## 8. Troubleshooting & FAQ

### 1. The new keybind doesn't work after editing `user_keybinds.lua`
- Check for Lua syntax errors:
  ```bash
  luac -p ~/.config/hypr/UserConfigs/user_keybinds.lua
  ```
- Make sure to reload Hyprland configuration with `SUPER + ALT + R` or `hyprctl reload`.

### 2. Both old and new actions trigger simultaneously
- You forgot to `unbind` the default key combo first. Add `unbind("MODS", "KEY")` right above your `bind(...)` statement.

### 3. A keybind doesn't respond when the screen is locked
- Add `{ locked = true }` to the options table of your `bind(...)` call.

### 4. How can I see all currently active keybindings?
- Run `hyprctl binds` in your terminal, or press `SUPER + SHIFT + K` to open the Rofi Keybinds Search menu.
