# How to Override GTK Theme, Cursors, and Icons

In **KoolDots (2026)**, the desktop environment automatically adapts themes and colors based on wallpapers or dynamic presets. If you prefer to **lock down a specific GTK theme, cursor theme, or icon set** so that it always applies across all your applications, this guide explains how to configure persistent overrides.

> **Important Note on Icons:**
> Neither GTK nor Qt supports environment variables (such as `ICON_THEME` or `GTK_ICON_THEME`) for icon themes—applications will simply ignore them. Icon themes must be configured via **`nwg-look`**, **`gsettings`**, or **GTK/Qt settings files** as detailed in [Section 4](#4-how-to-change-and-lock-icon-themes).

---

## 1. Environment Variables Overview (`user_env.lua`)

Adding toolkit variables to `~/.config/hypr/UserConfigs/user_env.lua` ensures your preferred GTK and cursor settings are exported to your session and survive all system updates.

### Supported Appearance Variables

| Variable | Target | Example Values | Description |
|---|---|---|---|
| `GTK_THEME` | GTK 3 & GTK 4 | `"Nordic"`, `"Adwaita-dark"`, `"Catppuccin-Mocha"` | Forces a fixed GTK widget theme across all GTK applications. |
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

## 3. Configuration Entries & Examples (`user_env.lua`)

Add your desired overrides using the `hl.env("KEY", "VALUE")` function:

### Example A: Dark Nordic Style

```lua
-- Force specific GTK theme
hl.env("GTK_THEME", "Nordic")

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

-- Standard cursor
hl.env("HYPRCURSOR_THEME", "Adwaita")
hl.env("XCURSOR_THEME", "Adwaita")
hl.env("HYPRCURSOR_SIZE", "24")
hl.env("XCURSOR_SIZE", "24")
```

---

## 4. How to Change and Lock Icon Themes

Because icon themes are not controlled by environment variables, use one of the following methods to change your icon theme:

### Method A: Via `nwg-look` (Recommended GUI)

1. Open **Kool Quick Settings** (`SUPER + SHIFT + E`), go to **`[[ Misc ]]`**, and select **`GTK Settings (nwg-look)`** (or run `nwg-look` in a terminal).
2. Go to the **Icon Theme** tab.
3. Select your desired icon theme (e.g., `candy-icons`, `Papirus-Dark`).
4. Click **Apply**.

This updates `gsettings`, `~/.config/gtk-3.0/settings.ini`, `~/.config/gtk-4.0/settings.ini`, and `xsettingsd`.

### Method B: Via CLI (`gsettings` / `dconf`)

Run the following command to set the icon theme across GTK/GNOME desktop interfaces and portals:

```bash
gsettings set org.gnome.desktop.interface icon-theme 'candy-icons'
```

On NixOS or systems using dconf directly:

```bash
dconf write /org/gnome/desktop/interface/icon-theme "'candy-icons'"
```

### Method C: Via GTK Configuration Files

Ensure the icon theme is specified in `~/.config/gtk-3.0/settings.ini` and `~/.config/gtk-4.0/settings.ini`:

```ini
[Settings]
gtk-icon-theme-name = candy-icons
```

### Method D: For Qt Applications

KoolDots configures Qt applications with `qt6ct` (`hl.env("QT_QPA_PLATFORMTHEME", "qt6ct")`). To set your icon theme for Qt applications:
1. Run `qt6ct` (or `qt5ct`).
2. Navigate to the **Icon Theme** tab, select your icon theme, and click **Apply**.

---

## 5. Applying and Verifying Changes

1. **Save your files**:
   Save any edits made to `user_env.lua` or settings files.
2. **Reload Hyprland**:
   Press `SUPER + ALT + R` or run:
   ```bash
   hyprctl reload
   ```
3. **Log out and log back in**:
   Because environment variables are read by desktop applications when they launch, log out (`CTRL + ALT + Delete`) and log back into Hyprland to ensure all GUI applications adopt the new settings.
4. **Verification**:
   Open a terminal and verify your active settings:
   ```bash
   echo $GTK_THEME
   echo $HYPRCURSOR_THEME
   gsettings get org.gnome.desktop.interface icon-theme
   ```
