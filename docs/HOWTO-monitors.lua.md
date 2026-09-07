# How to Configure Monitors in KoolDots (`monitors.lua`)

In **KoolDots (2026)** with the Lua configuration workflow, all personal and multi-monitor setups are managed in:

```
~/.config/hypr/UserConfigs/monitors.lua
```

This guide explains how monitor configuration works in Hyprland Lua, how monitor profiles interact with user overrides, and provides practical examples for single, multi-monitor, high-refresh, and scaled displays.

---

## 1. Overview & Architecture

### System vs. User Monitor Configurations

- **System Monitors (`~/.config/hypr/lua/monitors.lua`)**:
  Provides fallback defaults (such as `output = "", mode = "preferred", position = "auto", scale = "1"`).
- **User Monitors (`~/.config/hypr/UserConfigs/monitors.lua`)**:
  Contains your persistent custom monitor definitions. When the `MonitorProfiles.sh` script or profile selector runs, selected profiles write here. Any custom `hl.monitor({...})` blocks you add here will be preserved.

### The `hl.monitor()` Helper Syntax

Monitor definitions are created using the `hl.monitor({...})` function:

```lua
hl.monitor({
    output = "eDP-1",        -- Display connector name (e.g. eDP-1, DP-1, HDMI-A-1)
    mode = "1920x1080@144",  -- Resolution and refresh rate (or "preferred", "highrr", "highres")
    position = "0x0",        -- Placement offset "XxY" or "auto"
    scale = "1",             -- Scale factor (e.g. "1", "1.25", "1.5", "2")
    transform = "0",         -- Optional: Rotation (0: normal, 1: 90 deg, 2: 180 deg, 3: 270 deg)
    bitdepth = "10",         -- Optional: Color bit depth (e.g. "8", "10")
})
```

---

## 2. Finding Connected Displays

To find the exact connector names, supported modes, and current resolutions of your connected monitors:

```bash
hyprctl monitors all
```

Look for the monitor name at the top of each block (e.g. `Monitor DP-1 (ID 0):`, `Monitor eDP-1 (ID 1):`).

---

## 3. Step-by-Step Instructions

### Step 1: Open `monitors.lua`
Open the file in your preferred text editor:

```bash
nano ~/.config/hypr/UserConfigs/monitors.lua
# or
nvim ~/.config/hypr/UserConfigs/monitors.lua
```

### Step 2: Add Your Monitor Definitions
Add one `hl.monitor({...})` block per monitor.

```lua
-- Primary Laptop Display
hl.monitor({
    output = "eDP-1",
    mode = "preferred",
    position = "0x0",
    scale = "1",
})
```

### Step 3: Save & Apply Changes
Reload Hyprland immediately:

```bash
hyprctl reload
```
*(or press `SUPER + ALT + R`).*

---

## 4. Practical Examples

### Example A: Single High-Refresh Rate Laptop Screen

```lua
hl.monitor({
    output = "eDP-1",
    mode = "1920x1080@144",
    position = "0x0",
    scale = "1",
})
```

### Example B: Dual Monitor Setup (Laptop + External Monitor on the Right)

In this setup:
- Laptop `eDP-1` is `1920x1080` at position `0x0`.
- External `DP-1` is `2560x1440` placed to the right at position `1920x0`.

```lua
-- Laptop (Left)
hl.monitor({
    output = "eDP-1",
    mode = "1920x1080@60",
    position = "0x0",
    scale = "1",
})

-- External Monitor (Right)
hl.monitor({
    output = "DP-1",
    mode = "2560x1440@144",
    position = "1920x0",
    scale = "1",
})
```

### Example C: Dual Monitor Setup (External Above Laptop)

- Laptop `eDP-1` (`1920x1080`) at position `0x1080`.
- External `HDMI-A-1` (`1920x1080`) placed directly above it at `0x0`.

```lua
-- External Monitor (Top)
hl.monitor({
    output = "HDMI-A-1",
    mode = "1920x1080@60",
    position = "0x0",
    scale = "1",
})

-- Laptop Screen (Bottom)
hl.monitor({
    output = "eDP-1",
    mode = "1920x1080@60",
    position = "0x1080",
    scale = "1",
})
```

### Example D: 4K HiDPI Monitor with Fractional Scaling

```lua
hl.monitor({
    output = "DP-2",
    mode = "3840x2160@60",
    position = "0x0",
    scale = "1.5",
})
```

### Example E: Vertical / Portrait Secondary Monitor

To rotate a monitor 90 degrees clockwise (portrait orientation):

```lua
hl.monitor({
    output = "DP-1",
    mode = "1920x1080@60",
    position = "1920x0",
    scale = "1",
    transform = "1", -- 1 = 90 degrees clockwise
})
```

### Example F: Disabling an Unused Display Connector

```lua
hl.monitor({
    output = "HDMI-A-1",
    mode = "disable",
})
```

---

## 5. Troubleshooting

1. **Monitor shows black screen or incorrect resolution**:
   Verify available modes using `hyprctl monitors all` and ensure the `mode` string exactly matches a supported resolution/refresh rate (e.g. `2560x1440@144`).
2. **Screens overlap or mouse cursor gets trapped**:
   Check your `position` coordinates. If the left monitor has a width of 1920, the right monitor's X offset must be at least `1920`.
3. **Check Lua Syntax**:
   ```bash
   luac -p ~/.config/hypr/UserConfigs/monitors.lua
   ```
