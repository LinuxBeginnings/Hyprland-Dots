# KooL's Hyprland-Dots — User Guide

A practical guide to the default keybindings and to the files in
`$HOME/.config/hypr/UserConfigs`, which is where everything personal lives.

- Wiki: <https://github.com/LinuxBeginnings/Hyprland-Dots/wiki>
- Repo: <https://github.com/LinuxBeginnings/Hyprland-Dots>
- Changelogs: <https://github.com/LinuxBeginnings/Hyprland-Dots/wiki/Changelogs>

---

## Table of Contents

1. [Overview](#1-overview)
2. [Installation](#2-installation)
3. [The Quick Settings menu (SUPER + SHIFT + E)](#3-the-quick-settings-menu-super--shift--e)
4. [Default keybindings](#4-default-keybindings)
   - [4.1 Launchers, menus and apps](#41-launchers-menus-and-apps)
   - [4.2 Window management](#42-window-management)
   - [4.3 Focus, move, resize and swap](#43-focus-move-resize-and-swap)
   - [4.4 Layouts and groups](#44-layouts-and-groups)
   - [4.5 Workspaces and special workspace](#45-workspaces-and-special-workspace)
   - [4.6 Screenshots](#46-screenshots)
   - [4.7 Monitors and display layouts](#47-monitors-and-display-layouts)
   - [4.8 Theme, look and session](#48-theme-look-and-session)
   - [4.9 Media, volume, brightness and hardware keys](#49-media-volume-brightness-and-hardware-keys)
5. [The UserConfigs directory](#5-the-userconfigs-directory)
   - [5.1 What each file covers](#51-what-each-file-covers)
   - [5.2 Load order (why some files win)](#52-load-order-why-some-files-win)
6. [Editing the UserConfigs files](#6-editing-the-userconfigs-files)
   - [6.1 `user_keybinds.lua`](#61-user_keybindslua)
   - [6.2 `user_settings.lua`](#62-user_settingslua)
   - [6.3 `user_decorations.lua`](#63-user_decorationslua)
   - [6.4 `user_animations.lua`](#64-user_animationslua)
   - [6.5 `user_window_rules.lua`](#65-user_window_ruleslua)
   - [6.6 `user_layer_rules.lua`](#66-user_layer_ruleslua)
   - [6.7 `user_startup.lua`](#67-user_startuplua)
   - [6.8 `user_env.lua`](#68-user_envlua)
   - [6.9 `user_defaults.lua`](#69-user_defaultslua)
   - [6.10 `monitors.lua`](#610-monitorslua)
   - [6.11 `workspaces.lua`](#611-workspaceslua)
   - [6.12 `user_laptops.lua`](#612-user_laptopslua)
7. [Applying, checking and undoing changes](#7-applying-checking-and-undoing-changes)
8. [Further reading](#8-further-reading)

---

## 1. Overview

KooL's Hyprland-Dots is a set of pre-configured Hyprland dotfiles for Wayland
desktops, shipped together with a copy script that installs them into
`$HOME/.config`. The repo installs **configuration only** — no packages, no
services. The per-distro install scripts (linked below) install the packages and
optionally pull these dots.

The current configuration is written in Hyprland's **Lua config API**
(`hyprland.lua` plus modules loaded with `dofile`), not the older
`.conf`/Hyprlang workflow. That is why every example in this guide is a Lua
table call such as `hl.config({...})`, `hl.bind(...)` or `apply_window_rule({...})`.

The layout is deliberately split in two:

| Layer             | Location in this repo          | Installed at                          | Managed by                         |
| ----------------- | ------------------------------ | ------------------------------------- | ---------------------------------- |
| System defaults   | `config/hypr/configs/`         | `$HOME/.config/hypr/configs/`         | the dotfiles — replaced on upgrade |
| Shared modules    | `config/hypr/lua/`             | `$HOME/.config/hypr/lua/`             | the dotfiles — replaced on upgrade |
| **Your settings** | **`config/hypr/UserConfigs/`** | **`$HOME/.config/hypr/UserConfigs/`** | **you — preserved on upgrade**     |
| Your scripts      | `config/hypr/UserScripts/`     | `$HOME/.config/hypr/UserScripts/`     | you — preserved on upgrade         |
| Entrypoint        | `config/hypr/hyprland.lua`     | `$HOME/.config/hypr/hyprland.lua`     | the dotfiles                       |

Two rules follow from that table:

- Edit `UserConfigs/`, not `configs/`. `configs/` is overwritten when you upgrade.
- Do not rename the files in `UserConfigs/`. `hyprland.lua` and
  `lua/user_overrides.lua` load them by name; a rename means the file silently
  stops loading.

Upgrades never replace your `UserConfigs` files. They may apply small,
non-destructive patches to them (adding one setting, never rewriting the file) —
see [`Patching-UserConfigs.md`](./Patching-UserConfigs.md).

---

## 2. Installation

Full instructions, requirements and troubleshooting live in the wiki:

> **Hyprland-Dots Wiki — Install & Update:**
> <https://github.com/LinuxBeginnings/Hyprland-Dots/wiki/Install_&_Update>

The recommended path is the distro install script for your system. Each one
installs the required packages and offers to pull these dotfiles:

| Distro                          | Install scripts                                                 |
| ------------------------------- | --------------------------------------------------------------- |
| Arch Linux                      | <https://github.com/LinuxBeginnings/Arch-Hyprland>              |
| Fedora (43 / 44 / Rawhide)      | <https://github.com/LinuxBeginnings/Fedora-Hyprland>            |
| Debian (Trixie / Testing / SID) | <https://github.com/LinuxBeginnings/Debian-Hyprland>            |
| NixOS (25.05+)                  | <https://github.com/LinuxBeginnings/NixOS-Hyprland>             |
| Ubuntu 24.04 LTS                | <https://github.com/LinuxBeginnings/Ubuntu-Hyprland/tree/24.04> |
| Ubuntu 26.04 LTS                | <https://github.com/LinuxBeginnings/Ubuntu-Hyprland/tree/26.04> |

No longer supported: OpenSUSE Tumbleweed, Ubuntu 24.10 / 25.04 / 25.10.

Bootstrap helper (clones the right install script and starts it):

```bash
sh <(curl -L https://raw.githubusercontent.com/LinuxBeginnings/Hyprland-Dots/main/Distro-Hyprland.sh)
```

> The bootstrap helper is not fish-shell safe. On fish, clone the Distro-Hyprland
> repo for your distro and run `install.sh` directly.

Installing or updating the dots only (packages assumed present):

```bash
git clone --depth=1 https://github.com/LinuxBeginnings/Hyprland-Dots.git
cd Hyprland-Dots
chmod +x copy.sh
./copy.sh
```

`copy.sh` backs up anything it is about to replace under `$HOME/.config`, copies
`config/` into `$HOME/.config`, and leaves `UserConfigs/` and `UserScripts/`
alone on an existing install. Check `$HOME/.config` afterwards and delete any
backups you do not want.

After installing:

- **NVIDIA users:** read the wiki FAQ (<https://github.com/LinuxBeginnings/Hyprland-Dots/wiki/FAQ_NVIDIA>)
  and review `$HOME/.config/hypr/UserConfigs/user_env.lua`.
- **Hybrid Intel/NVIDIA or AMD/NVIDIA laptops:** the installer enables cursor
  fallbacks automatically; expect a cursor reset at session start.
- Log out and back in (or reboot) so the new config is loaded.

---

## 3. The Quick Settings menu (SUPER + SHIFT + E)

```
SUPER + SHIFT + E
```

Opens a rofi menu that is the fastest way to reach the files in this guide.
Picking an `Edit …` entry opens that file in your editor — `user_defaults.lua`
first, then `$VISUAL`/`$EDITOR`, then `nvim`/`vim`/`nano`. Terminal editors open
inside your terminal. When the editor exits, the script runs `luac -p` on the
file and notifies you if the Lua syntax is broken, which is exactly the mistake
that stops Hyprland from loading a config.

The main menu is two columns:

- **Left — categories:** `[[ User Settings ]]`, `[[ System Settings ]]`,
  `[[ Toggle Options ]]`, `[[ Misc ]]`
- **Right — quick links:** the entries you reach most often

| Category        | Entries                                                                                                                                                                                                                                                                                       |
| --------------- | --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| User Settings   | Manage / Edit User Defaults, Edit User Keybinds, Edit User ENV variables, Edit User Startup Apps, Edit User Window Rules, Edit User Layer Rules, Edit User Settings, Edit User Decorations, Edit User Animations, Edit User Laptop Settings, Edit User Monitor config, Select Hyprview Layout |
| System Settings | Edit System Default Keybinds, Startup Apps, Window Rules, Layer Rules, Settings                                                                                                                                                                                                               |
| Toggle Options  | Waybar weather units, Waybar clock 12H/24H, Game Mode, Window Wobble                                                                                                                                                                                                                          |
| Misc            | Starship prompt, SDDM wallpaper, Kitty/Ghostty/Wlogout themes, nwg-displays, nwg-look, qt6ct/qt5ct, Hyprlock wallpaper, animations, monitor profiles, rofi themes, keybind search, palette source, rainbow borders                                                                            |

Two other menus that are worth knowing:

- `SUPER + SHIFT + K` — searchable keybind list (the same data as the tables below)
- `SUPER + H` — key hints cheat sheet

---

## 4. Default keybindings

These are the shipped defaults from `$HOME/.config/hypr/configs/system_keybinds.lua`.
They are defined as shown and are not meant to be edited in place — copy what you
want to change into `$HOME/.config/hypr/UserConfigs/user_keybinds.lua` instead.

`SUPER` is the Windows/Super key. Key names are XKB keysyms, so arrows are
`left/right/up/down`, the number row is bound by keycode (`code:10` = `1`) so it
works on layouts where the digit is not produced unshifted.

### 4.1 Launchers, menus and apps

| Keys                     | Action                      |
| ------------------------ | --------------------------- |
| `SUPER + D`              | App launcher (rofi drun)    |
| `SUPER + Return`         | Terminal                    |
| `SUPER + E`              | File manager                |
| `SUPER + B`              | Default browser             |
| `SUPER + A`              | Desktop overview            |
| `SUPER + CTRL + A`       | AGS (shell) overview        |
| `SUPER + SHIFT + Return` | Drop-down terminal          |
| `SUPER + C`              | SSH session manager         |
| `SUPER + S`              | Web search                  |
| `SUPER + CTRL + S`       | Window switcher             |
| `SUPER + ALT + E`        | Emoji picker                |
| `SUPER + ALT + V`        | Clipboard manager           |
| `SUPER + ALT + C`        | Calculator                  |
| `SUPER + SHIFT + M`      | Online music (RofiBeats)    |
| `SUPER + SHIFT + N`      | Notification panel (swaync) |
| `SUPER + SHIFT + K`      | Search keybinds             |
| `SUPER + SHIFT + E`      | Quick Settings menu         |
| `SUPER + H`              | Key hints / cheat sheet     |
| `SUPER + ALT + R`        | Refresh Waybar and menus    |

### 4.2 Window management

| Keys                                     | Action                                      |
| ---------------------------------------- | ------------------------------------------- |
| `SUPER + Q`                              | Close active window                         |
| `SUPER + SHIFT + Q`                      | Terminate the active window's process       |
| `SUPER + F`                              | Maximize window                             |
| `SUPER + SHIFT + F`                      | Toggle fullscreen                           |
| `SUPER + SPACE`                          | Toggle floating for active window           |
| `SUPER + ALT + SPACE`                    | Float all windows                           |
| `SUPER + CTRL + SPACE`                   | Float all windows at the same size          |
| `SUPER + CTRL + O`                       | Toggle active window opacity                |
| `SUPER + SHIFT + H`                      | Mute / unmute the active window's audio     |
| `ALT + Tab`                              | Cycle to next window, brought to top        |
| `SUPER + j` / `SUPER + k`                | Cycle next / previous window (layout-aware) |
| `SUPER + mouse right-drag` (`mouse:273`) | Resize window                               |
| `SUPER + mouse left-drag` (`mouse:272`)  | Move window                                 |

### 4.3 Focus, move, resize and swap

| Keys                      | Action                                           |
| ------------------------- | ------------------------------------------------ |
| `SUPER + ←/→/↑/↓`         | Focus in that direction (layout-aware)           |
| `SUPER + CTRL + ←/→/↑/↓`  | Move window in that direction                    |
| `SUPER + SHIFT + ←/→/↑/↓` | Resize window (`±50 px`, repeats while held)     |
| `SUPER + ALT + ←/→/↑/↓`   | Swap window with the neighbour in that direction |

### 4.4 Layouts and groups

| Keys                      | Action                                  |
| ------------------------- | --------------------------------------- |
| `SUPER + ALT + 1`         | Dwindle layout                          |
| `SUPER + ALT + 2`         | Master layout                           |
| `SUPER + ALT + 3`         | Scrolling layout                        |
| `SUPER + ALT + 4`         | Monocle layout                          |
| `SUPER + ALT + L`         | Cycle layouts                           |
| `SUPER + P`               | Toggle pseudo-tiling (dwindle)          |
| `SUPER + SHIFT + I`       | Toggle split (dwindle)                  |
| `SUPER + M`               | Set split ratio `0.3`                   |
| `SUPER + I`               | Add master (master layout)              |
| `SUPER + CTRL + D`        | Remove master                           |
| `SUPER + CTRL + Return`   | Swap window with master                 |
| `SUPER + R`               | Cycle column-width preset (scrolling)   |
| `SUPER + ALT + H`         | Scrolling layout: horizontal direction  |
| `SUPER + CTRL + V`        | Scrolling layout: vertical direction    |
| `SUPER + ALT + S`         | Toggle scrolling layout direction (V/H) |
| `SUPER + SHIFT + .` / `,` | Move window to right / left column      |
| `SUPER + ALT + .` / `,`   | Swap columns right / left               |
| `SUPER + G`               | Toggle group                            |
| `SUPER + Tab`             | Next window in group                    |
| `SUPER + SHIFT + Tab`     | Previous window in group                |
| `SUPER + CTRL + J` / `L`  | Move window into group (left / right)   |
| `SUPER + CTRL + H`        | Move window out of group                |
| `SUPER + CTRL + Tab`      | Hyprview overview toggle                |

### 4.5 Workspaces and special workspace

| Keys                      | Action                                             |
| ------------------------- | -------------------------------------------------- |
| `SUPER + 1…0`             | Switch to workspace 1…10                           |
| `SUPER + SHIFT + 1…0`     | Move active window to workspace 1…10               |
| `SUPER + CTRL + 1…0`      | Move window silently (no focus follow)             |
| `SUPER + Tab`             | Next workspace (uses the free slot, `m+1`)         |
| `SUPER + SHIFT + Tab`     | Previous workspace                                 |
| `SUPER + .` / `,`         | Next / previous workspace (`e+1` / `e-1`)          |
| `SUPER + mouse wheel`     | Next / previous workspace                          |
| `SUPER + SHIFT + ]` / `[` | Move window to next / previous workspace           |
| `SUPER + CTRL + ]` / `[`  | Move window silently to next / previous workspace  |
| `SUPER + U`               | Toggle special workspace                           |
| `SUPER + SHIFT + U`       | Move active window to special workspace            |
| `SUPER + CTRL + F9…F12`   | Move workspace to left / right / up / down monitor |

`SUPER + Tab` and `SUPER + SHIFT + Tab` also change the group when a group has
focus; that is an upstream overlap, not a bug.

### 4.6 Screenshots

| Keys                                                 | Action                          |
| ---------------------------------------------------- | ------------------------------- |
| `SUPER + Print` or `SUPER + F6`                      | Screenshot now                  |
| `SUPER + SHIFT + Print` or `SUPER + SHIFT + F6`      | Screenshot of a selected area   |
| `SUPER + CTRL + Print` or `SUPER + CTRL + F6`        | Screenshot after 5 s            |
| `SUPER + CTRL + SHIFT + Print` or `SUPER + ALT + F6` | Screenshot after 10 s           |
| `ALT + Print` or `ALT + F6`                          | Screenshot of the active window |
| `SUPER + SHIFT + S`                                  | Screenshot area, open in swappy |
| `ALT + SHIFT + S`                                    | Hyprshot region capture         |

### 4.7 Monitors and display layouts

| Keys              | Action                                                    |
| ----------------- | --------------------------------------------------------- |
| `SUPER + ALT + D` | Display-layouts menu for the monitors currently connected |
| `SUPER + ALT + W` | Apply the saved layout named `Work`                       |

Layouts are saved per monitor set (not per port) and are written to
`$HOME/.config/hypr/UserConfigs/monitors.lua`. Press `SUPER + ALT + D`, arrange
the screens, then "Save current state as…". `SUPER + SHIFT + E` → **Choose
Monitor Profiles** lists the same layouts plus the legacy `Monitor_Profiles/`
files, which it can import one way. Full description:
[`README-display-layouts.md`](../README-display-layouts.md).

### 4.8 Theme, look and session

| Keys                       | Action                            |
| -------------------------- | --------------------------------- |
| `SUPER + T`                | Global theme switcher (Wallust)   |
| `SUPER + W`                | Select wallpaper                  |
| `SUPER + SHIFT + W`        | Wallpaper effects                 |
| `SUPER + CTRL + ALT + W`   | Random wallpaper                  |
| `SUPER + N`                | Toggle Hyprsunset (night light)   |
| `SUPER + SHIFT + G`        | Toggle game mode                  |
| `SUPER + SHIFT + X`        | Toggle window wobble              |
| `SUPER + ALT + O`          | Toggle blur                       |
| `SUPER + SHIFT + A`        | Animations menu                   |
| `SUPER + SHIFT + B`        | Rainbow borders mode menu         |
| `SUPER + SHIFT + O`        | Change oh-my-zsh theme            |
| `SUPER + CTRL + B`         | Waybar styles menu                |
| `SUPER + ALT + B`          | Waybar layout menu                |
| `SUPER + CTRL + ALT + B`   | Toggle Waybar on / off            |
| `SUPER + CTRL + R`         | Rofi theme selector               |
| `SUPER + CTRL + SHIFT + R` | Rofi theme selector (modified)    |
| `SUPER + CTRL + K`         | Kitty theme selector              |
| `SUPER + CTRL + G`         | Ghostty theme selector            |
| `SUPER + CTRL + W`         | wlogout theme selector            |
| `SUPER + CTRL + SHIFT + W` | wlogout wallpaper selector        |
| `CTRL + ALT + L`           | Lock screen                       |
| `CTRL + ALT + P`           | Power menu (wlogout)              |
| `CTRL + ALT + D`           | Toggle dock                       |
| `CTRL + ALT + Delete`      | Exit Hyprland                     |
| `ALT + Shift` (either)     | Switch keyboard layout globally   |
| `SHIFT + Alt` (either)     | Switch keyboard layout per window |

### 4.9 Media, volume, brightness and hardware keys

These use the `""` (no modifier) chord and are marked `locked`, so they keep
working with the lockscreen up.

| Keys                                                          | Action                          |
| ------------------------------------------------------------- | ------------------------------- |
| `XF86AudioRaiseVolume` / `XF86AudioLowerVolume`               | Volume up / down                |
| `ALT + XF86AudioRaiseVolume` / `LowerVolume`                  | Volume up / down (fine step)    |
| `XF86AudioMute`                                               | Mute / unmute                   |
| `XF86AudioMicMute`                                            | Mute / unmute microphone        |
| `XF86AudioPlay` / `Pause` / `Next` / `Prev` / `Stop`          | Media transport                 |
| `XF86MonBrightnessUp` / `Down`                                | Screen brightness               |
| `CTRL + ALT + =` / `-`, `CTRL + ALT + KP_Add` / `KP_Subtract` | Screen brightness (no Fn row)   |
| `XF86KbdBrightnessUp` / `Down` / `KbdLightOnOff`              | Keyboard backlight              |
| `XF86TouchpadToggle`                                          | Toggle touchpad                 |
| `XF86Sleep`                                                   | Suspend                         |
| `XF86Rfkill`                                                  | Airplane mode                   |
| `XF86Launch1`                                                 | ASUS Armoury Crate button       |
| `XF86Launch3`                                                 | ASUS: next keyboard RGB profile |
| `XF86Launch4`                                                 | ASUS: next fan profile          |

There is also a keyboard-passthrough submap: `SUPER + SHIFT + P` sends your
keystrokes to the focused window (useful for VMs and remote sessions), and
`SUPER + ALT + P` leaves it. Waybar shows `submap: Bind KB` while it is active.

---

## 5. The UserConfigs directory

Everything below is `$HOME/.config/hypr/UserConfigs/` once installed (in this
repo: `config/hypr/UserConfigs/`).

### 5.1 What each file covers

| File                    | What it covers                                                                                                  |
| ----------------------- | --------------------------------------------------------------------------------------------------------------- |
| `user_keybinds.lua`     | Your keybinds: add new combos, override or move the defaults                                                    |
| `user_settings.lua`     | Input devices: keyboard layouts, repeat rate, touchpad, mouse, tablets, and `misc`/`cursor` options             |
| `user_decorations.lua`  | Look of windows: gaps, border size and colour, rounding, opacity, blur, shadows, dimming, group colours, wobble |
| `user_animations.lua`   | Animation on/off and per-leaf animation curves and styles                                                       |
| `user_window_rules.lua` | Per-app window rules: float, size, position, workspace, opacity, pin, tags, no blur                             |
| `user_layer_rules.lua`  | Layer-surface rules for bars, launchers, notifications (e.g. rofi blur)                                         |
| `user_startup.lua`      | Autostart: tray applets, daemons, personal scripts                                                              |
| `user_env.lua`          | Environment variables for the session (`hl.env`)                                                                |
| `user_defaults.lua`     | `KOOLDOTS_DEFAULTS`: terminal, file manager, editor, visual editor, search engine                               |
| `monitors.lua`          | Monitor modes, positions, scales — also written by the display-layout system                                    |
| `workspaces.lua`        | Workspace-to-monitor rules — also written by the display-layout system                                          |
| `user_laptops.lua`      | Laptop lid / clamshell and hotplug behaviour (self-driving; usually leave alone)                                |

Non-config files in the same directory, edited directly rather than through the
settings menu:

| File                          | Purpose                                              |
| ----------------------------- | ---------------------------------------------------- |
| `kitty.conf`, `kitty-themes/` | Kitty terminal config and theme set                  |
| `ghostty.conf`                | Ghostty terminal config                              |
| `hyprview-layout.conf`        | Selected Hyprview overview layout                    |
| `display-layouts.json`        | Saved display layouts (written by the layout system) |

### 5.2 Load order (why some files win)

`$HOME/.config/hypr/hyprland.lua` is the entrypoint. It loads `lua/user_defaults.lua`
(which in turn reads your `UserConfigs/user_defaults.lua`), then the keybind
index, then `lua/user_overrides.lua`, which loads in this order:

```
configs/system_env.lua        →  UserConfigs/user_env.lua
configs/system_startup.lua    →  UserConfigs/user_startup.lua
configs/system_window_rules.lua → UserConfigs/user_window_rules.lua
configs/system_layer_rules.lua  → UserConfigs/user_layer_rules.lua
configs/system_keybinds.lua   →  UserConfigs/user_keybinds.lua
configs/system_settings.lua   →  UserConfigs/user_settings.lua
configs/system_laptops.lua    →  UserConfigs/user_laptops.lua
                              →  UserConfigs/user_decorations.lua
                              →  UserConfigs/user_animations.lua
```

then `lua/monitors.lua` and `lua/workspaces.lua`, which read your
`UserConfigs/monitors.lua` and `UserConfigs/workspaces.lua`.

Consequences worth remembering:

- Your file loads **after** the system file, so a setting you repeat there wins.
- `user_decorations.lua` loads after `user_settings.lua`, so a `general` table in
  `user_settings.lua` would be overwritten by the one in `user_decorations.lua`.
  Put gaps and borders in `user_decorations.lua`.
- Keybinds are appended, not replaced. If a combo is already bound, run
  `unbind("MODS", "KEY")` first, then `bind(...)` it again.

---

## 6. Editing the UserConfigs files

Open any of them with `SUPER + SHIFT + E`, or edit the file directly. Save the
file and the config reloads — `scripts/LuaConfigWatch.sh` watches the loaded
directories and pokes the entrypoint, because Hyprland's own autoreload only
watches `hyprland.lua` itself. If the watcher is not running (it needs
`inotify-tools`), run `hyprctl reload` yourself.

Each file ships with commented examples. Below are those examples plus a few
more; uncomment and adjust.

### 6.1 `user_keybinds.lua`

`$HOME/.config/hypr/UserConfigs/user_keybinds.lua`

```lua
bind("MODS", "KEY", action, [options])
unbind("MODS", "KEY")
```

- Modifiers: `"SUPER"`, `"SHIFT"`, `"CTRL"`, `"ALT"`, combinations like
  `"SUPER SHIFT"` / `"SUPER CTRL SHIFT"`, or `""` for hardware keys.
- Actions: `exec_cmd("command")` to run a command, `dispatch("name", "arg")` for
  compositor dispatchers.

Add a new combo, on keys nothing else uses:

```lua
bind("SUPER", "Z", exec_cmd("ghostty"), { description = "Launch Ghostty" })
bind("SUPER SHIFT", "V", exec_cmd("pavucontrol"), { description = "Audio control" })
bind("SUPER", "X", dispatch("killactive"), { description = "Close active window" })
```

Change what an existing combo does — unbind first, then bind:

```lua
-- SUPER + Return opens kitty by default; make it ghostty
unbind("SUPER", "Return")
bind("SUPER", "Return", exec_cmd("ghostty"), { description = "Launch Ghostty" })
```

Move an action to a different combo:

```lua
-- File manager: SUPER + E → SUPER + F. Emacs takes SUPER + E.
unbind("SUPER", "E")
unbind("SUPER", "F")   -- default: maximize
bind("SUPER", "F", exec_cmd("$HOME/.config/hypr/scripts/LaunchFileManager.sh '$files' '$term'"),
  { description = "File manager" })
bind("SUPER", "E", exec_cmd("emacsclient -c -a 'emacs'"), { description = "Launch Emacs" })
```

Rebind a compositor action:

```lua
unbind("SUPER", "Q")
bind("SUPER", "Q", dispatch("killactive"), { description = "Close active window" })
bind("SUPER SHIFT", "F", dispatch("fullscreen", "0"), { description = "Toggle fullscreen" })
bind("SUPER ALT", "W", dispatch("workspace", "special:scratchpad"), { description = "Scratchpad" })
```

Bind options:

```lua
-- locked = true    → keeps working with the lockscreen up (media keys)
-- repeating = true → repeats while the key is held (volume, brightness)
bind("CTRL ALT", "bracketright", exec_cmd("$HOME/.config/hypr/scripts/Brightness.sh --inc"),
  { description = "Brightness up", repeating = true })
bind("", "XF86AudioMute", exec_cmd("$HOME/.config/hypr/scripts/Volume.sh --toggle"),
  { description = "Mute audio", locked = true })
```

Useful to know:

- `$term`, `$files`, `$edit`, `$visual` are replaced with the values from
  `user_defaults.lua`, so one place changes every bound command.
- Avoid keys the defaults already use (the tables in section 4) unless you
  `unbind` them. The full default list is also in `SUPER + SHIFT + K`.
- `dispatch()` understands the common dispatchers — `killactive`,
  `togglefloating`, `fullscreen`, `workspace`, `movetoworkspace`,
  `togglespecialworkspace`, `togglegroup`, `pseudo`, `layoutmsg`, `resizeactive`,
  `movewindow`, `moveintogroup`, `moveoutofgroup` — and prints a warning at load
  time for a name it has no handler for, rather than silently doing nothing.

More detail: [`HOWTO-Change-Keybindgs.md`](./HOWTO-Change-Keybindgs.md) and
[`Keybinds.md`](./Keybinds.md).

### 6.2 `user_settings.lua`

`$HOME/.config/hypr/UserConfigs/user_settings.lua`

Keyboard, touchpad, mouse and tablet behaviour, plus a few `misc`/`cursor`
options. The shipped example is a complete `input` block; trim it to what you
actually want to change.

Change the keyboard layout and enable two layouts:

```lua
hl.config({
  input = {
    kb_layout = "us,de",
    kb_variant = "",
    kb_options = "grp:alt_shift_toggle",   -- ALT + SHIFT switches layout
  },
  misc = {
    focus_on_activate = true,              -- focus requests from apps
  },
})
```

`kb_layout` and `kb_variant` must have matching comma counts:
`kb_layout = "fr,de"` pairs with `kb_variant = "azerty,"` or `kb_variant = ""`.

Touchpad and mouse tweaks:

```lua
hl.config({
  input = {
    sensitivity = 0.2,              -- -1.0 … 1.0
    follow_mouse = 1,               -- 0 click, 1 hover, 2 detached
    touchpad = {
      natural_scroll = false,
      tap_to_click = true,
      disable_while_typing = true,
      middle_button_emulation = true,
    },
  },
  cursor = {
    no_warps = true,                -- do not recentre the cursor on workspace switch
    warp_on_change_workspace = 0,
  },
})
```

Caps Lock as Escape, and no repeat on the number row, are `kb_options` values:

```lua
hl.config({ input = { kb_options = "caps:escape" } })
```

Gaps, borders and blur are **not** here — they live in `user_decorations.lua`,
which loads later and would overwrite a `general` or `decoration` table set in
this file.

More detail: [`HOWTO-user_settings.lua.md`](./HOWTO-user_settings.lua.md) and
[`HOWTO-Keyboard-Mappings.md`](./HOWTO-Keyboard-Mappings.md).

### 6.3 `user_decorations.lua`

`$HOME/.config/hypr/UserConfigs/user_decorations.lua`

The look of windows: border size and colour, gaps, rounding, opacity, blur,
shadows, dimming, group colours and wobble. Colours are pulled from
`$HOME/.config/hypr/wallust/wallust-hyprland.conf`, so they follow the wallpaper
by default.

Tighter gaps and no rounding:

```lua
hl.config({
  general = {
    border_size = 2,
    gaps_in = 2,
    gaps_out = 8,
  },
  decoration = {
    rounding = 0,
  },
})
```

Frozen (non-wallpaper) border colours:

```lua
hl.config({
  general = {
    col = {
      active_border = "rgba(f7077eff)",
      inactive_border = "rgba(5f6578ff)",
    },
  },
})
```

Stronger blur, and translucent terminals:

```lua
hl.config({
  decoration = {
    active_opacity = 1.0,
    inactive_opacity = 0.90,
    blur = {
      enabled = true,
      size = 8,
      passes = 3,
      xray = true,
    },
  },
})
```

Wobble is a window transformer, not an animation. This table is the only place
it is configured, and `scripts/ToggleWobble.sh` (and `SUPER + SHIFT + X`) flips
`enabled` in place, matching the keys by name — keep the keys, change the values
freely:

```lua
hl.config({
  decoration = {
    wobble = {
      enabled = true,
      mesh = 12,
      stiffness = 240,   -- lower = floatier
      damping = 16,      -- higher = settles faster
      mass = 1,
      intensity = 0.25,
    },
  },
})
```

Inspect the live value with `hyprctl getoption decoration:wobble:enabled`.

More detail: [`HOWTO-user_decorations.lua.md`](./HOWTO-user_decorations.lua.md)
and [`HOWTO-Override-Theme-and-Icons.md`](./HOWTO-Override-Theme-and-Icons.md).

### 6.4 `user_animations.lua`

`$HOME/.config/hypr/UserConfigs/user_animations.lua`

Turn animations off, or change a single animation instead of all of them:

```lua
hl.config({ animations = { enabled = true } })

hl.animation({ leaf = "windows", enabled = true, speed = 5, bezier = "wind", style = "slide" })
hl.animation({ leaf = "workspaces", enabled = true, speed = 4, bezier = "wind", style = "slide" })
```

`SUPER + SHIFT + A` opens a menu with ready-made sets and writes here for you.
The defaults live in `$HOME/.config/hypr/lua/animations.lua`.

### 6.5 `user_window_rules.lua`

`$HOME/.config/hypr/UserConfigs/user_window_rules.lua`

Per-app behaviour: floating, size, position, workspace, opacity, pinning, tags,
no blur, keeping aspect ratio, blocking initial focus.

Find the exact class or title of a window first:

```bash
hyprctl activewindow        # or: hyprctl clients
```

Float and centre a settings window:

```lua
apply_window_rule({
  name = "user-float-pavucontrol",
  match = { class = "^(pavucontrol|org.pulseaudio.pavucontrol)$" },
  float = true,
  center = true,
  size = "(monitor_w*0.5) (monitor_h*0.55)",
})
```

Send apps to fixed workspaces:

```lua
apply_window_rule({ name = "user-spotify-workspace", match = { class = "^([Ss]potify)$" }, workspace = "9" })
apply_window_rule({
  name = "user-discord-workspace",
  match = { class = "^([Dd]iscord|[Ww]ebCord|[Vv]esktop)$" },
  workspace = "10",
})
```

Opacity per app:

```lua
apply_window_rule({
  name = "user-transparent-terminal",
  match = { class = "^(kitty|ghostty|Alacritty)$" },
  opacity = "0.90 0.80",            -- active inactive
})
```

A picture-in-picture window that follows you across workspaces:

```lua
apply_window_rule({
  name = "user-pip-video",
  match = { title = "^[Pp]icture-in-[Pp]icture$" },
  float = true,
  pin = true,
  move = "72% 7%",
  size = "(monitor_w*0.25) (monitor_h*0.25)",
  keep_aspect_ratio = true,
})
```

Stop an app stealing focus at login:

```lua
apply_window_rule({ name = "user-no-focus-slack", match = { class = "^(Slack|slack)$" }, no_initial_focus = true })
```

`match` also accepts `initial_class`, `initial_title`, `tag`, `fullscreen`;
actions also accept `idle_inhibit`, `no_blur`, `tag = "+name"`. `name` must be
unique.

More detail: [`HOWTO-user_window_rules.lua.md`](./HOWTO-user_window_rules.lua.md).

### 6.6 `user_layer_rules.lua`

`$HOME/.config/hypr/UserConfigs/user_layer_rules.lua`

Layer rules apply to surfaces that are not windows — bars, launchers,
notification daemons, lockscreens. The `namespace` is the layer namespace
reported by `hyprctl layers`.

Blur rofi and swaync:

```lua
apply_layer_rule({
  name = "user-rofi-blur",
  match = { namespace = "rofi" },
  blur = true,
  ignore_alpha = 0,
})

apply_layer_rule({
  name = "user-swaync-blur",
  match = { namespace = "notifications" },
  blur = true,
})
```

More detail: [`HOWTO-user_layer_rules.lua.md`](./HOWTO-user_layer_rules.lua.md).

### 6.7 `user_startup.lua`

`$HOME/.config/hypr/UserConfigs/user_startup.lua`

Commands that run once per Hyprland session. Add them to the
`startup_commands` table; `exec_once` makes sure a config reload does not start
them a second time. Each command's output goes to
`/tmp/hypr-lua-user-startup-<cmd>.log`.

```lua
local startup_commands = {
  "$HOME/.config/hypr/scripts/MonitorWatcher.sh",   -- shipped: display layouts
  "kdeconnect-app",
  "blueman-applet",
  "nm-applet --indicator",
  "$HOME/.config/hypr/UserScripts/RainbowBorders.sh",
  "sleep 3; notify-send 'Welcome' 'Hyprland session started'",
}
```

Common entries:

```lua
"pasystray",                                   -- volume tray
"udiskie --tray",                              -- auto-mount removable media
"copyq --start-server",                        -- clipboard history
"flatpak run org.telegram.desktop -startintray",
"1password --silent",
"wlsunset -l 37.77 -l -122.41 -t 4000 -T 6500", -- night colour temperature
```

Do **not** add `DisplayProfile.sh` here: `MonitorWatcher.sh` already runs it,
and two controllers apply layouts at the same time.

More detail: [`HOWTO-Add-Apps-To-user_startup.lua.md`](./HOWTO-Add-Apps-To-user_startup.lua.md).

### 6.8 `user_env.lua`

`$HOME/.config/hypr/UserConfigs/user_env.lua`

Environment variables for the whole session, as `hl.env("NAME", "value")`. They
survive upgrades.

```lua
hl.env("QT_QPA_PLATFORMTHEME", "qt6ct")
hl.env("GDK_SCALE", "1")
hl.env("QT_SCALE_FACTOR", "1")
hl.env("WEATHER_UNITS", "imperial")     -- Waybar weather
hl.env("ELECTRON_OZONE_PLATFORM_HINT", "auto")
hl.env("MOZ_ENABLE_WAYLAND", "1")
hl.env("XCURSOR_SIZE", "24")
```

`WEATHER_UNITS` is also toggled from the Quick Settings menu. Variables that
must be set before Hyprland starts (display manager variables, for example)
belong in your login shell or the session file, not here.

NVIDIA users: review the variables commented in this file and read the wiki FAQ.

More detail: [`HOWTO-user_env.lua.md`](./HOWTO-user_env.lua.md).

### 6.9 `user_defaults.lua`

`$HOME/.config/hypr/UserConfigs/user_defaults.lua`

The programs the keybinds call. Change them once here and every `$term`,
`$files`, `$edit` and `$visual` in the config follows.

```lua
KOOLDOTS_DEFAULTS = KOOLDOTS_DEFAULTS or {}

KOOLDOTS_DEFAULTS.term = "ghostty"          -- SUPER + Return, LaunchTerminal.sh
KOOLDOTS_DEFAULTS.files = "nemo"            -- SUPER + E
KOOLDOTS_DEFAULTS.edit = "nano"             -- default editor
KOOLDOTS_DEFAULTS.visual = "code"           -- overrides edit for GUI editors
KOOLDOTS_DEFAULTS.search_engine = "https://duckduckgo.com/?q={}"
```

`{}` is where the query goes. Values fall back to `$TERMINAL`, `$EDITOR` and
`$VISUAL`, then to the shipped defaults (`kitty`, `thunar`, `nano`).

More detail: [`HOWTO-user_defaults.lua.md`](./HOWTO-user_defaults.lua.md).

### 6.10 `monitors.lua`

`$HOME/.config/hypr/UserConfigs/monitors.lua`

Monitor mode, position, scale and transform, one `hl.monitor({...})` per output.
Output names come from `hyprctl monitors`.

```lua
hl.monitor({ output = "eDP-1", mode = "1920x1200@60", position = "0x0", scale = "1" })
hl.monitor({ output = "HDMI-A-1", mode = "2560x1440@144", position = "1920x0", scale = "1" })
hl.monitor({ output = "DP-1", disabled = true })
```

This file is also written by the display-layout system
(`scripts/DisplayProfile.sh`) and by layouts saved with `SUPER + ALT + D`, so hand
edits can be replaced the next time a layout is applied — save the arrangement as
a layout instead if you want it to stick. If you run `nwg-displays` from the
Quick Settings menu, its arrangement is imported here.

More detail: [`HOWTO-monitors.lua.md`](./HOWTO-monitors.lua.md) and
[`README-display-layouts.md`](../README-display-layouts.md).

### 6.11 `workspaces.lua`

`$HOME/.config/hypr/UserConfigs/workspaces.lua`

Workspace rules. The important one is binding a workspace to a display: with no
rule, `SUPER + 1…0` puts the workspace on whichever monitor has focus, which
looks like the workspace jumping when you switch screens.

```lua
hl.workspace_rule({ workspace = "1", monitor = "eDP-1" })
hl.workspace_rule({ workspace = "2", monitor = "eDP-1" })
hl.workspace_rule({ workspace = "3", monitor = "HDMI-A-1" })
hl.workspace_rule({ workspace = "4", monitor = "HDMI-A-1", default = true })
```

Rules can also carry `gaps_in`, `gaps_out`, `no_rounding`, `persistent`, and a
layout — see `WorkspaceRuleSpec` in `$HOME/.config/hypr/hl.meta.lua`.

Leave alone any rule ending in `-- nwg-displays: ...`: that marker records which
fields the nwg-displays import owns, and the import rewrites only those.
`scripts/PersistWorkspaceLayout.sh` writes here too.

### 6.12 `user_laptops.lua`

`$HOME/.config/hypr/UserConfigs/user_laptops.lua`

Laptop-specific behaviour: it detects the internal panel (`eDP`, `LVDS`, `DSI`),
watches hotplug and lid events, disables the internal panel when the lid is
closed with an external display attached, and restores it when the lid opens or
the external is unplugged. It reads the layout from `monitors.lua`.

It is on purpose self-driving — it binds the lid switch itself, so nothing else
should. Leave it enabled, and manage arrangements through
`UserConfigs/monitors.lua` or a saved display layout rather than by editing the
logic here. The constants you might want are at the top:

```lua
local FALLBACK_INTERNAL = "eDP-1"   -- used when sysfs detection finds nothing
```

---

## 7. Applying, checking and undoing changes

**Apply.** Saving any file under `$HOME/.config/hypr/` triggers
`scripts/LuaConfigWatch.sh`, which reloads the config through Hyprland's own
reload path. If nothing happens (no `inotify-tools`, or the watcher was killed):

```bash
hyprctl reload
```

**Check.** A Lua syntax error stops a file from loading, and Hyprland keeps the
previous config. Two ways to catch it before logging out:

```bash
luac -p "$HOME/.config/hypr/UserConfigs/user_keybinds.lua"   # syntax only
hyprctl reload && hyprctl configerrors                        # what Hyprland complained about
```

`SUPER + SHIFT + E` runs the `luac -p` check for you after the editor closes.

**See what a keybind resolves to.** `SUPER + SHIFT + K` searches the loaded
keybinds, with the description from each `bind(...)`. `hyprctl binds` prints the
raw table.

**Undo.** `UserConfigs` is preserved on upgrade, which also means nothing
overwrites a mistake. Keep a copy before large edits:

```bash
cp -r "$HOME/.config/hypr/UserConfigs" "$HOME/.config/hypr/UserConfigs.bak.$(date +%F)"
```

The files are also in the repo, so `git checkout` on a fresh clone restores the
shipped template.

**Upgrade.** `copy.sh` from the repo you already cloned updates everything
managed by the dotfiles and leaves `UserConfigs` and `UserScripts` alone. See
[`HOWTO-Upgrade-Dotfiles.md`](./HOWTO-Upgrade-Dotfiles.md).

---

## 8. Further reading

Per-file HOWTOs live in `docs/`:

| Topic                            | Document                                                                                                         |
| -------------------------------- | ---------------------------------------------------------------------------------------------------------------- |
| Keybinds                         | [`HOWTO-Change-Keybindgs.md`](./HOWTO-Change-Keybindgs.md), [`Keybinds.md`](./Keybinds.md)                       |
| Keyboard mappings                | [`HOWTO-Keyboard-Mappings.md`](./HOWTO-Keyboard-Mappings.md)                                                     |
| Settings and input               | [`HOWTO-user_settings.lua.md`](./HOWTO-user_settings.lua.md)                                                     |
| Decorations                      | [`HOWTO-user_decorations.lua.md`](./HOWTO-user_decorations.lua.md)                                               |
| Window rules                     | [`HOWTO-user_window_rules.lua.md`](./HOWTO-user_window_rules.lua.md)                                             |
| Layer rules                      | [`HOWTO-user_layer_rules.lua.md`](./HOWTO-user_layer_rules.lua.md)                                               |
| Startup apps                     | [`HOWTO-Add-Apps-To-user_startup.lua.md`](./HOWTO-Add-Apps-To-user_startup.lua.md)                               |
| Environment                      | [`HOWTO-user_env.lua.md`](./HOWTO-user_env.lua.md)                                                               |
| Defaults                         | [`HOWTO-user_defaults.lua.md`](./HOWTO-user_defaults.lua.md)                                                     |
| Monitors                         | [`HOWTO-monitors.lua.md`](./HOWTO-monitors.lua.md)                                                               |
| Display layouts                  | [`README-display-layouts.md`](../README-display-layouts.md)                                                      |
| Submaps                          | [`HOWTO-Use-Submap-template.md`](./HOWTO-Use-Submap-template.md)                                                 |
| Waybar modules and icons         | [`HOWTO-Add-New-Application-Icons-ModulesWorkspaces.md`](./HOWTO-Add-New-Application-Icons-ModulesWorkspaces.md) |
| Themes and icons                 | [`HOWTO-Override-Theme-and-Icons.md`](./HOWTO-Override-Theme-and-Icons.md)                                       |
| Upgrades                         | [`HOWTO-Upgrade-Dotfiles.md`](./HOWTO-Upgrade-Dotfiles.md)                                                       |
| Patch behaviour on `UserConfigs` | [`Patching-UserConfigs.md`](./Patching-UserConfigs.md)                                                           |
| Migrating Waybar to Hyprland     | [`HOWTO-Migrate-Waybar-To-Hypr.md`](./HOWTO-Migrate-Waybar-To-Hypr.md)                                           |

Online:

- Wiki home: <https://github.com/LinuxBeginnings/Hyprland-Dots/wiki>
- Install & update: <https://github.com/LinuxBeginnings/Hyprland-Dots/wiki/Install_&_Update>
- Keybinds: <https://github.com/LinuxBeginnings/Hyprland-Dots/wiki/Keybinds>
- Packages required: <https://github.com/LinuxBeginnings/Hyprland-Dots/wiki/Packages_Required>
- Changelogs: <https://github.com/LinuxBeginnings/Hyprland-Dots/wiki/Changelogs>
- FAQ (NVIDIA): <https://github.com/LinuxBeginnings/Hyprland-Dots/wiki/FAQ_NVIDIA>
- Hyprland's own documentation: <https://wiki.hypr.land/>
