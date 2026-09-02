# How to Add Autostart Applications in KoolDots (`user_startup.lua`)

In **KoolDots (2026)** with the Lua configuration workflow, all personal autostart applications, system tray applets, background services, and custom startup scripts are managed in:

```
~/.config/hypr/UserConfigs/user_startup.lua
```

This guide explains how `user_startup.lua` works, how it differs from system startup tasks, and provides step-by-step examples for common use cases.

---

## 1. Overview & Architecture

### System vs. User Startup

- **System Startup (`~/.config/hypr/configs/system_startup.lua` & `lua/startup.lua`)**:
  Manages core environment services like Waybar, wallpaper daemon, notification daemon (`swaync`), Polkit agent, Quickshell, clipboard history, idle manager (`hypridle`), etc.
- **User Startup (`~/.config/hypr/UserConfigs/user_startup.lua`)**:
  Reserved exclusively for your personal applications and preferences. It will **not** be overwritten by core updates when using standard update routines.

### How `exec_once` Works

Under the hood, `user_startup.lua` uses a managed `exec_once(command)` helper that:

1. **Ensures Single Execution**: Prevents applications from launching multiple times when reloading Hyprland configuration.
2. **Waits for Wayland & Hyprland Sockets**: Prevents startup race conditions where apps crash because the compositor or display socket is not ready yet.
3. **Writes Per-Command Logs**: Outputs stderr/stdout to `/tmp/hypr-lua-user-startup-<cmd>.log` to make troubleshooting trivial.

---

## 2. Step-by-Step: Adding an Application

### Step 1: Open `user_startup.lua`

Open the file in your preferred editor (or via terminal):

```bash
nano ~/.config/hypr/UserConfigs/user_startup.lua
# or
nvim ~/.config/hypr/UserConfigs/user_startup.lua
```

### Step 2: Locate the `startup_commands` table

Find the `startup_commands` list near the bottom of the file:

```lua
-- Add custom startup commands:
local startup_commands = {
  -- "kdeconnect-app",
  -- "blueman-applet",
  -- "$HOME/.config/hypr/UserScripts/RainbowBorders.sh",
}
```

### Step 3: Add your commands

Add any valid shell command or binary name as a quoted string in the table. Make sure each item ends with a comma `,`:

```lua
local startup_commands = {
  "blueman-applet",
  "nm-applet --indicator",
  "flatpak run com.discordapp.Discord --start-minimized",
  "spotify --minimized",
}
```

### Step 4: Save & Apply

To test your new startup entries:
- Log out and log back into Hyprland, or reboot your machine.
- Since `exec_once` is designed for initial session boot, logging out/in starts the newly added apps.

---

## 3. Practical Examples by Category

### A. System Tray & Hardware Applets

```lua
local startup_commands = {
  "blueman-applet",                -- Bluetooth manager tray applet
  "nm-applet --indicator",         -- NetworkManager tray applet
  "pasystray",                     -- Audio volume tray control
  "udiskie --tray",                -- Auto-mount USB drives with tray icon
  "cbatticon",                     -- Laptop battery monitor tray applet
}
```

### B. Chat, Messengers & Social Apps

For native and Flatpak applications:

```lua
local startup_commands = {
  "flatpak run com.discordapp.Discord --start-minimized",
  "flatpak run org.telegram.desktop -startintray",
  "element-desktop --hidden",
  "slack -u",
}
```

### C. Productivity, Passwords & Media

```lua
local startup_commands = {
  "1password --silent",
  "copyq --start-server",
  "spotify --minimized",
  "kdeconnect-app",
}
```

### D. Cloud Sync & Backup Daemons

```lua
local startup_commands = {
  "nextcloud --background",
  "insync start",
  "megasync",
}
```

### E. Custom Scripts & Delayed Notifications

Use `$HOME` or standard shell chaining (`sleep`, `&&`, `;`):

```lua
local startup_commands = {
  "$HOME/.config/hypr/UserScripts/RainbowBorders.sh",
  "$HOME/.config/hypr/UserScripts/WallpaperAutoChange.sh $HOME/Pictures/wallpapers",
  "sleep 3; notify-send 'Welcome' 'Hyprland session started successfully!'",
}
```

---

## 4. Advanced: Direct `exec_once` Calls

While putting commands in the `startup_commands` table is the cleanest approach, you can also directly call `exec_once()` anywhere in `user_startup.lua`:

```lua
local exec_once = user_startup_helper.exec_once

exec_once("openrgb --startminimized --profile 'Default'")
```

---

## 5. Troubleshooting & Debugging

If an application does not appear after logging in:

1. **Check the Startup Logs**:
   Look inside `/tmp/` for logs created by the startup helper:
   ```bash
   ls -la /tmp/hypr-lua-user-startup-*.log
   cat /tmp/hypr-lua-user-startup-<your_app_name>*.log
   ```

2. **Verify Binary Availability**:
   Ensure the program is installed and accessible in your `$PATH`:
   ```bash
   which blueman-applet
   which flatpak
   ```

3. **Check Lua Syntax**:
   Ensure you did not introduce syntax errors (like a missing comma or quote) by running:
   ```bash
   luac -p ~/.config/hypr/UserConfigs/user_startup.lua
   ```

4. **Clear Session Markers (for testing without rebooting)**:
   If you want to re-run `exec_once` commands without a full re-login, clear the session marker files:
   ```bash
   rm -f /tmp/hypr-lua-user-exec-once-*
   ```

---

## 6. Related Configuration Files

- **`~/.config/hypr/UserConfigs/user_keybinds.lua`**: Manage custom keybindings, unbinds, and app launcher shortcuts.
- **`~/.config/hypr/UserConfigs/user_window_rules.lua`**: Set window rules (e.g. float, pin, workspace assignments for autostarted apps).
- **`~/.config/hypr/UserConfigs/user_settings.lua`**: Customize general Hyprland appearance, input devices, and gestures.
