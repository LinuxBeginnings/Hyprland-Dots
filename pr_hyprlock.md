Hey everyone! 

I've been working on getting video wallpapers to work nicely with the lock screen. Since Hyprlock doesn't natively support playing `.mp4` files in the background block (it often crashes or shows a black screen), I put together a smart fallback mechanism for the Wallpaper Selector.

Here's what this PR does:

### 1. Smart Video-to-Image Fallback
I updated `HyprlockWallpaperSelect.sh`. Now, if a user selects a video file (MP4, MKV, WebM, etc.) for their lock screen, the script will automatically extract a high-quality frame from the video (using `ffmpeg`) and set *that* image as the Hyprlock background. This prevents the lock screen from breaking while still matching the user's aesthetic!

### 2. Official Keybind Promotion
To make this easier to access, I promoted the Hyprlock Wallpaper Selector from a hidden script to an official keybind.
- `SUPER + SHIFT + L` now launches the Hyprlock Wallpaper Selector natively via `Keybinds.conf`.
- Removed the redundant, clunky bind from `UserKeybinds.conf`.

### 3. Syntax Fixes
Fixed a few minor syntax errors in the default `hyprlock.conf` for the latest v0.9.3 release (e.g., removing the deprecated `grace` option from the general block).

Tested and works perfectly! Let me know if you need any adjustments.