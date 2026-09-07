# How to Configure Environment Variables in KoolDots (`user_env.lua`)

In **KoolDots (2026)** with the Lua configuration workflow, all personal session environment variables (toolkit theming, scaling, driver flags, weather units) are managed in:

```
~/.config/hypr/UserConfigs/user_env.lua
```

This guide explains how environment variables work in Hyprland Lua, how system defaults interact with user variables, and provides practical examples for common hardware and software integrations.

---

## 1. Overview & Architecture

### System vs. User Environment Variables

- **System Environment (`~/.config/hypr/configs/system_env.lua` & `lua/environment.lua`)**:
  Configures baseline Wayland environment variables (such as `XDG_CURRENT_DESKTOP`, `XDG_SESSION_TYPE`, `MOZ_ENABLE_WAYLAND`, `ELECTRON_OZONE_PLATFORM_HINT`, etc.).
- **User Environment (`~/.config/hypr/UserConfigs/user_env.lua`)**:
  Loaded to apply your personal environment variable additions and overrides. Entries defined here survive updates to KoolDots.

### The `hl.env()` Helper Syntax

Environment variables are set in Lua using the `hl.env()` function:

```lua
hl.env("VARIABLE_NAME", "VALUE")
```

---

## 2. Step-by-Step Instructions

### Step 1: Open `user_env.lua`
Open the file in your preferred text editor:

```bash
nano ~/.config/hypr/UserConfigs/user_env.lua
# or
nvim ~/.config/hypr/UserConfigs/user_env.lua
```

### Step 2: Add Your Environment Variables
Use `hl.env("KEY", "VALUE")` to specify environment variables.

```lua
-- Example: Qt theming engine
hl.env("QT_QPA_PLATFORMTHEME", "qt6ct")
```

### Step 3: Save & Apply
Because many environment variables are read by applications at launch:
- For immediate testing: Run `hyprctl reload` or press `SUPER + ALT + R`.
- For system-wide GUI application propagation: Log out and log back into your Hyprland session.

---

## 3. Practical Examples

### Example A: Qt & GTK Theme Customization

```lua
-- Force Qt applications to use qt6ct / qt5ct theme config
hl.env("QT_QPA_PLATFORMTHEME", "qt6ct")

-- Force Qt style override (e.g. kvantum, Fusion)
hl.env("QT_STYLE_OVERRIDE", "kvantum")

-- Enable automatic screen scaling in Qt apps
hl.env("QT_AUTO_SCREEN_SCALE_FACTOR", "1")
```

### Example B: HiDPI & Toolkit Scaling Factors

```lua
-- GTK / GDK scale
hl.env("GDK_SCALE", "1")

-- Qt scale factor
hl.env("QT_SCALE_FACTOR", "1")

-- Java / JetBrains UI scale
hl.env("_JAVA_OPTIONS", "-Dsun.java2d.uiScale=1")
```

### Example C: Cursor Theme & Size

```lua
-- Hyprland cursor settings
hl.env("HYPRCURSOR_THEME", "Bibata-Modern-Classic")
hl.env("HYPRCURSOR_SIZE", "24")

-- XCursor fallback for older XWayland / GTK applications
hl.env("XCURSOR_THEME", "Bibata-Modern-Classic")
hl.env("XCURSOR_SIZE", "24")
```

### Example D: NVIDIA Proprietary Driver Tweaks

If you run an NVIDIA GPU with proprietary drivers:

```lua
-- Hardware video acceleration
hl.env("LIBVA_DRIVER_NAME", "nvidia")
hl.env("GBM_BACKEND", "nvidia-drm")
hl.env("__GLX_VENDOR_LIBRARY_NAME", "nvidia")

-- Hardware cursor rendering fix for NVIDIA if cursor disappears
-- hl.env("WLR_NO_HARDWARE_CURSORS", "1")
```

### Example E: KoolDots Widgets & Tool Units

```lua
-- Weather temperature and speed units ("metric" for °C/km/h or "imperial" for °F/mph)
hl.env("WEATHER_UNITS", "metric")
```

---

## 4. Troubleshooting & Verification

1. **Verify Loaded Variables**:
   In your terminal, check if an environment variable is exported in your session:
   ```bash
   echo $QT_QPA_PLATFORMTHEME
   echo $WEATHER_UNITS
   ```

2. **Check Lua Syntax**:
   ```bash
   luac -p ~/.config/hypr/UserConfigs/user_env.lua
   ```
