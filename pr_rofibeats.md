Hey everyone! I've been using RofiBeats heavily and noticed a few areas where we could really level up the experience to make it feel like a premium, native music app. I spent some time refactoring the engine to fix some underlying bugs and add a few highly-requested "Quality of Life" features.

Here is a breakdown of what this PR brings to the table:

### 1. Seamless Track Transitions
Previously, the script relied on an IPC socket to control `mpv`. On some systems, this socket wouldn't create properly, leading to "Cannot skip" errors. Furthermore, skipping tracks meant killing the player and restarting it, causing a jarring gap in audio and annoying "Playback stopped" notification spam.
**The Fix:** I've rewritten the core control logic to use standard `playerctl` and MPRIS (`mpv-mpris`). Now, when a track changes, the new URL is seamlessly loaded into the already-running `mpv` instance. The result is completely gapless audio transitions!

### 2. Zero-Second "Auto-Radio" (Background Pre-fetching)
The YouTube Auto-Radio feature is awesome, but clicking "Next" used to mean waiting 15-30 seconds for `yt-dlp` to calculate the next mix.
**The Fix:** Now, the exact second a song starts playing, the engine silently pre-fetches the *next* related video in the background and caches it. When you press Next, the new song starts instantly with zero delay.

### 3. Visual Overhaul (Real Thumbnails!)
A music player needs album art. I've updated the YouTube search function to fetch high-quality video thumbnails.
- The Rofi menu now uses a clean **5x2 grid layout**, displaying the actual thumbnails next to the song titles.
- Your desktop "Now Playing" notifications (`MediaCtrl.sh`) will also display the downloaded YouTube thumbnail instead of a generic music note.

### 4. Global Hardware Media Key Support
Because the script now properly utilizes MPRIS, your physical keyboard media keys (Next, Previous, Play/Pause) and Waybar clicks will flawlessly control RofiBeats. Even better, pressing the physical "Next" key on your keyboard will actively trigger the smart YouTube Auto-Radio logic to find a related song, rather than just failing.

I've tested this extensively and it makes the whole media experience feel incredibly snappy and professional out of the box. Let me know what you think!