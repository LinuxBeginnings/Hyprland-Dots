# How to Configure Window Decorations in KoolDots (`user_decorations.lua`)

In **KoolDots (2026)** with the Lua configuration workflow, all aesthetic window styling (borders, gaps, corner rounding, transparency, blur effects, drop shadows, and grouped tab styling) are managed in:

```
~/.config/hypr/UserConfigs/user_decorations.lua
```

This guide explains how decoration overrides work in Hyprland Lua, the options available under `general`, `decoration`, and `group`, and provides practical examples for styling your desktop.

---

## 1. Overview & Architecture

### System vs. User Decorations

- **System Themes (`~/.config/hypr/lua/user_decorations_helper.lua`, themes, quick settings)**:
  Themes and dynamic wallpaper color tools (e.g. `wallust`) calculate border colors, shadows, and default layout parameters.
- **User Decorations (`~/.config/hypr/UserConfigs/user_decorations.lua`)**:
  Allows you to override any default decoration settings (such as setting larger margins, disabling blur for performance, or forcing specific opacity levels). Your changes here will persist across updates.

### The `hl.config()` Syntax

Decorations are configured using the standard `hl.config({...})` table helper:

```lua
hl.config({
  general = {
    border_size = 2,
    gaps_in = 6,
    gaps_out = 10,
  },
  decoration = {
    rounding = 12,
    active_opacity = 1.0,
    inactive_opacity = 0.90,
    blur = {
      enabled = true,
      size = 6,
      passes = 3,
    },
    shadow = {
      enabled = true,
      range = 4,
    },
  },
})
```

---

## 2. Supported Configuration Options

### `general` Options

| Option | Type | Description |
|---|---|---|
| `border_size` | number | Window border thickness in pixels |
| `gaps_in` | number | Inner gap between adjacent windows in pixels |
| `gaps_out` | number | Outer gap between windows and monitor screen edges |

### `decoration` Options

| Option | Type | Description |
|---|---|---|
| `rounding` | number | Corner rounding radius in pixels |
| `active_opacity` | number | Opacity of the currently focused window (`0.0` - `1.0`) |
| `inactive_opacity` | number | Opacity of unfocused windows (`0.0` - `1.0`) |
| `fullscreen_opacity` | number | Opacity of fullscreen windows |
| `dim_inactive` | boolean | Dim unfocused windows |
| `dim_strength` | number | Dimming amount (`0.0` to `1.0`) |
| `dim_special` | number | Background dimming when opening the special workspace |

### `decoration.shadow` Options

| Option | Type | Description |
|---|---|---|
| `enabled` | boolean | Enable window drop shadows |
| `range` | number | Shadow size/spread in pixels |
| `render_power` | number | Falloff rendering power (`1` - `4`) |
| `color` | string | RGBA color string (e.g. `"rgba(00000088)"`) |
| `color_inactive` | string | Shadow color for unfocused windows |

### `decoration.blur` Options

| Option | Type | Description |
|---|---|---|
| `enabled` | boolean | Enable background blur for translucent surfaces |
| `size` | number | Blur kernel radius |
| `passes` | number | Number of blur passes (higher = smoother, more GPU intensive) |
| `new_optimizations` | boolean | Enable Hyprland blur optimizations |
| `xray` | boolean | Floating windows blur desktop directly through tiled windows |
| `ignore_opacity` | boolean | Blurs regardless of window base opacity |
| `popups` | boolean | Apply blur to context menus and popups |

---

## 3. Step-by-Step Instructions

### Step 1: Open `user_decorations.lua`
Open the file in your editor:

```bash
nano ~/.config/hypr/UserConfigs/user_decorations.lua
# or
nvim ~/.config/hypr/UserConfigs/user_decorations.lua
```

### Step 2: Add or Uncomment Configuration Blocks
Add your `hl.config({...})` blocks with the desired properties.

### Step 3: Save & Reload
Apply your styling changes immediately:

```bash
hyprctl reload
```
*(or press `SUPER + ALT + R`).*

---

## 4. Practical Examples

### Example A: Clean Minimalist Style (No Gaps, Thin Borders, Flat)

```lua
hl.config({
  general = {
    border_size = 1,
    gaps_in = 0,
    gaps_out = 0,
  },
  decoration = {
    rounding = 0,
    active_opacity = 1.0,
    inactive_opacity = 1.0,
    dim_inactive = false,
    shadow = {
      enabled = false,
    },
    blur = {
      enabled = false,
    },
  },
})
```

### Example B: Glass / Frosted Blur Aesthetic

```lua
hl.config({
  general = {
    border_size = 2,
    gaps_in = 6,
    gaps_out = 12,
  },
  decoration = {
    rounding = 14,
    active_opacity = 0.94,
    inactive_opacity = 0.82,
    dim_inactive = true,
    dim_strength = 0.1,
    blur = {
      enabled = true,
      size = 8,
      passes = 4,
      new_optimizations = true,
      ignore_opacity = true,
      popups = true,
    },
    shadow = {
      enabled = true,
      range = 10,
      render_power = 3,
      color = "rgba(00000066)",
    },
  },
})
```

### Example C: Low-Power / Battery Saver Profile

Disables blur and heavy shadow rendering for older laptops and integrated GPUs:

```lua
hl.config({
  decoration = {
    rounding = 8,
    active_opacity = 1.0,
    inactive_opacity = 0.98,
    dim_inactive = false,
    shadow = {
      enabled = false,
    },
    blur = {
      enabled = false,
    },
  },
})
```

---

## 5. Troubleshooting

1. **Blur is not visible**:
   Make sure `decoration.blur.enabled = true` and that your window has opacity less than `1.0` or `ignore_opacity = true`.
2. **Lag or dropped frames on low-end GPUs**:
   Reduce `decoration.blur.passes` to `1` or `2`, or set `decoration.blur.enabled = false`.
3. **Validate syntax**:
   ```bash
   luac -p ~/.config/hypr/UserConfigs/user_decorations.lua
   ```
