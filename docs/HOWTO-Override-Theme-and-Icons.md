# How to Override GTK Theme, Icons, and Cursors (`user_env.lua`)

In **KoolDots (2026)**, the desktop environment automatically adapts themes and colors based on wallpapers or dynamic presets. If you prefer to **lock down a specific GTK theme, icon set, or cursor theme** so that it always applies across all your applications, you can define persistent environment overrides in:

```
~/.config/hypr/UserConfigs/user_env.lua
```

This guide explains how to edit your environment file, add persistent theme variables, and provides step-by-step examples.

---

## 1. Overview & Key Settings

Adding toolkit variables to `user_env.lua` ensures your preferred appearance settings are exported to your session and survive all system updates.

### Supported Appearance Variables

| Variable | Target | Example Values | Description |
|---|---|---|---|
| `GTK_THEME` | GTK 3 & GTK 4 | `"Nordic"`, `"Adwaita-dark"`, `"Catppuccin-Mocha"` | Forces a fixed GTK widget theme across all GTK applications. |
| `ICON_THEME` | Toolkits / Apps | `"Papirus-Dark"`, `"Tela-circle-dracula"`, `"Flat-Remix-Blue-Dark"` | Specifies default icon theme for supported apps and Flatpaks. |
| `GTK_ICON_THEME` | GTK Fallback | `"Papirus-Dark"`, `"Adwaita"` | Explicit icon theme definition for GTK session environments. |
| `HYPRCURSOR_THEME` | Hyprland | `"Bibata-Modern-Classic"`, `"Bibata-Modern-Ice"` | Hardware cursor theme for Hyprland Wayland compositor. |
| `HYPRCURSOR_SIZE` | Hyprland | `"24"`, `"28"`, `"32"` | Cursor size in pixels for Hyprland. |
| `XCURSOR_THEME` | GTK & XWayland | `"Bibata-Modern-Classic"`, `"Bibata-Modern-Ice"` | Fallback cursor theme for XWayland and GTK applications. |
| `XCURSOR_SIZE` | GTK & XWayland | `"24"`, `"28"`, `"32"` | Fallback cursor size in pixels for XWayland and GTK apps. |

---

## 2. Step-by-Step: Editing `user_env.lua`

### Method A: Via Kool Quick Settings (Recommended)

1. Press `SUPER + SHIFT + E` on your keyboard to open the **Kool Quick Settings** menu.
2. Select **`[[ User Settings ]]`** from the category menu.
3. Select **`Edit User ENV variables`**.
4. The file `~/.config/hypr/UserConfigs/user_env.lua` will automatically open in your default editor.

### Method B: Via Terminal

Open a terminal and edit the file directly:

```bash
nano ~/.config/hypr/UserConfigs/user_env.lua
# or
nvim ~/.config/hypr/UserConfigs/user_env.lua
```

---

## 3. Configuration Entries & Examples

Add your desired overrides using the `hl.env("KEY", "VALUE")` function:

### Example A: Dark Nordic Style (Nordic + Papirus-Dark)

```lua
-- Force specific GTK theme
hl.env("GTK_THEME", "Nordic")

-- Force specific Icon theme
hl.env("ICON_THEME", "Papirus-Dark")
hl.env("GTK_ICON_THEME", "Papirus-Dark")

-- Force cursor theme & size
hl.env("HYPRCURSOR_THEME", "Bibata-Modern-Classic")
hl.env("XCURSOR_THEME", "Bibata-Modern-Classic")
hl.env("HYPRCURSOR_SIZE", "24")
hl.env("XCURSOR_SIZE", "24")
```

### Example B: Catppuccin Mocha Style

```lua
-- Force Catppuccin GTK theme
hl.env("GTK_THEME", "Catppuccin-Mocha-Standard-Blue-Dark")

-- Force Icon theme
hl.env("ICON_THEME", "Papirus-Dark")
hl.env("GTK_ICON_THEME", "Papirus-Dark")

-- Force cursor theme & size
hl.env("HYPRCURSOR_THEME", "Bibata-Modern-Ice")
hl.env("XCURSOR_THEME", "Bibata-Modern-Ice")
hl.env("HYPRCURSOR_SIZE", "24")
hl.env("XCURSOR_SIZE", "24")
```

### Example C: Standard GNOME / Adwaita Dark

```lua
-- Force Adwaita Dark theme
hl.env("GTK_THEME", "Adwaita-dark")

-- Standard Adwaita Icons
hl.env("ICON_THEME", "Adwaita")
hl.env("GTK_ICON_THEME", "Adwaita")

-- Standard cursor
hl.env("HYPRCURSOR_THEME", "Adwaita")
hl.env("XCURSOR_THEME", "Adwaita")
hl.env("HYPRCURSOR_SIZE", "24")
hl.env("XCURSOR_SIZE", "24")
```

---

## 4. Applying and Verifying Changes

1. **Save the file**:
   Save your edits and exit the text editor.
2. **Reload Hyprland**:
   Press `SUPER + ALT + R` or run:
   ```bash
   hyprctl reload
   ```
3. **Log out and log back in**:
   Because environment variables are read by desktop applications when they launch, log out (`CTRL + ALT + Delete`) and log back into Hyprland to ensure all GUI applications adopt the new settings.
4. **Verification**:
   Open a terminal and verify that the variables are active:
   ```bash
   echo $GTK_THEME
   echo $ICON_THEME
   echo $HYPRCURSOR_THEME
   ```
