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
2. **Waits for a usable session**: Every command waits for the Wayland socket *and* for Hyprland's IPC to report at least one output. The compositor creates its socket long before it has finished starting, so a command that runs at the earliest opportunity can initialise against a compositor with no outputs yet — the same reason the system startup scripts poll for monitors before doing anything.
3. **Spawns through the compositor**: Commands are launched with Hyprland's own `hl.exec_cmd`, the same spawn path the old `exec-once` used. The process gets the session environment, a clean signal mask and its own session, which is what tray applets, D-Bus services and GUI clients need. `&` and `disown` are therefore unnecessary — the command is already detached.
4. **Writes Per-Command Logs**: Outputs stderr/stdout to `/tmp/hypr-lua-user-startup-<cmd>.log` to make troubleshooting trivial.

The system startup list (`lua/startup.lua`) uses this same helper, so both lists behave identically.

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
  "$HOME/.config/hypr/UserScripts/WallpaperAutoChange.sh $HOME/Pictures/wallpapers",
  "sleep 3; notify-send 'Welcome' 'Hyprland session started successfully!'",
}
```

**Note:** Rainbow borders are not a `user_startup.lua` entry. Pick a mode from Quick Settings → **Rainbow Borders Mode** (`SUPER SHIFT + E`). The choice is stored in `~/.config/hypr/UserScripts/rainbow-borders.mode` and is re-applied automatically at login and after every wallpaper/theme change — see section 4.

**Note:** Do not add `& disown` to commands. `exec_once` already detaches the process through the compositor, and `disown` is not a builtin in the POSIX shell (`sh`) the command runs under, so it only adds a "not found" line to the log.

---

## 4. Startup ordering and the `sleep` workaround

Your commands run **at the same time as** the system startup list, not after it. That list contains the wallpaper pass:

```lua
"sleep 1; $HOME/.config/hypr/scripts/WallpaperDaemon.sh && $HOME/.config/hypr/scripts/WaybarStartup.sh"
```

That pass rewrites Hyprland state from the Wallust palette, including `general:col.active_border`, `decoration.shadow.color` and the group border colours. Anything you start that writes the same options gets **overwritten about a second later**, which looks exactly like "my command had no effect".

This is why a `sleep` appears to fix some entries. It is a workaround, not a fix:

- It is a race, not a delay. A slower machine, a different wallpaper pass, or a theme change later in the session brings the problem back.
- A one-shot script that sets a border only wins until the next wallpaper change. Use the persistent modes instead: a Rainbow Borders Mode selected from Quick Settings is re-applied after every wallpaper/theme pass and now survives login.
- Adding `sleep` also changes the command string, which changes the marker file name under `/tmp`, so the entry runs again once even if it had been skipped.

If something genuinely has to run after the wallpaper pass, chain it behind the script that owns that state (for example `WallpaperDaemon.sh && your-command`) instead of guessing a delay.

---

## 5. Advanced: Direct `exec_once` Calls

While putting commands in the `startup_commands` table is the cleanest approach, you can also directly call `exec_once()` anywhere in `user_startup.lua`:

```lua
local exec_once = user_startup_helper.exec_once

exec_once("openrgb --startminimized --profile 'Default'")
```

---

## 6. Troubleshooting & Debugging

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
   A command is marked as done *before* it runs, so an entry that failed once is not retried in the same session.

5. **The app starts but the effect disappears**:
   Another startup step owns the same Hyprland option. See section 4.

6. **An entry that only works with `sleep` in front of it**:
   Also section 4 — the delay is masking an ordering race, not fixing one.

---

## 7. Related Configuration Files

- **`~/.config/hypr/UserConfigs/user_keybinds.lua`**: Manage custom keybindings, unbinds, and app launcher shortcuts.
- **`~/.config/hypr/UserConfigs/user_window_rules.lua`**: Set window rules (e.g. float, pin, workspace assignments for autostarted apps).
- **`~/.config/hypr/UserConfigs/user_settings.lua`**: Customize general Hyprland appearance, input devices, and gestures.
