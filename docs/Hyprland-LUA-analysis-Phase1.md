# 🧭 Hyprland → Lua Migration Analysis (Phase 1)
<span style="color:#7dd3fc">Focus: identify scripts/configs that **write Hyprland config files** and therefore must change for Lua.</span>

---

## 📌 Table of Contents
- [🎯 Scope & Assumptions](#-scope--assumptions)
- [🧩 Hyprland Config Entry Points](#-hyprland-config-entry-points)
- [✍️ Direct Hyprland Config Writers (must change)](#️-direct-hyprland-config-writers-must-change)
- [🧪 Indirect / Generated Config Writers](#-indirect--generated-config-writers)
- [🧰 Install/Upgrade Writers (copy/restore paths)](#-installupgrade-writers-copyrestore-paths)
- [📟 Runtime‑Only Files (no file writes)](#-runtime-only-files-no-file-writes)
- [📝 Notes / Follow‑ups](#-notes--follow-ups)

---

## 🎯 Scope & Assumptions
<span style="color:#fbbf24">Goal:</span> Identify **files that directly modify Hyprland config on disk** (or generate files sourced by Hyprland), because those will need updating for Lua.

<span style="color:#a3e635">Out of scope:</span> The new Lua syntax itself.

---

## 🧩 Hyprland Config Entry Points
**Primary file:** `Hyprland-Dots/config/hypr/hyprland.conf`

This file **sources**:
- `Hyprland-Dots/config/hypr/configs/*.conf`
- `Hyprland-Dots/config/hypr/UserConfigs/*.conf`
- `Hyprland-Dots/config/hypr/monitors.conf`
- `Hyprland-Dots/config/hypr/workspaces.conf`

Also:
- `Hyprland-Dots/config/hypr/UserConfigs/UserDecorations.conf` **sources**
  `~/.config/hypr/wallust/wallust-hyprland.conf`

➡️ Any script that writes these files must be updated for Lua.

---

## ✍️ Direct Hyprland Config Writers (must change)
These **write/overwrite Hyprland config files**:

### 🖥️ Monitor Profiles
- `Hyprland-Dots/config/hypr/scripts/MonitorProfiles.sh`
  **Writes:** `~/.config/hypr/monitors.conf`
  **How:** `cp` chosen profile from `Monitor_Profiles/*.conf`

### 🎞️ Animations
- `Hyprland-Dots/config/hypr/scripts/Animations.sh`
  **Writes:** `~/.config/hypr/UserConfigs/UserAnimations.conf`
  **How:** `cp` selected animation file into UserConfigs

### 🧱 Window Rules Version Switch
- `Hyprland-Dots/config/hypr/scripts/update_WindowRules.sh`
  **Writes:** `~/.config/hypr/configs/WindowRules.conf`
  **How:** backup + `cp` from `WindowRules-config-v3.conf`, then `hyprctl reload`

### 🎬 Startup Apps (wallpaper switching)
- `Hyprland-Dots/config/hypr/UserScripts/WallpaperSelect.sh`
  **Writes:** `~/.config/hypr/UserConfigs/Startup_Apps.conf`
  **How:** `sed -i` toggles `exec-once` lines and updates `$livewallpaper`

### 🗂️ UserConfig swapper
- `Hyprland-Dots/config/hypr/scripts/UserConfigsSwitcher.sh`
  **Writes:** directory move/rename
  **How:** `mv` between `UserConfigs` and `UserConfigsBak`

---

## 🧪 Indirect / Generated Config Writers
These generate **files that Hyprland sources**:

### 🎨 Wallust → Hyprland colors
- `Hyprland-Dots/config/hypr/scripts/ThemeChanger.sh`
- `Hyprland-Dots/config/hypr/scripts/WallustSwww.sh`

**Writes/overwrites:**
`~/.config/hypr/wallust/wallust-hyprland.conf`

**Used by:**
`Hyprland-Dots/config/hypr/UserConfigs/UserDecorations.conf` (sources it)

➡️ The Lua migration must either keep a compatible generated file or switch the generator target.

---

## 🧰 Install/Upgrade Writers (copy/restore paths)
These **modify Hyprland configs during install/upgrade**:

### 🔧 `copy.sh`
- Edits `Hyprland-Dots/config/hypr/configs/ENVariables.conf` (enables hyprcursor)
- Modifies `~/.config/hypr/configs/Startup_Apps.conf` (quickshell migration)
- Renames/switches `hyprlock.conf` variants (not Hyprland config, but in same dir)
- Calls restore helpers below

### 🧱 `scripts/lib_copy.sh`
Restores/copies:
- `~/.config/hypr/monitors.conf`
- `~/.config/hypr/workspaces.conf`
- `~/.config/hypr/UserConfigs/Startup_Apps.conf`
- `~/.config/hypr/UserConfigs/WindowRules.conf`
- `~/.config/hypr/UserConfigs/UserKeybinds.conf`
- Additional UserConfigs overlay logic

---

## 📟 Runtime‑Only Files (no file writes)
These **appear to be runtime-only** (no direct file writes detected; they act via `hyprctl`, process control, notifications, etc.):

### ✅ Scripts
- `Hyprland-Dots/config/hypr/scripts/AirplaneMode.sh`
- `Hyprland-Dots/config/hypr/scripts/Battery.sh`
- `Hyprland-Dots/config/hypr/scripts/BrightnessKbd.sh`
- `Hyprland-Dots/config/hypr/scripts/Brightness.sh`
- `Hyprland-Dots/config/hypr/scripts/ChangeBlur.sh`
- `Hyprland-Dots/config/hypr/scripts/ChangeLayout.sh`
- `Hyprland-Dots/config/hypr/scripts/ClipManager.sh`
- `Hyprland-Dots/config/hypr/scripts/ExternalBrightness.sh`
- `Hyprland-Dots/config/hypr/scripts/fastfetch-wrapper.sh`
- `Hyprland-Dots/config/hypr/scripts/Float-all-Windows.sh`
- `Hyprland-Dots/config/hypr/scripts/GameMode.sh`
- `Hyprland-Dots/config/hypr/scripts/Hypridle.sh`
- `Hyprland-Dots/config/hypr/scripts/KeybindsLayoutInit.sh`
- `Hyprland-Dots/config/hypr/scripts/keybinds_parser.py`
- `Hyprland-Dots/config/hypr/scripts/KeyboardLayout.sh`
- `Hyprland-Dots/config/hypr/scripts/KeyHints.sh`
- `Hyprland-Dots/config/hypr/scripts/KillActiveProcess.sh`
- `Hyprland-Dots/config/hypr/scripts/LockScreen.sh`
- `Hyprland-Dots/config/hypr/scripts/MediaCtrl.sh`
- `Hyprland-Dots/config/hypr/scripts/OverviewToggle.sh`
- `Hyprland-Dots/config/hypr/scripts/Polkit-NixOS.sh`
- `Hyprland-Dots/config/hypr/scripts/Polkit.sh`
- `Hyprland-Dots/config/hypr/scripts/PortalHyprland.sh`
- `Hyprland-Dots/config/hypr/scripts/PortalHyprlandUbuntu.sh`
- `Hyprland-Dots/config/hypr/scripts/RefreshNoWaybar.sh`
- `Hyprland-Dots/config/hypr/scripts/rofi-emacs-keybinds`
- `Hyprland-Dots/config/hypr/scripts/RofiSearch.sh`
- `Hyprland-Dots/config/hypr/scripts/Sounds.sh`
- `Hyprland-Dots/config/hypr/scripts/Toggle-Active-Window-Audio.sh`
- `Hyprland-Dots/config/hypr/scripts/UptimeNixOS.sh`
- `Hyprland-Dots/config/hypr/scripts/Volume.sh`
- `Hyprland-Dots/config/hypr/scripts/WallpaperDaemon.sh`
- `Hyprland-Dots/config/hypr/scripts/WaybarScripts.sh`
- `Hyprland-Dots/config/hypr/scripts/Wlogout.sh`

### ✅ UserScripts
- `Hyprland-Dots/config/hypr/UserScripts/00-Readme`
- `Hyprland-Dots/config/hypr/UserScripts/RofiCalc.sh`
- `Hyprland-Dots/config/hypr/UserScripts/WallpaperRandom.sh`
- `Hyprland-Dots/config/hypr/UserScripts/WeatherWrap.sh`

---

## 📝 Notes / Follow‑ups
<span style="color:#f97316">Important:</span>
Some scripts are **file writers but not Hyprland config writers** (e.g., `install-uv.sh`, `Distro_update.sh`, and the binary `dots-tui-ubuntu-2404`). They don’t touch Hyprland configs but do modify the system.

If you want an **exact “no file writes anywhere” list**, I can do a stricter pass (including temp/status files, downloads, etc.).
