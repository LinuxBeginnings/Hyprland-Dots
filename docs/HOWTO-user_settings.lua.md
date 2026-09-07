# How to Configure User Settings in KoolDots (`user_settings.lua`)

In **KoolDots (2026)** with the Lua configuration workflow, all personal input device settings, keyboard layouts, touchpad behaviors, sensitivity, and core compositor options are managed in:

```
~/.config/hypr/UserConfigs/user_settings.lua
```

This guide explains how `user_settings.lua` interacts with system configurations, lists all customizable input and compositor properties, and provides step-by-step examples.

---

## 1. Overview & Architecture

### System vs. User Settings

- **System Settings (`~/.config/hypr/configs/system_settings.lua` & `lua/settings.lua`)**:
  Defines core environment behavior, dnd (drag and drop) rules, layout settings (dwindle / master), and system default input rules.
- **User Settings (`~/.config/hypr/UserConfigs/user_settings.lua`)**:
  Loaded to apply your personal input customizations (such as your keyboard languages, touchpad scrolling options, mouse acceleration, and cursor behavior). Your configurations in this file are preserved across KoolDots updates.

### The `hl.config()` Structure

User settings use the standard nested `hl.config({...})` table:

```lua
hl.config({
  input = {
    kb_layout = "us",
    repeat_rate = 50,
    repeat_delay = 300,
    touchpad = {
      natural_scroll = true,
      tap_to_click = true,
    },
  },
  cursor = {
    no_warps = true,
  },
})
```

---

## 2. Supported Configuration Options

### `input` Options

| Option | Type | Description |
|---|---|---|
| `kb_layout` | string | Keyboard layout codes (e.g. `"us"`, `"es"`, `"us,de"`) |
| `kb_variant` | string | Keyboard variant (e.g. `"colemak"`, `"dvorak"`) |
| `kb_options` | string | XKB options (e.g. `"grp:alt_shift_toggle"`, `"caps:escape"`, `"caps:swapescape"`) |
| `repeat_rate` | number | Key repeat rate in Hertz (e.g. `50`) |
| `repeat_delay` | number | Delay before repeating in milliseconds (e.g. `300`) |
| `sensitivity` | number | Pointer sensitivity modifier from `-1.0` to `1.0` |
| `follow_mouse` | number | Focus follows mouse (`0`: click to focus, `1`: cursor focus, `2`: detached) |
| `numlock_by_default` | boolean | Turn on NumLock automatically on startup |
| `left_handed` | boolean | Swap left and right mouse buttons |
| `float_switch_override_focus` | boolean | Controls focus behavior when switching floating windows |

### `input.touchpad` Options

| Option | Type | Description |
|---|---|---|
| `natural_scroll` | boolean | Invert scrolling direction (natural two-finger scroll) |
| `tap_to_click` | boolean | Tap touchpad surface to trigger left click |
| `disable_while_typing` | boolean | Temporarily ignore touchpad input while typing |
| `clickfinger_behavior` | boolean | 1 finger = left click, 2 fingers = right click, 3 fingers = middle click |
| `middle_button_emulation` | boolean | Pressing left+right simultaneously triggers middle click |
| `drag_lock` | boolean | Locks dragging on tap-drag |

### `cursor` Options

| Option | Type | Description |
|---|---|---|
| `no_warps` | boolean | Prevent the cursor from jumping/warping when focus changes |
| `warp_on_change_workspace` | number | `0`: Disable cursor warping to window when switching workspaces |
| `inactive_timeout` | number | Seconds of inactivity before cursor auto-hides (`0` = never) |

---

## 3. Step-by-Step Instructions

### Step 1: Open `user_settings.lua`
Open the file in your preferred text editor:

```bash
nano ~/.config/hypr/UserConfigs/user_settings.lua
# or
nvim ~/.config/hypr/UserConfigs/user_settings.lua
```

### Step 2: Edit or Add Desired Options
Modify the properties inside the `hl.config({...})` table.

### Step 3: Save & Reload
Reload Hyprland immediately:

```bash
hyprctl reload
```
*(or press `SUPER + ALT + R`).*

---

## 4. Practical Examples

### Example A: Dual-Language Keyboard with Alt+Shift Switching

```lua
hl.config({
  input = {
    kb_layout = "us,es",
    kb_variant = "",
    kb_options = "grp:alt_shift_toggle,caps:swapescape",
    repeat_rate = 50,
    repeat_delay = 300,
    numlock_by_default = true,
  },
})
```

### Example B: Laptop Touchpad Optimization

```lua
hl.config({
  input = {
    touchpad = {
      natural_scroll = true,
      tap_to_click = true,
      disable_while_typing = true,
      clickfinger_behavior = true,
      middle_button_emulation = false,
      drag_lock = false,
    },
  },
})
```

### Example C: Fast Key Repeat & Gaming Mouse Settings

```lua
hl.config({
  input = {
    sensitivity = -0.2,       -- Lower sensitivity for higher DPI sensor
    repeat_rate = 60,         -- Fast repeat rate
    repeat_delay = 240,        -- Short key repeat delay
    follow_mouse = 1,
  },
  cursor = {
    no_warps = true,
    warp_on_change_workspace = 0,
  },
})
```

---

## 5. Troubleshooting

1. **Keyboard shortcut for layout switching does not work**:
   Make sure you specify multiple layouts in `kb_layout` (e.g. `kb_layout = "us,es"`) and set `kb_options = "grp:alt_shift_toggle"`.
2. **Cursor jumps unexpectedly when switching windows**:
   Ensure `cursor = { no_warps = true, warp_on_change_workspace = 0 }` is configured.
3. **Check syntax errors**:
   ```bash
   luac -p ~/.config/hypr/UserConfigs/user_settings.lua
   ```
