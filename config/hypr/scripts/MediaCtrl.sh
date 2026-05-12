#!/bin/bash
# /* ---- 💫 https://github.com/JaKooLit 💫 ---- */  ##
# Playerctl

music_icon="$HOME/.config/swaync/icons/music.png"

# RofiBeats socket (deprecated, using pgrep instead for stability)
rofi_beats_script="$HOME/.config/hypr/UserScripts/RofiBeats.sh"

is_rofi_beats() {
  pgrep -x "mpv" >/dev/null
  return $?
}

# Play the next track
play_next() {
  if is_rofi_beats; then
    $rofi_beats_script --next
  else
    playerctl next
    show_music_notification
  fi
}

# Play the previous track
play_previous() {
  if is_rofi_beats; then
    $rofi_beats_script --prev
  else
    playerctl previous
    show_music_notification
  fi
}

# Toggle play/pause
toggle_play_pause() {
  if is_rofi_beats; then
    $rofi_beats_script --play-pause
  else
    playerctl play-pause
    sleep 0.1
    show_music_notification
  fi
}

# Stop playback
stop_playback() {
  if is_rofi_beats; then
    $rofi_beats_script --stop
  else
    playerctl stop
    notify-send -e -u low -i $music_icon " Playback:" " Stopped"
  fi
}

# Display notification with song information
show_music_notification() {
  status=$(playerctl status)
  if [[ "$status" == "Playing" ]]; then
    song_title=$(playerctl metadata title)
    song_artist=$(playerctl metadata artist)
    
    # Try to use RofiBeats cached thumbnail
    thumb_path="$HOME/.cache/rofi-beats/.last_thumb"
    icon="$music_icon"
    [[ -f "$thumb_path" ]] && icon=$(cat "$thumb_path")
    
    notify-send -e -u low -i "$icon" "Now Playing:" "$song_title by $song_artist"
  elif [[ "$status" == "Paused" ]]; then
    notify-send -e -u low -i $music_icon " Playback:" " Paused"
  fi
}

# Get media control action from command line argument
case "$1" in
"--nxt")
  play_next
  ;;
"--prv")
  play_previous
  ;;
"--pause")
  toggle_play_pause
  ;;
"--stop")
  stop_playback
  ;;
*)
  echo "Usage: $0 [--nxt|--prv|--pause|--stop]"
  exit 1
  ;;
esac
