# Hyprland Default Keybinds
Source: `config/hypr/lua/keybinds.lua`

## Legend
- `SUPER` = `$mainMod` (Super / Windows key)
- `code:10..19` = number row `1..0`
- Arrows, function keys, mouse triggers, and media keys are shown with their readable names

## Duplicate / Intentional Stacked Binds Audit
- `ALT + Tab`
  - `cyclenext` (cycles window focus via `LuaCycleWindow.sh next`)
- `SUPER + Tab` / `SUPER + SHIFT + Tab`
  - Group active cycle (`changegroupactive f/b`) and workspace cycle (`workspace e+1/e-1`)

## Launcher / App Shortcuts
- `SUPER + D` — App launcher (Rofi drun, filebrowser, run, window)
- `SUPER + Return` — Terminal (`LaunchTerminal.sh '$term'`)
- `SUPER + SHIFT + Return` — Dropdown terminal (`Dropterminal.sh kitty`)
- `SUPER + E` — File manager (`LaunchFileManager.sh '$files' '$term'`)
- `SUPER + B` — Default browser (`xdg-open "https://"`)
- `SUPER + C` — SSH session manager (`rofi-ssh-menu.sh`)
- `SUPER + S` — Web search (`RofiSearch.sh`)
- `SUPER + CTRL + S` — Window switcher (`rofi -show window`)
- `SUPER + ALT + E` — Emoji menu (`RofiEmoji.sh`)
- `SUPER + ALT + C` — Calculator (`RofiCalc.sh`)
- `SUPER + SHIFT + M` — Online music & stations (`RofiBeats.sh`)
- `SUPER + H` — Help / cheat sheet (`KeyHints.sh`)
- `SUPER + SHIFT + K` — Search keybinds helper (`KeyBinds.sh`)

## Appearance / Theme / Wallpaper / Zoom
- `SUPER + T` — Global theme switcher using Wallust (`ThemeChanger.sh`)
- `SUPER + CTRL + R` — Rofi theme selector (`RofiThemeSelector.sh`)
- `SUPER + CTRL + SHIFT + R` — Modified Rofi theme selector (`RofiThemeSelector-modified.sh`)
- `SUPER + CTRL + K` — Kitty theme selector (`Kitty_themes.sh`)
- `SUPER + CTRL + G` — Ghostty theme selector (`Ghostty_themes.sh`)
- `SUPER + SHIFT + O` — Change Oh-My-Zsh theme (`ZshChangeTheme.sh`)
- `SUPER + SHIFT + A` — Animations menu (`Animations.sh`)
- `SUPER + W` — Select wallpaper (`WallpaperSelect.sh`)
- `SUPER + SHIFT + W` — Wallpaper effects (`WallpaperEffects.sh`)
- `CTRL + ALT + W` — Random wallpaper (`WallpaperRandom.sh`)
- `SUPER + CTRL + O` — Toggle active window opacity (`setprop active opaque toggle`)
- `SUPER + ALT + O` — Toggle blur (`ChangeBlur.sh`)
- `SUPER + SHIFT + B` — Set static rainbow border (`RainbowBorders-low-cpu.sh --run-once`)
- `SUPER + ALT + mouse_down` — Zoom in (`cursor:zoom_factor * 2.0`)
- `SUPER + ALT + mouse_up` — Zoom out (`cursor:zoom_factor / 2.0`)

## Panels / Menus / Bar
- `SUPER + A` — Desktop overview (`OverviewToggle.sh`)
- `SUPER + SHIFT + E` — Quick settings menu (`Kool_Quick_Settings.sh`)
- `SUPER + SHIFT + N` — Notification panel (`swaync-client -t -sw`)
- `SUPER + CTRL + ALT + B` — Toggle Waybar on/off (`pkill -SIGUSR1 waybar`)
- `SUPER + CTRL + B` — Waybar styles menu (`WaybarStyles.sh`)
- `SUPER + ALT + B` — Waybar layout menu (`WaybarLayout.sh`)
- `SUPER + ALT + R` — Refresh bar and menus (`Refresh.sh`)

