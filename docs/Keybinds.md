# Hyprland Default Keybinds
Source: `config/hypr/configs/Keybinds.conf`

## Legend
- `SUPER` = `$mainMod`
- `code:10..19` = number row `1..0`
- Arrows/print/media keys are shown with their readable names

## Duplicate Audit
### Intentional stacked bind
- `ALT + Tab`
  - `cyclenext` (cycle next window)
  - `bringactivetotop` (raise newly selected/covered window)

### Potential conflicts
- None currently detected in `Keybinds.conf` (excluding intentional stacked binds).

## Launcher / App Shortcuts
- `SUPER + D` — App launcher (Rofi)
- `SUPER + Return` — Terminal
- `SUPER + SHIFT + Return` — Dropdown terminal
- `SUPER + E` — File manager
- `SUPER + B` — Browser
- `SUPER + C` — SSH menu
- `SUPER + S` — Web search
- `SUPER + CTRL + S` — Window switcher
- `SUPER + ALT + E` — Emoji menu
- `SUPER + ALT + C` — Calculator
- `SUPER + H` — Help / cheat sheet
- `SUPER + SHIFT + K` — Search keybinds helper

## Appearance / Theme / Wallpaper
- `SUPER + T` — Global theme switcher
- `SUPER + CTRL + R` — Rofi theme selector
- `SUPER + CTRL + SHIFT + R` — Modified Rofi theme selector
- `SUPER + CTRL + K` — Kitty theme selector
- `SUPER + CTRL + G` — Ghostty theme selector
- `SUPER + SHIFT + O` — Change ZSH theme
- `SUPER + W` — Select wallpaper
- `SUPER + SHIFT + W` — Wallpaper effects
- `CTRL + ALT + W` — Random wallpaper
- `SUPER + CTRL + O` — Toggle active window opacity
- `SUPER + ALT + O` — Toggle blur
- `SUPER + SHIFT + B` — Set static rainbow border

## Panels / Menus / Bar
- `SUPER + A` — Desktop overview
- `SUPER + CTRL + A` — AGS overview
- `SUPER + SHIFT + E` — Quick settings
- `SUPER + SHIFT + N` — Notification panel
- `SUPER + CTRL + ALT + B` — Toggle waybar
- `SUPER + CTRL + B` — Waybar styles menu
- `SUPER + ALT + B` — Waybar layout menu
- `SUPER + ALT + R` — Refresh bar/menus

## Session / System
- `SUPER + Q` — Close active window
- `SUPER + SHIFT + Q` — Terminate active process
- `CTRL + ALT + Delete` — Exit Hyprland
- `CTRL + ALT + L` — Lock screen
- `CTRL + ALT + P` — Power menu
- `SUPER + SHIFT + H` — Toggle active-window mute
- `SUPER + SHIFT + G` — Toggle game mode
- `SUPER + N` — Toggle night light

## Window State / Float / Fullscreen
- `SUPER + F` — Maximize window
- `SUPER + SHIFT + F` — Fullscreen
- `SUPER + Space` — Toggle floating
- `SUPER + ALT + Space` — Float all windows

## Layout Controls
### Global layout selection
- `SUPER + ALT + L` — Toggle layouts
- `SUPER + ALT + 1/2/3/4` — Dwindle / Master / Scrolling / Monocle

### Master layout
- `SUPER + I` — Add master
- `SUPER + CTRL + D` — Remove master
- `SUPER + CTRL + Return` — Swap with master

### Dwindle layout
- `SUPER + SHIFT + I` — Toggle split
- `SUPER + P` — Toggle pseudo

### Scrolling layout
- `SUPER + SHIFT + , / .` — Move column left/right
- `SUPER + ALT + , / .` — Swap column left/right
- `SUPER + R` — Cycle column width presets
- `SUPER + ALT + H` — Horizontal direction
- `SUPER + CTRL + V` — Vertical direction
- `SUPER + ALT + S` — Toggle horizontal/vertical direction

## Focus / Move / Resize
### Focus
- `SUPER + j/k` — Cycle next/previous (layout-aware)
- `SUPER + Left/Right/Up/Down` — Focus by direction

### Move windows
- `SUPER + CTRL + Left/Right/Up/Down` — Move window by direction

### Swap windows
- `SUPER + ALT + Left/Right/Up/Down` — Swap window by direction

### Resize windows
- `SUPER + SHIFT + Left/Right` — Width -/+50
- `SUPER + SHIFT + Up/Down` — Height -/+50

### Mouse drag controls
- `SUPER + mouse:272` — Move window
- `SUPER + mouse:273` — Resize window

## Grouping
- `SUPER + G` — Toggle group
- `SUPER + Tab` — Group forward
- `SUPER + SHIFT + Tab` — Group back
- `SUPER + CTRL + Tab` — Change active in group
- `SUPER + CTRL + J` — Move into group (left)
- `SUPER + CTRL + L` — Move into group (right)
- `SUPER + CTRL + H` — Move out of group

## Workspaces
### Navigation
- `SUPER + Tab` — Next workspace
- `SUPER + SHIFT + Tab` — Previous workspace
- `SUPER + mouse_down` or `SUPER + .` — Next existing workspace
- `SUPER + mouse_up` or `SUPER + ,` — Previous existing workspace

### Direct workspace jump
- `SUPER + code:10..19` — Go to workspaces `1..10`

### Move active window (follow)
- `SUPER + SHIFT + code:10..19` — Move to workspaces `1..10`
- `SUPER + SHIFT + [` / `]` — Move to prev/next workspace

### Move active window (silent)
- `SUPER + CTRL + code:10..19` — Move silently to workspaces `1..10`
- `SUPER + CTRL + [` / `]` — Move silently to prev/next workspace

### Special workspace / monitor move
- `SUPER + U` — Toggle special workspace
- `SUPER + SHIFT + U` — Move to special workspace
- `SUPER + CTRL + F9/F10/F11/F12` — Move current workspace to monitor left/right/up/down

## Overview / Alt-Tab
- `SUPER + SHIFT + Tab` — Toggle qs-hyprview
- `ALT + Tab` — Cycle next + bring active to top (intentional pair)

## Screenshots
- `SUPER + Print` — Screenshot now
- `SUPER + SHIFT + Print` — Screenshot area
- `SUPER + CTRL + Print` — Screenshot in 5s
- `SUPER + CTRL + SHIFT + Print` — Screenshot in 10s
- `ALT + Print` — Screenshot active window
- `ALT + SHIFT + S` — Hyprshot region capture
- `SUPER + SHIFT + S` — Screenshot via swappy flow

## Media / Audio / Hardware Keys
### Volume & mic
- `XF86AudioRaiseVolume` / `XF86AudioLowerVolume` — Volume up/down
- `ALT + XF86AudioRaiseVolume` / `ALT + XF86AudioLowerVolume` — Precise volume up/down
- `XF86AudioMute` — Toggle output mute
- `XF86AudioMicMute` — Toggle microphone mute

### Playback
- `XF86AudioPlayPause` — Play/pause
- `XF86AudioPause` — Pause
- `XF86AudioPlay` — Play
- `XF86AudioNext` / `XF86AudioPrev` — Next/previous track
- `XF86AudioStop` — Stop

### Power/device keys
- `XF86Sleep` — Suspend
- `XF86Rfkill` — Airplane mode toggle

## Keyboard Layout
- `Left ALT + Left SHIFT` — Switch keyboard layout globally
- `Left SHIFT + Left ALT` — Switch keyboard layout per-window
