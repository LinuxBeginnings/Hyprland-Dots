# copy.sh vs TUI Installer Parity Report (2026-03-14)

This report compares the Bash-based `copy.sh` flow (including helper scripts) against the Python/Textual TUI installer in `../Hyprland-Dots-TUI-Installer/`.

## ✅ Parity Matches

### Core Modes & Flow
- Install / Upgrade / Express workflows exist in both.
  - `copy.sh`, `scripts/copy_menu.sh`
  - TUI: `src/dots_tui/__main__.py`, `src/dots_tui/screens/menu.py`, `src/dots_tui/logic/orchestrator.py`

### Safety / Setup
- Root check (both abort if root).
- Repo update flow (stash + pull + summary).
- Logs written to `Copy-Logs/` with per-run log file.

### Hardware / OS Detection + Tweaks
- Nvidia / VM / NixOS tweaks.
  - `scripts/lib_detect.sh`
  - `src/dots_tui/logic/orchestrator.py`, `src/dots_tui/logic/system.py`

### User Prompts / Config Choices
- Keyboard layout detect + confirmation.
- Resolution selection (<1440p vs ≥1440p).
- 12h/24h clock (waybar + hyprlock edits).
- Default editor selection (nvim/vim).
- Optional app enablement: asusctl, blueman, ags, quickshell.

### Copy / Backup / Restore
- Phase1 copy w/ replace prompts: fastfetch, kitty, rofi, swaync.
- Waybar merge semantics (backup, merge configs/styles/UserModules).
- Phase2 copy (btop, cava, hypr, etc.).
- Restore user configs / scripts / hypr files (with express skip).
- Duplicate UserConfigs cleanup.

### Wallpapers
- Base wallpaper copy to `~/Pictures/wallpapers`.
- Optional 1GB Wallpaper-Bank download (skipped in express).

### Finalization
- chmod scripts, waybar symlinks, cleanup backups, wallust init.

## ⚠️ Parity Gaps (Missing or Divergent Behavior)

### 1) waybar-weather install + config handling
`copy.sh` does **two things** the TUI does not:
- **Installs waybar-weather binary**
  - `scripts/lib_apps.sh`: `install_waybar_weather()`
  - `copy.sh`: calls it on non-NixOS, or warns on NixOS.
- **Copies waybar-weather config + prompts for units**
  - `copy.sh`: block near `WAYBAR_WEATHER_SRC / DEST` (install/upgrade/express logic + Fahrenheit prompt).

✅ **TUI currently has no references to waybar-weather**.

---

### 2) KeybindsLayoutInit always enabled
`copy.sh` always ensures `exec-once = $scriptsDir/KeybindsLayoutInit.sh` via `ensure_keybinds_init` (called unconditionally).

TUI only adds it if **one of** (asus / blueman / ags / quickshell) is enabled:
- `src/dots_tui/logic/orchestrator.py` → `_apply_user_choices`

So if user disables all optional apps, TUI skips it while `copy.sh` still adds it.

---

### 3) Waybar symlink enforcement
`copy.sh` forces `~/.config/waybar/config` and `style.css` to be symlinks even if they are regular files.

TUI only replaces them **if missing or already a symlink**:
- `src/dots_tui/logic/orchestrator.py` → `_finalize_post_copy`

So regular files won’t be converted in TUI.

---

### 4) Express mode + SDDM 12h edits
`copy.sh` explicitly **skips SDDM 12h edits** in express mode to avoid sudo prompts.

TUI still attempts SDDM edits if user chooses 12h:
- `src/dots_tui/logic/orchestrator.py` → `_finalize_post_copy` (SDDM clock edits run whenever `clock_24h` is false).

---

### 5) Menu behavior / CLI flags
- `copy.sh` supports `--tty` to force non-whiptail menu.
- TUI has no equivalent.

---

## ✅ TUI-only Extras (Not in copy.sh)
- Dry-run / plan mode (`--dry-run`).
- Download repo (clone flow).
- Path safety guard (prevents deletes outside `$HOME`).
- Default wallpaper initialization if `.wallpaper_current` missing.

---

## Summary
The TUI installer is **mostly aligned** with `copy.sh`, but **not full parity** due to:
1) Missing `waybar-weather` binary + config + units prompt
2) KeybindsLayoutInit not always added
3) Waybar symlink enforcement behavior mismatch
4) Express-mode SDDM 12h edits mismatch
5) Minor CLI/menu flag mismatch