## Session / System Controls
- `SUPER + Q` — Close active window (`killactive`)
- `SUPER + SHIFT + Q` — Terminate active process (`KillActiveProcess.sh`)
- `CTRL + ALT + Delete` — Exit Hyprland / logout menu (`Logout.sh`)
- `CTRL + ALT + L` — Lock screen (`LockScreen.sh`)
- `CTRL + ALT + P` — Power menu (`Wlogout.sh`)
- `SUPER + SHIFT + H` — Toggle mute/unmute for active window (`Toggle-Active-Window-Audio.sh`)
- `SUPER + SHIFT + G` — Toggle game mode (`GameMode.sh`)
- `SUPER + N` — Toggle night light (`Hyprsunset.sh toggle`)

## Window State / Float / Fullscreen
- `SUPER + F` — Maximize window (`fullscreen 1`)
- `SUPER + SHIFT + F` — Fullscreen (`fullscreen 0`)
- `SUPER + Space` — Toggle floating current window (`togglefloating`)
- `SUPER + ALT + Space` — Float all windows (`Float-all-Windows.sh`)
- `SUPER + CTRL + Space` — Float all windows same size (`float.all.samesize.lua`)

## Layout Controls
### Global layout selection
- `SUPER + ALT + L` — Toggle layouts (`ChangeLayout.sh toggle`)
- `SUPER + ALT + 1` — Dwindle layout (`ChangeLayout.sh dwindle`)
- `SUPER + ALT + 2` — Master layout (`ChangeLayout.sh master`)
- `SUPER + ALT + 3` — Scrolling layout (`ChangeLayout.sh scrolling`)
- `SUPER + ALT + 4` — Monocle layout (`ChangeLayout.sh monocle`)

### Master layout
- `SUPER + I` — Add master (`layoutmsg addmaster`)
- `SUPER + CTRL + D` — Remove master (`layoutmsg removemaster`)
- `SUPER + CTRL + Return` — Swap with master (`layoutmsg swapwithmaster`)

### Dwindle layout
- `SUPER + SHIFT + I` — Toggle split (`layoutmsg togglesplit`)
- `SUPER + P` — Toggle pseudo (`pseudo`)
- `SUPER + M` — Set split ratio 0.3 (`splitratio 0.3`)

### Scrolling layout
- `SUPER + SHIFT + period` — Move to right column (`layoutmsg move +col`)
- `SUPER + SHIFT + comma` — Move to left column (`layoutmsg move -col`)
- `SUPER + ALT + comma` — Swap columns left (`layoutmsg swapcol l`)
- `SUPER + ALT + period` — Swap columns right (`layoutmsg swapcol r`)
- `SUPER + R` — Cycle column width preset (`0.25`, `0.33`, `0.5`, `0.66`, `0.75`, `1.0`)
- `SUPER + ALT + H` — Horizontal scroll direction right (`scrolling:direction right`)
- `SUPER + CTRL + V` — Vertical scroll direction down (`scrolling:direction down`)
- `SUPER + ALT + S` — Toggle scrolling direction (Horizontal / Vertical)

## Focus / Move / Resize / Swap
### Focus
- `SUPER + j` — Cycle next window (layout-aware via `LayoutKeybindDispatch.sh cycle-next`)
- `SUPER + k` — Cycle previous window (layout-aware via `LayoutKeybindDispatch.sh cycle-prev`)
- `SUPER + Left/Right/Up/Down` — Focus window by direction (layout-aware via `LayoutKeybindDispatch.sh focus-*`)
- `ALT + Tab` — Cycle next window (`LuaCycleWindow.sh next`)

### Move windows
- `SUPER + CTRL + Left/Right/Up/Down` — Move window by direction (`movewindow l/r/u/d`)

### Swap windows
- `SUPER + ALT + Left/Right/Up/Down` — Swap window by direction (`LuaSwapWindow.sh l/r/u/d`)

### Resize windows
- `SUPER + SHIFT + Left` — Width -50 (`resizeactive -50 0`)
- `SUPER + SHIFT + Right` — Width +50 (`resizeactive 50 0`)
- `SUPER + SHIFT + Up` — Height -50 (`resizeactive 0 -50`)
- `SUPER + SHIFT + Down` — Height +50 (`resizeactive 0 50`)

### Mouse drag controls
- `SUPER + mouse:272` (Left click drag) — Move window (`movewindow`)
- `SUPER + mouse:273` (Right click drag) — Resize window (`resizewindow`)

## Grouping
- `SUPER + G` — Toggle window grouping (`togglegroup`)
- `SUPER + Tab` — Cycle group window forward (`changegroupactive f`)
- `SUPER + SHIFT + Tab` — Cycle group window back (`changegroupactive b`)
- `SUPER + CTRL + J` — Move left into group (`moveintogroup l`)
- `SUPER + CTRL + H` — Move active window out of group (`moveoutofgroup`)

