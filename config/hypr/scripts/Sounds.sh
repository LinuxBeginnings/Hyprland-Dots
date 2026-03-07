#!/usr/bin/env bash
# ==================================================
#  KoolDots (2026)
#  Project URL: https://github.com/LinuxBeginnings
#  License: GNU GPLv3
#  SPDX-License-Identifier: GPL-3.0-or-later
# ==================================================
# This script is used to play system sounds.
# Script is used by Volume.Sh and ScreenShots.sh 

theme="freedesktop" # Set the theme for the system sounds.
mute=false          # Set to true to mute the system sounds.
directSoundDir="$HOME/.config/hypr/sounds"

# Mute individual sounds here.
muteScreenshots=false
muteVolume=false

# Exit if the system sounds are muted.
if [[ "$mute" = true ]]; then
    exit 0
fi

# Choose the sound to play.
if [[ "$1" == "--screenshot" ]]; then
    if [[ "$muteScreenshots" = true ]]; then
        exit 0
    fi
    directSound="$directSoundDir/screenshot.ogg"
    soundoption="screen-capture.*"
elif [[ "$1" == "--volume" ]]; then
    if [[ "$muteVolume" = true ]]; then
        exit 0
    fi
    directSound="$directSoundDir/volume.ogg"
    soundoption="audio-volume-change.*"
elif [[ "$1" == "--error" ]]; then
    if [[ "$muteScreenshots" = true ]]; then
        exit 0
    fi
    directSound="$directSoundDir/error.ogg"
    soundoption="dialog-error.*"
else
    echo -e "Available sounds: --screenshot, --volume, --error"
    exit 0
fi

# Set the directory defaults for system sounds.
if [ -d "/run/current-system/sw/share/sounds" ]; then
    systemDIR="/run/current-system/sw/share/sounds" # NixOS
else
    systemDIR="/usr/share/sounds"
fi
userDIR="$HOME/.local/share/sounds"
defaultTheme="freedesktop"

# Prefer the user's theme, but use the system's if it doesn't exist.
sDIR="$systemDIR/$defaultTheme"
if [ -d "$userDIR/$theme" ]; then
    sDIR="$userDIR/$theme"
elif [ -d "$systemDIR/$theme" ]; then
    sDIR="$systemDIR/$theme"
fi

# Get the theme that it inherits.
iTheme=$(cat "$sDIR/index.theme" | grep -i "inherits" | cut -d "=" -f 2)
iDIR="$sDIR/../$iTheme"

# Helper to play in the background (fast return).
play_sound() {
    if command -v paplay >/dev/null 2>&1; then
        paplay "$1" >/dev/null 2>&1 &
        exit 0
    fi
    if command -v pw-play >/dev/null 2>&1; then
        pw-play "$1" >/dev/null 2>&1 &
        exit 0
    fi
    if command -v aplay >/dev/null 2>&1; then
        aplay "$1" >/dev/null 2>&1 &
        exit 0
    fi
    echo "Error: No suitable audio player found. Install paplay (pulseaudio-utils) or PipeWire/ALSA tools."
    exit 1
}

# If a direct sound file exists, play it immediately to avoid lookup delay.
if [[ -n "$directSound" && -f "$directSound" ]]; then
    play_sound "$directSound"
fi

# Find the sound file and play it.
sound_file=$(find -L $sDIR/stereo -name "$soundoption" -print -quit)
if ! test -f "$sound_file"; then
    sound_file=$(find -L $iDIR/stereo -name "$soundoption" -print -quit)
    if ! test -f "$sound_file"; then
        sound_file=$(find -L $userDIR/$defaultTheme/stereo -name "$soundoption" -print -quit)
        if ! test -f "$sound_file"; then
            sound_file=$(find -L $systemDIR/$defaultTheme/stereo -name "$soundoption" -print -quit)
            if ! test -f "$sound_file"; then
                echo "Error: Sound file not found."
                exit 1
            fi
        fi
    fi
fi
# Play the sound (background for quick return).
play_sound "$sound_file"
