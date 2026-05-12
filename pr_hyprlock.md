Hey everyone! 

I noticed there wasn't a quick way to change the lock screen wallpaper directly from the main keybinds, so I promoted the hidden `HyprlockWallpaperSelect.sh` script to be an official keybind.

### 1. Official Keybind Promotion
- `SUPER + SHIFT + L` now launches the Hyprlock Wallpaper Selector natively via `Keybinds.conf`.
- Removed the redundant, clunky bind from `UserKeybinds.conf` since it is now a core feature.

### 2. Smart Video-to-Image Fallback
**To clarify: This is NOT a video wallpaper engine for Hyprlock.** Hyprlock does not natively support MP4 backgrounds. 
However, if a user accidentally selects a video file from the wallpaper menu, it currently breaks the lock screen (showing a black screen or failing to load). I updated `HyprlockWallpaperSelect.sh` so that if a user selects a video file (MP4, MKV, WebM), the script will automatically extract a high-quality static frame (using `ffmpeg`) and set *that* static image as the Hyprlock background. This prevents Hyprlock from breaking while still letting the user select files that match their aesthetic!

### 3. Syntax Fixes
Fixed a few minor syntax errors in the default `hyprlock.conf` for the latest v0.9.3 release (e.g., removing the deprecated `grace` option from the general block).

*Note: Re-submitted against the development branch as requested.*