## Workspaces
### Navigation
- `SUPER + Tab` — Next workspace (`workspace e+1`)
- `SUPER + SHIFT + Tab` — Previous workspace (`workspace e-1`)
- `SUPER + mouse_down` or `SUPER + period` — Next workspace (`workspace e+1`)
- `SUPER + mouse_up` or `SUPER + comma` — Previous workspace (`workspace e-1`)

### Direct workspace jump
- `SUPER + code:10..19` — Go to workspaces `1..10`

### Move active window (follow)
- `SUPER + SHIFT + code:10..19` — Move to workspaces `1..10`
- `SUPER + SHIFT + [` — Move to previous workspace (`movetoworkspace -1`)
- `SUPER + SHIFT + ]` — Move to next workspace (`movetoworkspace +1`)

### Move active window (silent)
- `SUPER + CTRL + code:10..19` — Move silently to workspaces `1..10` (`movetoworkspacesilent 1..10`)
- `SUPER + CTRL + [` — Move silently to previous workspace (`movetoworkspacesilent -1`)
- `SUPER + CTRL + ]` — Move silently to next workspace (`movetoworkspacesilent +1`)

### Special workspace & monitor move
- `SUPER + U` — Toggle special workspace (`togglespecialworkspace`)
- `SUPER + SHIFT + U` — Move to special workspace (`movetoworkspace special`)
- `SUPER + CTRL + F9` — Move current workspace to left monitor (`movecurrentworkspacetomonitor l`)
- `SUPER + CTRL + F10` — Move current workspace to right monitor (`movecurrentworkspacetomonitor r`)
- `SUPER + CTRL + F11` — Move current workspace to upper monitor (`movecurrentworkspacetomonitor u`)
- `SUPER + CTRL + F12` — Move current workspace to lower monitor (`movecurrentworkspacetomonitor d`)

## Overview / Hyprview
- `SUPER + CTRL + Tab` — Hyprview Toggle (`toggle-qs-hyprview.sh smartgrid`)

## Screenshots
- `SUPER + Print` — Screenshot now (`ScreenShot.sh --now`)
- `SUPER + SHIFT + Print` — Screenshot area (`ScreenShot.sh --area`)
- `SUPER + CTRL + Print` — Screenshot in 5s (`ScreenShot.sh --in5`)
- `SUPER + CTRL + SHIFT + Print` — Screenshot in 10s (`ScreenShot.sh --in10`)
- `ALT + Print` — Screenshot active window (`ScreenShot.sh --active`)
- `ALT + SHIFT + S` — Hyprshot region capture to `~/Pictures/Screenshots`
- `SUPER + SHIFT + S` — Screenshot via Swappy editor (`ScreenShot.sh --swappy`)

## Media / Audio / Hardware Keys
### Volume & microphone
- `XF86AudioRaiseVolume` / `XF86AudioLowerVolume` — Volume up / down (`Volume.sh --inc` / `--dec`)
- `ALT + XF86AudioRaiseVolume` / `ALT + XF86AudioLowerVolume` — Precise volume up / down (`Volume.sh --inc-precise` / `--dec-precise`)
- `XF86AudioMute` — Toggle output mute (`Volume.sh --toggle`)
- `XF86AudioMicMute` — Toggle microphone mute (`Volume.sh --toggle-mic`)

### Playback controls
- `XF86AudioPlayPause` / `XF86AudioPause` / `XF86AudioPlay` — Play / pause (`MediaCtrl.sh --pause`)
- `XF86AudioNext` — Next track (`MediaCtrl.sh --nxt`)
- `XF86AudioPrev` — Previous track (`MediaCtrl.sh --prv`)
- `XF86AudioStop` — Stop playback (`MediaCtrl.sh --stop`)

### Power & device keys
- `XF86Sleep` — Suspend (`systemctl suspend`)
- `XF86Rfkill` — Airplane mode toggle (`AirplaneMode.sh`)

## Keyboard Layout Switching
- `Left ALT + Left SHIFT` (`ALT_L + SHIFT_L`) — Switch keyboard layout globally (`KeyboardLayout.sh switch`)
- `Left SHIFT + Left ALT` (`SHIFT_L + ALT_L`) — Switch keyboard layout per-window (`Tak0-Per-Window-Switch.sh`)
