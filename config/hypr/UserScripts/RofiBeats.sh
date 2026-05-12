#!/bin/bash
# ────────────────────────────────────────────────────────────────────
# 🎵 RofiBEATS — Advanced Music Player (v3.6.0)
# ────────────────────────────────────────────────────────────────────

set -o pipefail

# ═══════════════════════════════════════════════════════════════════
# 🔧 CONFIGURATION SECTION
# ═══════════════════════════════════════════════════════════════════

readonly mDIR="${HOME}/Music"
readonly iDIR="${HOME}/.config/swaync/icons"
readonly rofi_theme="${HOME}/.config/rofi/config-rofi-Beats.rasi"
readonly rofi_theme_menu="${HOME}/.config/rofi/config-rofi-Beats-menu.rasi"
readonly cache_dir="${HOME}/.cache/rofi-beats"
readonly history_file="${cache_dir}/youtube_history.txt"
readonly favorites_file="${cache_dir}/favorites.txt"
readonly queue_file="${cache_dir}/queue.txt"
readonly downloads_dir="${mDIR}/Downloaded"
readonly video_downloads_dir="${mDIR}/Videos"
readonly config_file="${cache_dir}/config.conf"
readonly mpv_socket="/tmp/mpv-rofi-beats.sock"
readonly pid_file="${cache_dir}/rofi-beats.pid"
readonly log_file="${cache_dir}/rofi-beats.log"
readonly download_log="${cache_dir}/download_log.txt"
readonly cache_url_file="${cache_dir}/.last_url"
readonly cache_title_file="${cache_dir}/.last_title"
readonly next_url_file="${cache_dir}/.next_url"
readonly thumb_cache="${cache_dir}/thumbnails"

mkdir -p "$cache_dir" "$downloads_dir" "$video_downloads_dir" "$thumb_cache" 2>/dev/null || true

readonly SCRIPT_VERSION="3.6.0"
readonly MAX_HISTORY_ENTRIES=150
readonly MAX_QUEUE_SIZE=500
readonly YT_DLP_TIMEOUT=30
readonly IPC_TIMEOUT=3
readonly NOTIFICATION_DURATION=4
readonly SOCKET_WAIT_TIME=10
readonly MAX_RETRIES=3

# ─── Browser Detection ───────────────────────────────────────────────
detect_browser() {
  if command -v brave &>/dev/null; then
    echo "brave"
  elif command -v chromium &>/dev/null; then
    echo "chromium"
  elif command -v google-chrome &>/dev/null; then
    echo "google-chrome"
  elif command -v firefox &>/dev/null; then
    echo "firefox"
  else
    echo ""
  fi
}

readonly DEFAULT_BROWSER=$(detect_browser)

# ─── Global Variables ────────────────────────────────────────────────
AUTOPLAY=1
SHUFFLE_ENABLED=0
REPEAT_MODE="none"
VOLUME_LEVEL=100
CURRENT_PLAYLIST=()
DOWNLOAD_QUALITY="best"
LAST_SELECTED_URL=""
LAST_SELECTED_TITLE=""
MPRIS_PLUGIN="/usr/lib/mpv-mpris/mpris.so"
[[ ! -f "$MPRIS_PLUGIN" ]] && MPRIS_PLUGIN="/etc/mpv/scripts/mpris.so"

# Helper to run mpv with correct parameters
run_mpv() {
  local url="$1"
  shift
  local extra_args=("$@")
  
  local mpris_arg=""
  [[ -f "$MPRIS_PLUGIN" ]] && mpris_arg="--script=$MPRIS_PLUGIN"
  
  mpv --profile=audio --vid=no \
      $mpris_arg \
      --input-ipc-server="$mpv_socket" \
      "${extra_args[@]}" \
      "$url" >/dev/null 2>&1 &
}

# Cache last selected URL
cache_selection() {
  local title="$1"
  local url="$2"
  local thumb="$3"
  echo "$url" > "$cache_url_file"
  echo "$title" > "$cache_title_file"
  [[ -n "$thumb" ]] && echo "$thumb" > "${cache_dir}/.last_thumb"
  LAST_SELECTED_URL="$url"
  LAST_SELECTED_TITLE="$title"
  log_debug "Cached: $title | $url"
  
  # Clean up previous pre-fetch
  rm -f "$next_url_file" 2>/dev/null || true
  
  # Pre-fetch next related video in background so 'Next' is instant
  if [[ $AUTOPLAY -eq 1 ]] && is_youtube_url "$url"; then
    (
      local next=$(get_related_video "$url")
      [[ -n "$next" ]] && echo "$next" > "$next_url_file"
    ) &
  fi
}

# Load cached URL
load_cached_url() {
  if [[ -f "$cache_url_file" ]]; then
    LAST_SELECTED_URL=$(cat "$cache_url_file" 2>/dev/null)
    LAST_SELECTED_TITLE=$(cat "$cache_title_file" 2>/dev/null)
  fi
}

# ═══════════════════════════════════════════════════════════════════
# 🎵 ONLINE STATIONS ARRAY
# ═══════════════════════════════════════════════════════════════════

declare -A online_music=(
 ["FM - Easy Rock 96.3 📻🎶"]="https://radio-stations-philippines.com/easy-rock"
  ["FM - Easy Rock - Baguio 91.9 📻🎶"]="https://radio-stations-philippines.com/easy-rock-baguio"
  ["FM - Love Radio 90.5 📻🎶"]="https://radio-stations-philippines.com/pinoy-love-radio"
  ["FM - WRock - CEBU 96.3 📻🎶"]="https://onlineradio.ph/126-96-3-wrock.html"
  ["FM - Fresh Philippines 📻🎶"]="https://onlineradio.ph/553-fresh-fm.html"
  ["Radio - Lofi Girl 🎧🎶"]="https://play.streamafrica.net/lofiradio"
  ["Radio - Chillhop 🎧🎶"]="http://stream.zeno.fm/fyn8eh3h5f8uv"
  ["Radio - Ibiza Global 🎧🎶"]="https://filtermusic.net/ibiza-global"
  ["Radio - Metal Music 🎧🎶"]="https://tunein.com/radio/mETaLmuSicRaDio-s119867/"
  ["YT - Wish 107.5 YT Pinoy HipHop 📻🎶"]="https://youtube.com/playlist?list=PLkrzfEDjeYJnmgMYwCKid4XIFqUKBVWEs&si=vahW_noh4UDJ5d37"
  ["YT - Youtube Top 100 Songs Global 📹🎶"]="https://youtube.com/playlist?list=PL4fGSI1pDJn6puJdseH2Rt9sMvt9E2M4i&si=5jsyfqcoUXBCSLeu"
  ["YT - Wish 107.5 YT Wishclusives 📹🎶"]="https://youtube.com/playlist?list=PLkrzfEDjeYJn5B22H9HOWP3Kxxs-DkPSM&si=d_Ld2OKhGvpH48WO"
  ["YT - Relaxing Piano Music 🎹🎶"]="https://youtu.be/6H7hXzjFoVU?si=nZTPREC9lnK1JJUG"
  ["YT - Youtube Remix 📹🎶"]="https://youtube.com/playlist?list=PLeqTkIUlrZXlSNn3tcXAa-zbo95j0iN-0"
  ["YT - Korean Drama OST 📹🎶"]="https://youtube.com/playlist?list=PLUge_o9AIFp4HuA-A3e3ZqENh63LuRRlQ"
  ["YT - lofi hip hop radio beats 📹🎶"]="https://www.youtube.com/live/jfKfPfyJRdk?si=PnJIA9ErQIAw6-qd"
  ["YT - BollyWood 90s 📹🎶"]="https://zeno.fm/radio/retro-bollywood-90s/"
  ["YT - Relaxing Piano Jazz Music 🎹🎶"]="https://youtu.be/85UEqRat6E4?si=jXQL1Yp2VP_G6NSn"
  ["YT - Phunks 🎹🎶"]="https://youtu.be/rKKLKzb5Ld4?si=fxDXp30U8J_zGnkZ"
  ["YT - Unnakul Naane🎶"]="https://youtu.be/661K4XN_egs?si=RCnfaGTCqNiXCi7r"
  ["FM - Tamil Mirchi 98.3 📻🎶"]="http://radios.crabdance.com:8002/1"
  ["FM - Suryan 93.5 📻🎶"]="http://radios.crabdance.com:8002/2"
  ["FM - Hello 106.4 📻🎶"]="http://radios.crabdance.com:8002/3"
  ["FM - Shoutout 📻🎶"]="https://orf-live.ors-shoutcast.at/oe3-q2a"
  ["FM - Mirchi 📻🎶"]="https://listen.openstream.co/4603/audio"
  ["FM - Md.Rafi 📻🎶"]="https://stream.zeno.fm/2xx62x8ztm0uv"
  ["FM - Ms Lata 💖📻🎶"]="https://stream.zeno.fm/87xam8pf7tzuv"
  ["FM - Mr.Kishore Sir 📻🎶"]="https://stream.zeno.fm/0ghtfp8ztm0uv"
  ["FM - Ishq 99.9 📻🎶"]="https://drive.uber.radio/uber/bollywoodlove/icecast.audio"
  ["FM - Radio City 📻🎶"]="https://stream.zeno.fm/pxc55r5uyc9uv"
  ["FM - Ghazal City 📻🎶"]="https://stream.zeno.fm/yo0kzyzedittv"
  ["Arijit Sir 🎤🎶"]="https://stream.zeno.fm/wn6muavgfr2tv"
  ["Today's Hit 🔥🎧"]="https://ice1.streeemer.com:8030/radio.aac"
  ["Tamil 100 🎵💯"]="https://stream.zeno.fm/ex1yqu2gsh1tv"
  ["Bhojpuriya 💃🎶"]="https://stream.zeno.fm/zqyhigwwo5mvv"
  ["Radio Vrishti 🌧️📻"]="https://stream.zeno.fm/un3qjmd4stbtv"
  ["Mixify Eng 🇬🇧🎶"]="https://server.mixify.in/listen/english/radio.mp3"
  ["Kiss Fm 💋📻"]="https://srv01.onlineradio.voaplus.com/kissfm"
["YT - Best Hindi Songs 2025 🎶"]="https://www.youtube.com/playlist?list=PLRZlMhcYkA2FYuTGWiVTkSz18o2pK8Hv4"
["YT - Latest Hindi Songs 2025 🎶"]="https://www.youtube.com/playlist?list=PL3oW2tjiIxvTSdJ4zqjL9dijeZ0LjcuGS"
["YT - New Hindi Hits 2025 🎶"]="https://www.youtube.com/playlist?list=PLw-VjHDlEOgvh3fIZ8VSWWE09eYGO8uFI"

["YT - Top Tamil Hits 2025 🎶"]="https://www.youtube.com/playlist?list=PLdPQQOxV3l0_11bBrgSX5CCb0YtcBGhhA"
["YT - Latest Tamil Hits 2025 🎶"]="https://www.youtube.com/playlist?list=PL3oW2tjiIxvTaC6caIGR55W3ssqGvb_LR"
["YT - New Tamil Songs 2025 🎶"]="https://www.youtube.com/playlist?list=PLinS5uF49IBpPnKzwrk8nu29EQiK4fuQs"

["YT - Top 100 English Songs 2025 🎶"]="https://www.youtube.com/playlist?list=PLx0sYbCqOb8QTF1DCJVfQrtWknZFzuoAE"
["YT - Top English Hits 2025 🎶"]="https://www.youtube.com/playlist?list=PLDIoUOhQQPlXr63I_vwF9GD8sAKh77dWU"
["YT - Top English Music Videos 2025 📹🎶"]="https://www.youtube.com/watch?v=0rYKbMjtnMo"

["YT - Sixties Greatest Hits 🎶"]="https://www.youtube.com/playlist?list=PLGBuKfnErZlCkRRgt06em8nbXvcV5Sae7"
["YT - Best 60s Songs Playlist 🎶"]="https://www.youtube.com/playlist?list=PLxA687tYuMWhsg1ZOb7dctduaJu4yUPUI"
["YT - Golden Oldies 60s Playlist 🎶"]="https://www.youtube.com/playlist?list=PLeqdIr58xuT3FqvbW1ThebL8LRoyGX3Dz"

["YT - 80s Music Hits Playlist 🎶"]="https://www.youtube.com/playlist?list=PLmXxqSJJq-yXrCPGIT2gn8b34JjOrl4Xf"
["YT - Greatest 80s Hits 🎶"]="https://www.youtube.com/playlist?list=PLCD0445C57F2B7F41"
["YT - Nonstop 80s Greatest Hits 📹🎶"]="https://www.youtube.com/watch?v=qRmTW6ruKy0"

["YT - Greatest 90s Music Hits 🎶"]="https://www.youtube.com/playlist?list=PL7DA3D097D6FDBC02"
["YT - 90s Radio Mix [Live] 📻🎶"]="https://www.youtube.com/watch?v=Ukyd5pBfJjM"
["YT - Best 90s Music Mix 📹🎶"]="https://www.youtube.com/watch?v=LvTQ6LLhlxQ"

["YT - 60s Hindi Hits (Rafi, Kishore, Lata) 🎶"]="https://www.youtube.com/watch?v=40L252sVd-c"
["YT - 80s Hindi Hits (Kishore Kumar) 🎶"]="https://www.youtube.com/watch?v=q1ErQ_TIi6w"
["YT - 90s Best Hindi Hits Collection 🎶"]="https://www.youtube.com/watch?v=8u1Bnxn9PTY"
["YT - 90s Tamil Hits (AR Rahman) 🎶"]="https://www.youtube.com/watch?v=nlc7bSWTtP4"
["YT - Best of Bollywood Hindi Love Songs Top 100"]="https://music.youtube.com/playlist?list=PL9bw4S5ePsEEqCMJSiYZ-KTtEjzVy0YvK&si=l9maTLNssaMNuya_"
["YT - Spotify Playlist 2025 🎶"]="https://music.youtube.com/playlist?list=PLOHoVaTp8R7d3L_pjuwIa6nRh4tH5nI4x&si=DxG8quSTl-fp9jk6"
["YT - Best Sad Songs that Make You Cry 🎶"]="https://music.youtube.com/playlist?list=PLBO3y7nHyBTdntbqKGSrj4MHVY6kBgErl&si=K_6nolmXwsXyxJ8L"
["YT - Top Tamil Hits Songs 🎶"]="https://music.youtube.com/playlist?list=PLHuHXHyLu7BG-gV5fc8y_jir4rKtUPHKr&si=5uZjHAtw_I8Ghy3_"
["YT - Sabrina Carpenter - Looking at Me 🎶"]="https://music.youtube.com/playlist?list=PLzra_PUujpChGZjiCiLoZO5yonEjsyjPv&si=GEkOkOgz3WTcmv2W"
["YT - Billie Baby💓"]="https://music.youtube.com/playlist?list=PLiyHrD1Lz34xUsqSUE2lyNRf-d_wbbqcz&si=9WOElcGmRL8vBTO6"
["YT - The Best ENGLISH Songs of All Time 🎶"]="https://music.youtube.com/playlist?list=PLA5F0EC50C3B8D29B&si=rc1BnhCvNdrGWk8G"
["YT - Songs with Lyrics 2025 🎶"]="https://music.youtube.com/playlist?list=PLP32wGpgzmIlInfgKVFfCwVsxgGqZNIiS&si=wOwWMQriDx_yKreQ"
["YT - Instagram Reels Trending Songs  Playlist 2025 🎶"]="https://music.youtube.com/playlist?list=PLmMoCUI44F_uQTTMVSBELjPWsjnXBWAIh&si=AtaLHt0sZVQ59-EX"
["YT - TikTok Songs 2025 🎶"]="https://music.youtube.com/playlist?list=PLTo6svdhIL1cxS4ffGueFpVCF756ip-ab&si=JCXRzp7NVJ2d3muW"
["YT - South Song 📹🎶"]="https://music.youtube.com/playlist?list=PLwlycfACM_vRUeTdoK5Z9_zcfL3iygSuS&si=RsBnNuj9muLNFGWH"
)

# ═══════════════════════════════════════════════════════════════════
# ⚠️ ERROR HANDLING & LOGGING
# ═══════════════════════════════════════════════════════════════════

trap 'error_handler $? $LINENO' ERR
trap 'cleanup_exit' EXIT INT TERM

error_handler() {
  local exit_code=$1
  local line_number=$2
  log_error "Error on line $line_number (exit code: $exit_code)"
}

cleanup_exit() {
  rm -f "$mpv_socket" 2>/dev/null || true
  log_info "RofiBEATS v$SCRIPT_VERSION exited cleanly"
}

log_info() {
  echo "[$(date +'%Y-%m-%d %H:%M:%S')] [INFO] $*" >> "$log_file"
}

log_error() {
  echo "[$(date +'%Y-%m-%d %H:%M:%S')] [ERROR] $*" >> "$log_file"
}

log_debug() {
  [[ "${DEBUG:-0}" == "1" ]] && echo "[$(date +'%Y-%m-%d %H:%M:%S')] [DEBUG] $*" >> "$log_file"
}

# ═══════════════════════════════════════════════════════════════════
# 🔔 NOTIFICATION SYSTEM
# ═══════════════════════════════════════════════════════════════════

notification() {
  local urgency="${1:-normal}"
  local title="${2:-RofiBEATS}"
  local message="${3:-}"
  
  notify-send -u "$urgency" -t $((NOTIFICATION_DURATION * 1000)) \
    -i "$iDIR/music.png" "$title" "$message" 2>/dev/null || true
  log_info "Notification: $title - $message"
}

notify_error() {
  notification critical "🎵 Error" "$1"
}

notify_success() {
  notification normal "✅ Success" "$1"
}

notify_info() {
  notification low "ℹ️ Info" "$1"
}

# ═══════════════════════════════════════════════════════════════════
# 🎵 MUSIC STATE FUNCTIONS 
# ═══════════════════════════════════════════════════════════════════

music_playing() {
  pgrep -x "mpv" >/dev/null 2>&1
  return $?
}

is_socket_alive() {
  if [[ ! -S "$mpv_socket" ]]; then
    return 1
  fi
  
  # Direct socat check: if we get ANY response, MPV is alive.
  if echo '{"command": ["get_property", "mpv-version"]}' | socat - "UNIX-CONNECT:$mpv_socket" >/dev/null 2>&1; then
    return 0
  else
    return 1
  fi
}

ensure_socket_clean() {
  if [[ -S "$mpv_socket" ]] && ! music_playing; then
    rm -f "$mpv_socket" 2>/dev/null || true
    sleep 0.1
  fi
}

wait_for_socket() {
  local counter=0
  while [[ ! -S "$mpv_socket" ]] && [[ $counter -lt $SOCKET_WAIT_TIME ]]; do
    sleep 0.2
    ((counter++))
  done
  
  if [[ -S "$mpv_socket" ]]; then
    sleep 0.5
    # Verify socket is actually responsive
    if is_socket_alive; then
      log_debug "Socket ready and responsive"
      return 0
    fi
  fi
  
  log_error "Socket creation or responsiveness timeout"
  return 1
}

get_lyrics() {
  local title="$1"
  notification normal "🎵 Lyrics" "Searching for lyrics: $title"
  
  local lyrics=$(yt-dlp --skip-download --get-subs --sub-langs "en.*,hi.*,ta.*" --sub-format "srt" --quiet --ignore-errors "$LAST_SELECTED_URL" 2>/dev/null)
  
  if [[ -z "$lyrics" ]]; then
    nohup "$DEFAULT_BROWSER" "https://www.google.com/search?q=$title+lyrics" >/dev/null 2>&1 &
    notify_info "Opened lyrics search in browser"
  else
    echo -e "$lyrics" | rofi -i -dmenu -p "📜 Lyrics: $title" -config "$rofi_theme_menu" >/dev/null
  fi
}

get_related_video() {
  local url="$1"
  log_info "Fetching related video for: $url"
  # Use --playlist-items 1,2 so it doesn't fetch the whole mix playlist metadata (making it instant)
  local current_id=$(yt-dlp --get-id "$url" 2>/dev/null)
  local mix_url="https://www.youtube.com/watch?v=${current_id}&list=RD${current_id}"
  local related_id=$(yt-dlp --flat-playlist --get-id --quiet --playlist-items 1,2 "$mix_url" 2>/dev/null | grep -v "$current_id" | head -n 1)
  
  if [[ -n "$related_id" ]]; then
    echo "https://www.youtube.com/watch?v=$related_id"
  else
    echo ""
  fi
}

stop_music() {
  pkill -x mpv 2>/dev/null || true
  sleep 0.3
  pkill -9 -x mpv 2>/dev/null || true
  sleep 0.3
  rm -f "$mpv_socket" 2>/dev/null || true
  
  # Only notify if explicitly called with "notify"
  if [[ "$1" == "notify" ]]; then
    notification low "⏹️ Music" "Playback stopped"
    log_info "Music playback stopped"
  fi
}

# ═══════════════════════════════════════════════════════════════════
# 🔊 IPC COMMUNICATION 
# ═══════════════════════════════════════════════════════════════════

mpv_ipc_send() {
  local cmd="$1"
  local timeout="${2:-$IPC_TIMEOUT}"
  
  if ! is_socket_alive; then
    log_debug "IPC socket not alive, attempting reconnect..."
    return 1
  fi
  
  {
    echo "$cmd"
    sleep 0.1
  } | timeout "$timeout" socat - "UNIX-CONNECT:$mpv_socket" 2>/dev/null
  
  local result=$?
  if [[ $result -eq 0 ]]; then
    log_debug "IPC command succeeded"
  else
    log_debug "IPC command failed (timeout or socket error)"
  fi
  return $result
}

mpv_ipc_append() {
  local url="$1"
  [[ -z "$url" ]] && return 1
  
  url=$(echo "$url" | sed 's/\\/\\\\/g; s/"/\\"/g')
  local cmd="{\"command\": [\"loadfile\", \"$url\", \"append-play\"]}"
  
  mpv_ipc_send "$cmd" >/dev/null 2>&1
  return $?
}

mpv_ipc_load() {
  local url="$1"
  [[ -z "$url" ]] && return 1
  
  url=$(echo "$url" | sed 's/\\/\\\\/g; s/"/\\"/g')
  local cmd="{\"command\": [\"loadfile\", \"$url\", \"replace\"]}"
  
  mpv_ipc_send "$cmd" >/dev/null 2>&1
  return $?
}

get_current_track_info() {
  if ! is_socket_alive; then
    # Return cached URL if socket dies
    if [[ -n "$LAST_SELECTED_URL" ]]; then
      echo "$LAST_SELECTED_TITLE|$LAST_SELECTED_URL"
      return 0
    fi
    echo "No track playing|"
    return 1
  fi
  
  local title_cmd="{\"command\": [\"get_property\", \"media-title\"]}"
  local title_resp=$(mpv_ipc_send "$title_cmd" 2>/dev/null)
  local title=$(echo "$title_resp" | jq -r '.data // empty')
  
  local path_cmd="{\"command\": [\"get_property\", \"path\"]}"
  local path_resp=$(mpv_ipc_send "$path_cmd" 2>/dev/null)
  local path=$(echo "$path_resp" | jq -r '.data // empty')
  
  if [[ -n "$title" && "$title" != "null" ]]; then
    # Cache it
    cache_selection "$title" "$path"
    echo "$title|$path"
  else
    # Return fallback
    if [[ -n "$LAST_SELECTED_URL" ]]; then
      echo "$LAST_SELECTED_TITLE|$LAST_SELECTED_URL"
    else
      echo "Unknown track|"
    fi
  fi
}

get_playlist_length() {
  if ! is_socket_alive; then
    echo 0
    return 1
  fi
  
  local cmd="{\"command\": [\"get_property\", \"playlist-count\"]}"
  local resp=$(mpv_ipc_send "$cmd" 2>/dev/null)
  echo "$resp" | jq -r '.data // 0'
}

get_current_position() {
  if ! is_socket_alive; then
    echo "0/0"
    return 1
  fi
  
  local pos_cmd="{\"command\": [\"get_property\", \"playlist-pos\"]}"
  local len_cmd="{\"command\": [\"get_property\", \"playlist-count\"]}"
  
  local pos=$(mpv_ipc_send "$pos_cmd" 2>/dev/null | jq -r '.data // 0')
  local len=$(mpv_ipc_send "$len_cmd" 2>/dev/null | jq -r '.data // 0')
  
  echo "$((pos + 1))/${len}"
}

get_playback_time() {
  if ! is_socket_alive; then
    echo "0:00|0:00"
    return 1
  fi
  
  local time_cmd="{\"command\": [\"get_property\", \"playback-time\"]}"
  local duration_cmd="{\"command\": [\"get_property\", \"duration\"]}"
  
  local time_resp=$(mpv_ipc_send "$time_cmd" 2>/dev/null)
  local duration_resp=$(mpv_ipc_send "$duration_cmd" 2>/dev/null)
  
  local time_sec=$(echo "$time_resp" | jq -r '.data // 0' | cut -d. -f1)
  local duration_sec=$(echo "$duration_resp" | jq -r '.data // 0' | cut -d. -f1 | head -1)
  
  time_sec=${time_sec:-0}
  duration_sec=${duration_sec:-0}
  
  local time_fmt=$(printf "%d:%02d" $((time_sec / 60)) $((time_sec % 60)))
  local duration_fmt=$(printf "%d:%02d" $((duration_sec / 60)) $((duration_sec % 60)))
  
  echo "$time_fmt|$duration_fmt"
}

set_volume() {
  local volume="$1"
  [[ $volume -lt 0 ]] && volume=0
  [[ $volume -gt 100 ]] && volume=100
  
  if ! is_socket_alive; then
    VOLUME_LEVEL=$volume
    return 1
  fi
  
  local cmd="{\"command\": [\"set_property\", \"volume\", $volume]}"
  mpv_ipc_send "$cmd" >/dev/null 2>&1
  VOLUME_LEVEL=$volume
  log_debug "Volume set to $volume"
}

toggle_pause() {
  if ! is_socket_alive; then
    playerctl -p mpv play-pause
    return 0
  fi
  
  local cmd="{\"command\": [\"cycle\", \"pause\"]}"
  mpv_ipc_send "$cmd" >/dev/null 2>&1
  log_debug "Play/Pause toggled"
  sleep 0.3
  return 0
}

next_track() {
  # Check if we are at the end of the playlist
  local pos_cmd="{\"command\": [\"get_property\", \"playlist-pos\"]}"
  local count_cmd="{\"command\": [\"get_property\", \"playlist-count\"]}"
  
  local pos=$(mpv_ipc_send "$pos_cmd" 2>/dev/null | jq -r '.data // 0')
  local count=$(mpv_ipc_send "$count_cmd" 2>/dev/null | jq -r '.data // 0')
  
  # If pos + 1 < count, we have more tracks in the mpv playlist
  if [[ $((pos + 1)) -lt $count ]]; then
    local cmd="{\"command\": [\"playlist-next\"]}"
    mpv_ipc_send "$cmd" >/dev/null 2>&1
    log_debug "Next track (Playlist)"
    sleep 0.3
    return 0
  fi

  # Otherwise, use our Auto-Radio logic
  if [[ -s "$queue_file" ]]; then
    play_from_queue
  elif [[ $AUTOPLAY -eq 1 ]] && is_youtube_url "$LAST_SELECTED_URL"; then
    local next_url=""
    
    if [[ -f "$next_url_file" ]] && [[ -s "$next_url_file" ]]; then
      next_url=$(cat "$next_url_file")
      log_debug "Using pre-fetched next URL: $next_url"
    else
      next_url=$(get_related_video "$LAST_SELECTED_URL")
    fi
    
    if [[ -n "$next_url" ]]; then
      local next_title=$(yt-dlp --get-title "$next_url" 2>/dev/null)
      notification normal "🎵 Autoplay" "Next: $next_title"
      cache_selection "$next_title" "$next_url"
      
      # SEAMLESS TRANSITION using IPC instead of stopping!
      if is_socket_alive; then
         mpv_ipc_load "$next_url"
      else
         stop_music silent
         run_mpv "$next_url"
         wait_for_socket
         start_endfile_watcher
      fi
    else
      play_random_station
    fi
  else
    play_random_station
  fi
  return 0
}

previous_track() {
  if ! is_socket_alive; then
    playerctl -p mpv previous
    return 0
  fi
  
  local cmd="{\"command\": [\"playlist-prev\"]}"
  mpv_ipc_send "$cmd" >/dev/null 2>&1
  log_debug "Previous track"
  sleep 0.3
  return 0
}

seek_to_position() {
  local target="$1"
  if ! is_socket_alive; then
    return 1
  fi
  
  if [[ "$target" == "relative"* ]]; then
    local seconds="${target#relative}"
    local cmd="{\"command\": [\"seek\", $seconds, \"relative\"]}"
    mpv_ipc_send "$cmd" >/dev/null 2>&1
    notify_info "Seek: $seconds s"
  else
    local cmd="{\"command\": [\"set_property\", \"playback-time\", $target]}"
    mpv_ipc_send "$cmd" >/dev/null 2>&1
  fi
}

set_repeat_mode() {
  local mode="$1"
  if ! is_socket_alive; then
    return 1
  fi
  
  case "$mode" in
    none)
      local cmd="{\"command\": [\"set_property\", \"loop-playlist\", false]}"
      mpv_ipc_send "$cmd" >/dev/null 2>&1
      REPEAT_MODE="none"
      ;;
    one)
      local cmd="{\"command\": [\"set_property\", \"loop-file\", \"inf\"]}"
      mpv_ipc_send "$cmd" >/dev/null 2>&1
      REPEAT_MODE="one"
      ;;
    all)
      local cmd="{\"command\": [\"set_property\", \"loop-playlist\", \"inf\"]}"
      mpv_ipc_send "$cmd" >/dev/null 2>&1
      REPEAT_MODE="all"
      ;;
  esac
}

# ═══════════════════════════════════════════════════════════════════
# 📺 VIEW VIDEO FEATURE 
# ═══════════════════════════════════════════════════════════════════

extract_youtube_url() {
  local path="$1"
  
  if [[ "$path" =~ v=([^&]+) ]]; then
    echo "<https://www.youtube.com/watch?v=${BASH_REMATCH>}"
  elif [[ "$path" =~ youtu\.be/([^?&/]+) ]]; then
    echo "<https://www.youtube.com/watch?v=${BASH_REMATCH>}"
  elif [[ "$path" =~ youtube\.com/watch ]]; then
    echo "$path"
  elif [[ "$path" =~ youtu\.be ]]; then
    echo "$path"
  else
    echo "$path"
  fi
}

is_youtube_url() {
  local url="$1"
  [[ "$url" =~ youtube\.com|youtu\.be ]]
  return $?
}

view_playing_video() {
  if [[ -z "$DEFAULT_BROWSER" ]]; then
    notify_error "No browser found (Firefox, Chromium, Chrome, or Brave required)"
    log_error "No browser detected"
    return 1
  fi
  
  local track_info=$(get_current_track_info)
  local path="${track_info##*|}"
  
  if [[ -z "$path" || "$path" == "No track playing" ]]; then
    notify_error "No video currently playing"
    return 1
  fi
  
  if ! is_youtube_url "$path"; then
    # Try cached URL
    if is_youtube_url "$LAST_SELECTED_URL"; then
      path="$LAST_SELECTED_URL"
    else
      notify_error "Current track is not from YouTube"
      return 1
    fi
  fi
  
  local video_url=$(extract_youtube_url "$path")
  
  notification normal "🌐 Browser" "Opening video..."
  nohup "$DEFAULT_BROWSER" "$video_url" >/dev/null 2>&1 &
  log_info "Opened video in browser: $video_url"
  
  sleep 1
  notify_success "Video opened in browser"
}

# ═══════════════════════════════════════════════════════════════════
# 📹 DOWNLOAD VIDEO FEATURE
# ═══════════════════════════════════════════════════════════════════

select_download_quality() {
  local quality=$(printf "🎬 Best Quality (auto)\n1080p Full HD\n720p HD\n480p SD\n360p Mobile\n◄ Cancel" | \
    rofi -i -dmenu -p "📹 Select Video Quality" -config "$rofi_theme_menu")
  
  case "$quality" in
    "🎬 Best Quality (auto)")
      echo "best"
      ;;
    "1080p Full HD")
      echo "bestvideo[height<=1080]+bestaudio/best"
      ;;
    "720p HD")
      echo "bestvideo[height<=720]+bestaudio/best"
      ;;
    "480p SD")
      echo "bestvideo[height<=480]+bestaudio/best"
      ;;
    "360p Mobile")
      echo "bestvideo[height<=360]+bestaudio/best"
      ;;
    *)
      echo ""
      ;;
  esac
}

download_video() {
  local title="$1"
  local url="$2"
  
  if ! is_youtube_url "$url"; then
    notify_error "Only YouTube videos can be downloaded"
    return 1
  fi
  
  local quality=$(select_download_quality)
  [[ -z "$quality" ]] && return 1
  
  notification normal "⬇️ Download" "Starting: $title"
  log_info "Download started - Title: $title | URL: $url | Quality: $quality"
  
  (
    local start_time=$(date +%s)
    cd "$video_downloads_dir" || return 1
    
    if yt-dlp -f "$quality" --merge-output-format mkv \
           --embed-thumbnail --embed-metadata \
           --progress --newline \
           --output "%(title)s.%(ext)s" \
           --ignore-errors "$url" 2>>"$download_log"; then
      local end_time=$(date +%s)
      local duration=$((end_time - start_time))
      
      notify_success "Downloaded: $title (${duration}s)"
      log_info "Download completed: $title (Duration: ${duration}s)"
      echo "[$(date +'%Y-%m-%d %H:%M:%S')] ✅ COMPLETED: $title" >> "$download_log"
    else
      notify_error "Download failed: $title"
      log_error "Download failed: $title"
      echo "[$(date +'%Y-%m-%d %H:%M:%S')] ❌ FAILED: $title" >> "$download_log"
    fi
  ) &
}

# ═══════════════════════════════════════════════════════════════════
# 🎵 AUDIO DOWNLOAD
# ═══════════════════════════════════════════════════════════════════

download_track() {
  local title="$1"
  local url="$2"
  
  notification normal "⬇️ Download" "Starting: $title (Audio)"
  log_info "Audio download started - Title: $title"
  
  (
    local start_time=$(date +%s)
    cd "$downloads_dir" || return 1
    
    if yt-dlp --extract-audio --audio-format mp3 --audio-quality 0 \
           --embed-thumbnail --embed-metadata \
           --progress --newline \
           --output "%(title)s.%(ext)s" \
           --ignore-errors "$url" 2>>"$download_log"; then
      local end_time=$(date +%s)
      local duration=$((end_time - start_time))
      
      notify_success "Downloaded: $title (${duration}s)"
      log_info "Audio download completed: $title"
      echo "[$(date +'%Y-%m-%d %H:%M:%S')] ✅ AUDIO: $title" >> "$download_log"
    else
      notify_error "Download failed: $title"
      log_error "Audio download failed: $title"
      echo "[$(date +'%Y-%m-%d %H:%M:%S')] ❌ AUDIO FAILED: $title" >> "$download_log"
    fi
  ) &
}

# ═══════════════════════════════════════════════════════════════════
# 📜 HISTORY MANAGEMENT
# ═══════════════════════════════════════════════════════════════════

add_to_history() {
  local title="$1"
  local url="$2"
  local timestamp=$(date '+%Y-%m-%d %H:%M')
  
  title=$(echo "$title" | sed 's/|/║/g')
  local safe_title=$(printf '%s\n' "$title" | sed 's/[][\/.^$*]/\\&/g')
  
  if [[ -f "$history_file" ]]; then
    grep -v "^${safe_title}|" "$history_file" > "${history_file}.tmp" 2>/dev/null || true
    mv "${history_file}.tmp" "$history_file" 2>/dev/null || true
  fi
  
  echo "$title|$url|$timestamp" >> "$history_file"
  
  tail -n "$MAX_HISTORY_ENTRIES" "$history_file" > "${history_file}.tmp"
  mv "${history_file}.tmp" "$history_file"
  
  log_info "Added to history: $title"
}

clear_history() {
  local response=$(printf "Yes\nNo" | rofi -i -dmenu -p "🗑️ Clear History?" -config "$rofi_theme_menu")
  
  if [[ "$response" == "Yes" ]]; then
    rm -f "$history_file"
    notification normal "📜 History" "Cleared successfully"
    log_info "History cleared"
  fi
}

show_history() {
  [[ ! -f "$history_file" ]] && { notification low "📜 History" "No history found"; return; }
  
  while true; do
    local entries=()
    local urls=()
    
    while IFS='|' read -r title url timestamp; do
      [[ -z "$title" ]] && continue
      title=$(echo "$title" | sed 's/║/|/g')
      entries+=("$title  📅 $timestamp")
      urls+=("$url")
    done < <(tac "$history_file")
    
    [[ ${#entries[@]} -eq 0 ]] && { notification low "📜 History" "No history found"; return; }
    
    local choice=$(printf "%s\n" "${entries[@]}" "🗑️ Clear History" "◄ Back to Main Menu" | rofi -i -dmenu -p "📜 YouTube History" -config "$rofi_theme")
    [[ -z "$choice" || "$choice" == "◄ Back to Main Menu" ]] && return
    
    if [[ "$choice" == "🗑️ Clear History" ]]; then
      clear_history
      continue
    fi
    
    local idx=0
    for ((i=0; i<${#entries[@]}; i++)); do
      if [[ "${entries[$i]}" == "$choice" ]]; then
        idx=$i
        break
      fi
    done
    
    local selected_url="${urls[$idx]}"
    
    if music_playing && mpv_ipc_append "$selected_url"; then
      notification normal "➕ Queued" "$(echo "$choice" | cut -d' ' -f1-3)"
    else
      ensure_socket_clean
      stop_music
      notification normal "🎵 Playing" "$(echo "$choice" | cut -d' ' -f1-3)"
      cache_selection "$(echo "$choice" | cut -d' ' -f1-3)" "$selected_url"
      run_mpv "$selected_url"
      wait_for_socket
      start_endfile_watcher
    fi
  done
}

# ═══════════════════════════════════════════════════════════════════
# ⭐ FAVORITES MANAGEMENT (USE CACHED URL)
# ═══════════════════════════════════════════════════════════════════

add_to_favorites() {
  local title="$1"
  local url="$2"
  
  # If URL is empty, try cached URL
  if [[ -z "$url" ]] && [[ -n "$LAST_SELECTED_URL" ]]; then
    url="$LAST_SELECTED_URL"
    title="${title:-$LAST_SELECTED_TITLE}"
  fi
  
  # Validate it's YouTube
  if ! is_youtube_url "$url"; then
    notify_error "Only YouTube tracks can be favorited"
    return 1
  fi
  
  title=$(echo "$title" | sed 's/|/║/g')
  
  if [[ -f "$favorites_file" ]] && grep -q "^${title}|" "$favorites_file"; then
    notification low "⭐ Favorites" "Already in favorites"
    return 0
  fi
  
  echo "$title|$url" >> "$favorites_file"
  notification normal "⭐ Favorites" "Added successfully: $title"
  log_info "Added to favorites: $title | $url"
}

remove_from_favorites() {
  local title="$1"
  title=$(echo "$title" | sed 's/|/║/g')
  local safe_title=$(printf '%s\n' "$title" | sed 's/[][\/.^$*]/\\&/g')
  
  if [[ -f "$favorites_file" ]]; then
    grep -v "^${safe_title}|" "$favorites_file" > "${favorites_file}.tmp"
    mv "${favorites_file}.tmp" "$favorites_file"
    notification normal "⭐ Favorites" "Removed from favorites"
    log_info "Removed from favorites: $title"
  fi
}

show_favorites() {
  [[ ! -f "$favorites_file" ]] && { notification low "⭐ Favorites" "No favorites found"; return; }
  
  while true; do
    local entries=()
    local urls=()
    
    while IFS='|' read -r title url; do
      [[ -z "$title" ]] && continue
      title=$(echo "$title" | sed 's/║/|/g')
      entries+=("$title")
      urls+=("$url")
    done < "$favorites_file"
    
    [[ ${#entries[@]} -eq 0 ]] && { notification low "⭐ Favorites" "No favorites found"; return; }
    
    local choice=$(printf "%s\n" "${entries[@]}" "◄ Back to Main Menu" | rofi -i -dmenu -p "⭐ Favorites (${#entries[@]})" -config "$rofi_theme")
    [[ -z "$choice" || "$choice" == "◄ Back to Main Menu" ]] && return
    
    local idx=0
    for ((i=0; i<${#entries[@]}; i++)); do
      if [[ "${entries[$i]}" == "$choice" ]]; then
        idx=$i
        break
      fi
    done
    
    local selected_url="${urls[$idx]}"
    
    local action=$(printf "▶️ Play\n➕ Add to Queue\n👁️ View Video\n📹 Download Video\n⬇️ Download Audio\n❌ Remove from Favorites\n◄ Back" | rofi -i -dmenu -p "⭐ $choice" -config "$rofi_theme_menu")
    
    case "$action" in
      "▶️ Play")
        ensure_socket_clean
        stop_music
        notification normal "🎵 Playing" "$choice"
        cache_selection "$choice" "$selected_url"
        run_mpv "$selected_url"
        wait_for_socket
        start_endfile_watcher
        return
        ;;
      "➕ Add to Queue")
        if music_playing && mpv_ipc_append "$selected_url"; then
          notification normal "➕ Queued" "$choice"
        else
          notify_error "Cannot queue - no music playing"
        fi
        ;;
      "👁️ View Video")
        if is_youtube_url "$selected_url"; then
          [[ -z "$DEFAULT_BROWSER" ]] && { notify_error "No browser found"; continue; }
          nohup "$DEFAULT_BROWSER" "$selected_url" >/dev/null 2>&1 &
          notify_success "Video opened"
        else
          notify_error "Not a YouTube video"
        fi
        ;;
      "📹 Download Video")
        download_video "$choice" "$selected_url"
        ;;
      "⬇️ Download Audio")
        download_track "$choice" "$selected_url"
        ;;
      "❌ Remove from Favorites")
        remove_from_favorites "$choice"
        ;;
    esac
  done
}

# ═══════════════════════════════════════════════════════════════════
# 📋 QUEUE MANAGEMENT
# ═══════════════════════════════════════════════════════════════════

add_to_queue() {
  local title="$1"
  local url="$2"
  
  local queue_size=$(wc -l < "$queue_file" 2>/dev/null || echo 0)
  if [[ $queue_size -ge $MAX_QUEUE_SIZE ]]; then
    notify_error "Queue is full (max $MAX_QUEUE_SIZE tracks)"
    return 1
  fi
  
  title=$(echo "$title" | sed 's/|/║/g')
  echo "$title|$url" >> "$queue_file"
  notification normal "📋 Queue" "Added: $title"
  log_info "Added to queue: $title"
}

show_queue() {
  [[ ! -f "$queue_file" ]] || [[ ! -s "$queue_file" ]] && { notification low "📋 Queue" "Queue is empty"; return; }
  
  while true; do
    local entries=()
    local urls=()
    local line_num=1
    
    while IFS='|' read -r title url; do
      [[ -z "$title" ]] && continue
      title=$(echo "$title" | sed 's/║/|/g')
      entries+=("[$line_num] $title")
      urls+=("$url")
      ((line_num++))
    done < "$queue_file"
    
    [[ ${#entries[@]} -eq 0 ]] && { notification low "📋 Queue" "Queue is empty"; return; }
    
    local choice=$(printf "%s\n" "${entries[@]}" "🗑️ Clear Queue" "◄ Back to Main Menu" | rofi -i -dmenu -p "📋 Queue (${#entries[@]})" -config "$rofi_theme")
    [[ -z "$choice" || "$choice" == "◄ Back to Main Menu" ]] && return
    
    if [[ "$choice" == "🗑️ Clear Queue" ]]; then
      rm -f "$queue_file"
      notification normal "📋 Queue" "Cleared"
      return
    fi
    
    local idx=0
    for ((i=0; i<${#entries[@]}; i++)); do
      if [[ "${entries[$i]}" == "$choice" ]]; then
        idx=$i
        break
      fi
    done
    
    local selected_url="${urls[$idx]}"
    
    if music_playing && mpv_ipc_append "$selected_url"; then
      notification normal "▶️ Playing" "From queue"
    fi
  done
}

play_from_queue() {
  [[ ! -f "$queue_file" ]] || [[ ! -s "$queue_file" ]] && { notify_error "Queue is empty"; return; }
  
  local first_entry=$(head -n 1 "$queue_file")
  IFS='|' read -r title url <<< "$first_entry"
  
  title=$(echo "$title" | sed 's/║/|/g')
  
  tail -n +2 "$queue_file" > "${queue_file}.tmp"
  mv "${queue_file}.tmp" "$queue_file"
  
  if music_playing && mpv_ipc_append "$url"; then
    notification normal "▶️ Playing" "From queue: $title"
  else
    ensure_socket_clean
    stop_music
    notification normal "🎵 Playing" "$title"
    cache_selection "$title" "$url"
    run_mpv "$url"
    wait_for_socket
    start_endfile_watcher
  fi
}

# ═══════════════════════════════════════════════════════════════════
# 🎵 NOW PLAYING INTERFACE
# ═══════════════════════════════════════════════════════════════════

show_now_playing() {
  while true; do
    if ! music_playing; then
      notification low "🎵 Now Playing" "No music playing"
      return
    fi
    
    local track_info=$(get_current_track_info)
    local title="${track_info%%|*}"
    local path="${track_info##*|}"
    
    if [[ "$title" == "Unknown track" ]] || [[ -z "$title" ]]; then
      notify_info "No track info available"
      return
    fi
    
    local pos=$(get_current_position)
    local time_info=$(get_playback_time)
    local current_time="${time_info%%|*}"
    local total_time="${time_info##*|}"
    
    local display_title="${title:0:35}"
    [[ ${#title} -gt 35 ]] && display_title="${display_title}..."
    
    local repeat_icon=""
    case "$REPEAT_MODE" in
      one) repeat_icon="🔁" ;;
      all) repeat_icon="🔂" ;;
      *) repeat_icon="➡️" ;;
    esac
    
    
    local volume_bar=""
    local v_percent=$((VOLUME_LEVEL / 10))
    for ((i=0; i<v_percent; i++)); do volume_bar="${volume_bar}▮"; done
    for ((i=v_percent; i<10; i++)); do volume_bar="${volume_bar}▯"; done
    
    # CRITICAL FIX: Check both current path AND cached URL
    local is_youtube=false
    if is_youtube_url "$path" || is_youtube_url "$LAST_SELECTED_URL"; then
      is_youtube=true
    fi
    
    local options=(
      "▶️ Play/Pause"
      "⏭️ Next Track"
      "⏮️ Previous Track"
      "📊 Seek Position [$current_time/$total_time]"
      "$repeat_icon Repeat Mode ($REPEAT_MODE)"
      "🔊 Volume: ${volume_bar} $VOLUME_LEVEL%"
    )
    
    if $is_youtube; then
      options+=(
        "👁️ View Playing Video"
        "📹 Download Video"
        "⬇️ Download Audio"
      )
    fi
    
    options+=(
      "⭐ Add to Favorites"
      "➕ Add to Queue"
      "📊 Playlist Info"
      "📋 Keyboard Shortcuts"
      "◄ Back to Main Menu"
    )
    
    local choice=$(printf "%s\n" "${options[@]}" | rofi -i -dmenu -p "🎵 $display_title [$pos]" -config "$rofi_theme_menu")
    [[ -z "$choice" || "$choice" == "◄ Back to Main Menu" ]] && return
    
    case "$choice" in
      "▶️ Play/Pause")
        toggle_pause
        ;;
      "⏭️ Next Track")
        next_track
        ;;
      "⏮️ Previous Track")
        previous_track
        ;;
      "📊 Seek Position"*)
        local seek_opts=(
          "⏩ +10 Seconds"
          "⏩ +30 Seconds"
          "⏩ +60 Seconds"
          "⏪ -10 Seconds"
          "⏪ -30 Seconds"
          "⏪ -60 Seconds"
          "T  Type Seconds"
          "D  Go to 0:00"
          "◄ Back"
        )
        local seek_choice=$(printf "%s\n" "${seek_opts[@]}" | rofi -i -dmenu -p "⏱️ Seek" -config "$rofi_theme_menu")
        
        case "$seek_choice" in
          "⏩ +10 Seconds") seek_to_position "relative+10" ;;
          "⏩ +30 Seconds") seek_to_position "relative+30" ;;
          "⏩ +60 Seconds") seek_to_position "relative+60" ;;
          "⏪ -10 Seconds") seek_to_position "relative-10" ;;
          "⏪ -30 Seconds") seek_to_position "relative-30" ;;
          "⏪ -60 Seconds") seek_to_position "relative-60" ;;
          "D  Go to 0:00") seek_to_position "0" ;;
          "T  Type Seconds")
             local seek_input=$(rofi -dmenu -p "⏱️ Enter seconds" -config "$rofi_theme_menu")
             if [[ -n "$seek_input" && "$seek_input" =~ ^[0-9]+$ ]]; then
               seek_to_position "$seek_input"
               notify_info "Seeked to $seek_input seconds"
             fi
             ;;
        esac
        ;;
      "$repeat_icon Repeat Mode"*)
        local new_mode="none"
        case "$REPEAT_MODE" in
          none) new_mode="one" ;;
          one) new_mode="all" ;;
          all) new_mode="none" ;;
        esac
        set_repeat_mode "$new_mode"
        notify_info "Repeat: $new_mode"
        ;;
      "🔊 Volume:"*)
        local vol_choice=$(printf "0\n10\n20\n30\n40\n50\n60\n70\n80\n90\n100" | rofi -i -dmenu -p "🔊 Volume" -config "$rofi_theme_menu")
        [[ -n "$vol_choice" ]] && set_volume "$vol_choice"
        ;;
      "👁️ View Playing Video")
        view_playing_video
        ;;
      "📹 Download Video")
        if $is_youtube; then
          # Use cached URL if path is empty
          local dl_url="${path:-$LAST_SELECTED_URL}"
          download_video "$title" "$dl_url"
        else
          notify_error "Not a YouTube video"
        fi
        ;;
      "⬇️ Download Audio")
        if $is_youtube; then
          local dl_url="${path:-$LAST_SELECTED_URL}"
          download_track "$title" "$dl_url"
        else
          notify_error "Not a YouTube video"
        fi
        ;;
      "⭐ Add to Favorites")
        # Use cached URL if path is empty - FIX FOR SEARCH MENU BUG
        local fav_url="${path:-$LAST_SELECTED_URL}"
        add_to_favorites "$title" "$fav_url"
        ;;
      "➕ Add to Queue")
        add_to_queue "$title" "$path"
        ;;
      "📊 Playlist Info")
        show_playlist_info
        ;;
      "📋 Keyboard Shortcuts")
        show_keyboard_shortcuts
        ;;
    esac
  done
}

show_playlist_info() {
  if ! is_socket_alive; then
    notification low "📊 Playlist" "No playlist available"
    return
  fi
  
  local len=$(get_playlist_length)
  local pos=$(get_current_position)
  local time_info=$(get_playback_time)
  local repeat_mode_display="$REPEAT_MODE"
  local volume_display="$VOLUME_LEVEL%"
  
  local info="Playlist Length: $len tracks\nCurrent Position: $pos\nPlayback Time: ${time_info%%|*} / ${time_info##*|}\nRepeat Mode: $repeat_mode_display\nVolume: $volume_display\nAutoplay: $([ $AUTOPLAY -eq 1 ] && echo 'Enabled' || echo 'Disabled')"
  
  echo -e "$info" | rofi -i -dmenu -p "📊 Playlist Info" -config "$rofi_theme_menu" >/dev/null
}

show_keyboard_shortcuts() {
  local shortcuts="🎵 RofiBEATS - Keyboard Shortcuts

⚡ Main Features:
  🔍 Search YouTube → Find and play songs
  🎵 Now Playing → Control playback
  ⭐ Favorites → Save your loved tracks
  📜 History → Browse recently played
  📋 Queue → Manage playlist
  🌐 Online Stations → Stream radio
  🎧 Local Music → Play local files
  🔀 Shuffle → Random playback
  ⬇️ Downloads → View downloaded files

🎮 Now Playing Controls:
  ▶️ Play/Pause → Resume or pause
  ⏭️ Next → Skip to next track
  ⏮️ Previous → Go back
  🔊 Volume → Adjust 0-100%
  📊 Seek → Jump to specific time

📹 Video Features (YouTube only):
  👁️ View Video → Open in browser
  📹 Download Video → Save full video
  ⬇️ Download Audio → Save as MP3

⚙️ Settings:
  🔁 Autoplay → Auto-play next track
  🗑️ Clear → History/Queue/Cache
  📝 Logs → View debug information"
  
  echo -e "$shortcuts" | rofi -i -dmenu -p "📋 Shortcuts" -config "$rofi_theme_menu" >/dev/null
}

# ═══════════════════════════════════════════════════════════════════
# 🌐 ONLINE STREAMING
# ═══════════════════════════════════════════════════════════════════

play_online_music() {
  while true; do
    local stations=$(printf "%s\n" "${!online_music[@]}" | sort)
    local choice=$(printf "◄ Back to Main Menu\n%s" "$stations" | rofi -i -dmenu -p "🌐 Online Stations" -config "$rofi_theme")
    [[ -z "$choice" || "$choice" == "◄ Back to Main Menu" ]] && return
    
    local url="${online_music[$choice]}"
    cache_selection "$choice" "$url"
    
    if music_playing && mpv_ipc_append "$url"; then
      notification normal "➕ Queued" "$choice"
    else
      ensure_socket_clean
      stop_music
      notification normal "🎵 Playing" "$choice"
      run_mpv "$url"
      wait_for_socket
      start_endfile_watcher
    fi
  done
}

# ═══════════════════════════════════════════════════════════════════
# 📚 LOCAL MUSIC
# ═══════════════════════════════════════════════════════════════════

populate_local_music() {
  local -a local_music_temp
  mapfile -t local_music_temp < <(find -L "$mDIR" -maxdepth 3 -type f \
    \( -iname "*.mp3" -o -iname "*.flac" -o -iname "*.wav" -o -iname "*.ogg" -o -iname "*.m4a" \) 2>/dev/null | sort)
  
  CURRENT_PLAYLIST=("${local_music_temp[@]}")
  log_info "Populated ${#CURRENT_PLAYLIST[@]} local tracks"
}

play_local_music() {
  populate_local_music
  
  [[ ${#CURRENT_PLAYLIST[@]} -eq 0 ]] && { notify_error "No music files found in $mDIR"; return; }
  
  local -a display_names
  for file in "${CURRENT_PLAYLIST[@]}"; do
    display_names+=("${file##*/}")
  done
  
  local choice=$(printf "%s\n" "${display_names[@]}" | rofi -i -dmenu -p "🎧 Local Music (${#display_names[@]})" -config "$rofi_theme")
  [[ -z "$choice" ]] && return
  
  local idx=0
  for ((i=0; i<${#display_names[@]}; i++)); do
    if [[ "${display_names[$i]}" == "$choice" ]]; then
      idx=$i
      break
    fi
  done
  
  ensure_socket_clean
  stop_music
  notification normal "🎵 Playing" "${choice%.*}"
  cache_selection "${choice%.*}" "${CURRENT_PLAYLIST[$idx]}"
  
  mpv --profile=audio --vid=no --playlist-start="$idx" --loop-playlist \
      "${CURRENT_PLAYLIST[@]}" --input-ipc-server="$mpv_socket" >/dev/null 2>&1 &
  wait_for_socket
  start_endfile_watcher
}

shuffle_local_music() {
  populate_local_music
  
  [[ ${#CURRENT_PLAYLIST[@]} -eq 0 ]] && { notify_error "No music files found in $mDIR"; return; }
  
  ensure_socket_clean
  stop_music
  notification normal "🎵 Playing" "🔀 Shuffle - ${#CURRENT_PLAYLIST[@]} tracks"
  
  {
    printf "%s\n" "${CURRENT_PLAYLIST[@]}" | shuf | mpv --profile=audio --vid=no \
      --shuffle --loop-playlist --playlist=- --input-ipc-server="$mpv_socket"
  } >/dev/null 2>&1 &
  
  wait_for_socket
  start_endfile_watcher
}

# ═══════════════════════════════════════════════════════════════════
# 🔍 YOUTUBE SEARCH & PLAYBACK 
# ═══════════════════════════════════════════════════════════════════

search_youtube_safe() {
  local query="$1"
  local cache_file="${cache_dir}/yt_$(echo "$query" | md5sum | cut -d' ' -f1).txt"
  
  if [[ -f "$cache_file" ]] && [[ $(find "$cache_file" -mmin -60 2>/dev/null) ]]; then
    mapfile -t results < "$cache_file"
  else
    notification normal "🔎 Searching" "YouTube for: $query"
    
    mapfile -t results < <(timeout "$YT_DLP_TIMEOUT" yt-dlp --flat-playlist --ignore-errors --skip-download \
      --quiet --no-playlist "ytsearch15:$query" \
      --print "%(title)s|%(id)s|%(duration_string)s|https://i.ytimg.com/vi/%(id)s/hqdefault.jpg" 2>/dev/null || true)
    
    if [[ ${#results[@]} -eq 0 ]]; then
      notify_error "No results found for: $query"
      return 1
    fi
    
    printf "%s\n" "${results[@]}" >"$cache_file"
  fi
  
  return 0
}

search_and_play_youtube() {
  local query=$(rofi -dmenu -p "🔍 Search YouTube" -config "$rofi_theme_menu")
  [[ -z "$query" ]] && return
  
  if ! search_youtube_safe "$query"; then
    return
  fi
  
  local -a results
  local cache_file="${cache_dir}/yt_$(echo "$query" | md5sum | cut -d' ' -f1).txt"
  mapfile -t results < "$cache_file"
  
  # Fetch thumbnails in background
  local count=0
  for r in "${results[@]}"; do
    local id=$(echo "$r" | cut -d'|' -f2)
    local thumb_url=$(echo "$r" | cut -d'|' -f4)
    local thumb_file="${thumb_cache}/${id}.jpg"
    
    if [[ ! -f "$thumb_file" && -n "$thumb_url" ]]; then
      curl -s "$thumb_url" -o "$thumb_file" &
      # Wait a tiny bit for the first 3 thumbnails so they appear immediately
      [[ $count -lt 3 ]] && sleep 0.1
    fi
    ((count++))
  done
  
  # A small extra pause to let the downloads settle
  sleep 0.2
  
  while true; do
    local choice=$( (
      for r in "${results[@]}"; do
        IFS='|' read -r title id dur thumb_url <<< "$r"
        [[ -z "$dur" || "$dur" == "NA" ]] && dur="LIVE"
        
        local thumb_file="${thumb_cache}/${id}.jpg"
        # If thumbnail doesn't exist yet, show a music icon placeholder
        if [[ ! -f "$thumb_file" ]]; then
           thumb_file="$iDIR/music.png"
        fi
        echo -en "${title}  ⏱ ${dur}  ⟨${id}⟩\0icon\x1f${thumb_file}\n"
      done
      echo "◄ Back to Main Menu"
    ) | rofi -i -dmenu -p "🎵 Results for: $query" -config "$rofi_theme")

    [[ -z "$choice" || "$choice" == "◄ Back to Main Menu" ]] && return
    
    # Extract ID more reliably
    local sel_id=$(echo "$choice" | sed 's/.*⟨//; s/⟩.*//')
    local sel_title=$(echo "$choice" | sed 's/  ⏱.*//')
    local link="https://www.youtube.com/watch?v=$sel_id"
    local thumb_path="${thumb_cache}/${sel_id}.jpg"
    
    # CACHE THE SELECTION
    cache_selection "$sel_title" "$link" "$thumb_path"
    add_to_history "$sel_title" "$link"
    
    if music_playing && mpv_ipc_append "$link"; then
      notification normal "➕ Queued" "$sel_title"
    else
      ensure_socket_clean
      stop_music
      notification normal "🎵 Playing" "$sel_title"
      run_mpv "$link"
      wait_for_socket
      start_endfile_watcher
    fi
  done
}

# ═══════════════════════════════════════════════════════════════════
# 🎬 AUTOPLAY & WATCHER
# ═══════════════════════════════════════════════════════════════════

play_random_station() {
  # Pick a random station to play
  local keys=("${!online_music[@]}")
  local random_idx=$((RANDOM % ${#keys[@]}))
  local random_key="${keys[$random_idx]}"
  local random_url="${online_music[$random_key]}"
  
  notify_info "🔀 Autoplay: $random_key"
  
  ensure_socket_clean
  stop_music
  cache_selection "$random_key" "$random_url"
  run_mpv "$random_url"
  wait_for_socket
  start_endfile_watcher
}

start_endfile_watcher() {
  pgrep -f "endfile_watcher.*$$" >/dev/null && return 0
  
  (
    if ! wait_for_socket; then
      log_error "Socket never appeared for end-file watcher"
      return 1
    fi
    
    log_debug "End-file watcher started"
    
    local timeout_counter=0
    
    {
      while IFS= read -r line; do
        if [[ "$line" == *'\"event\":\"end-file\"'* ]]; then
          log_debug "End-file event detected"
          
          if [[ -s "$queue_file" ]]; then
            log_debug "Queue has items, playing from queue"
            play_from_queue
            break
          elif [[ $AUTOPLAY -eq 1 ]]; then
            log_debug "Autoplay enabled"
            play_random_station
          fi
          
          break
        fi
        
        ((timeout_counter++))
        [[ $timeout_counter -gt 3600 ]] && break
      done
    } < <(timeout 3610 socat - "UNIX-CONNECT:$mpv_socket" 2>/dev/null || true)
    
    log_debug "End-file watcher ended"
  ) >/dev/null 2>&1 &
}

# ═══════════════════════════════════════════════════════════════════
# 📁 DOWNLOADED FILES MANAGEMENT 
# ═══════════════════════════════════════════════════════════════════

list_downloads() {
  while true; do
    local -a audio_files
    local -a video_files
    mapfile -t audio_files < <(find "$downloads_dir" -maxdepth 1 -type f \( -name "*.mp3" -o -name "*.m4a" -o -name "*.flac" \) 2>/dev/null | sort)
    mapfile -t video_files < <(find "$video_downloads_dir" -maxdepth 1 -type f \( -name "*.mp4" -o -name "*.mkv" -o -name "*.webm" \) 2>/dev/null | sort)
    
    if [[ ${#audio_files[@]} -eq 0 && ${#video_files[@]} -eq 0 ]]; then
      notification low "⬇️ Downloads" "No downloads found"
      return
    fi
    
    local -a all_files=()
    local -a file_types=()
    local -a display_items=()
    
    if [[ ${#audio_files[@]} -gt 0 ]]; then
      display_items+=("📁 AUDIO FILES (${#audio_files[@]})")
      for f in "${audio_files[@]}"; do
        display_items+=("  🎵 ${f##*/}")
        all_files+=("$f")
        file_types+=("audio")
      done
    fi
    
    if [[ ${#video_files[@]} -gt 0 ]]; then
      display_items+=("📁 VIDEO FILES (${#video_files[@]})")
      for f in "${video_files[@]}"; do
        display_items+=("  📹 ${f##*/}")
        all_files+=("$f")
        file_types+=("video")
      done
    fi
    
    display_items+=("◄ Back to Main Menu")
    
    local choice=$(printf "%s\n" "${display_items[@]}" | rofi -i -dmenu -p "⬇️ Downloaded Files (A:${#audio_files[@]} V:${#video_files[@]})" -config "$rofi_theme")
    [[ -z "$choice" || "$choice" == "◄ Back to Main Menu" ]] && return
    
    [[ "$choice" =~ 📁 ]] && continue
    
    if ! [[ "$choice" =~ (🎵|📹) ]]; then
      continue
    fi
    
    # Find which file was selected
    local selected_idx=-1
    local selectable_idx=0
    
    for i in "${!display_items[@]}"; do
      if [[ "${display_items[$i]}" == "$choice" ]]; then
        # Count selectable items before this one
        for ((j=0; j<i; j++)); do
          if [[ "${display_items[$j]}" =~ (🎵|📹) ]]; then
            ((selectable_idx++))
          fi
        done
        selected_idx=$selectable_idx
        break
      fi
    done
    
    if [[ $selected_idx -ge 0 && $selected_idx -lt ${#all_files[@]} ]]; then
      local selected_file="${all_files[$selected_idx]}"
      
      if [[ -f "$selected_file" ]]; then
        local action=$(printf "▶️ Play\n📂 Open Folder\n🗑️ Delete\n◄ Back" | rofi -i -dmenu -p "⬇️ $(basename "$selected_file")" -config "$rofi_theme_menu")
        
        case "$action" in
          "▶️ Play")
            if [[ "$selected_file" =~ \.(mp3|m4a|flac)$ ]]; then
              ensure_socket_clean
              stop_music
              notification normal "🎵 Playing" "$(basename "$selected_file" | sed 's/\.[^.]*$//')"
              cache_selection "$(basename "$selected_file" | sed 's/\.[^.]*$//')" "$selected_file"
              mpv --profile=audio --vid=no "$selected_file" --input-ipc-server="$mpv_socket" >/dev/null 2>&1 &
              wait_for_socket
              start_endfile_watcher
            elif [[ "$selected_file" =~ \.(mp4|mkv|webm)$ ]]; then
              notification normal "📹 Playing" "$(basename "$selected_file" | sed 's/\.[^.]*$//')"
              nohup mpv "$selected_file" >/dev/null 2>&1 &
            fi
            ;;
          "📂 Open Folder")
            if [[ "${file_types[$selected_idx]}" == "audio" ]]; then
              xdg-open "$downloads_dir" >/dev/null 2>&1 &
            else
              xdg-open "$video_downloads_dir" >/dev/null 2>&1 &
            fi
            ;;
          "🗑️ Delete")
            rm -f "$selected_file"
            notify_success "Deleted: $(basename "$selected_file")"
            ;;
        esac
      fi
    fi
  done
}

# ═══════════════════════════════════════════════════════════════════
# ⚙️ SETTINGS
# ═══════════════════════════════════════════════════════════════════

show_settings() {
  while true; do
    local autoplay_status="$([ $AUTOPLAY -eq 1 ] && echo '✅ On' || echo '❌ Off')"
    
    local options=(
      "🔁 Autoplay: $autoplay_status"
      "🗑️ Clear History"
      "📋 Clear Queue"
      "🧹 Clear Cache"
      "📹 View Download Logs"
      "📝 View System Logs"
      "ℹ️ About RofiBEATS"
      "◄ Back to Main Menu"
    )
    
    local choice=$(printf "%s\n" "${options[@]}" | rofi -i -dmenu -p "⚙️ Settings" -config "$rofi_theme_menu")
    [[ -z "$choice" || "$choice" == "◄ Back to Main Menu" ]] && return
    
    case "$choice" in
      "🔁 Autoplay"*)
        AUTOPLAY=$((1 - AUTOPLAY))
        notify_info "Autoplay: $([ $AUTOPLAY -eq 1 ] && echo 'Enabled' || echo 'Disabled')"
        ;;
      "🗑️ Clear History")
        clear_history
        ;;
      "📋 Clear Queue")
        rm -f "$queue_file"
        notify_info "Queue cleared"
        ;;
      "🧹 Clear Cache")
        rm -rf "${cache_dir:?}"/* 2>/dev/null || true
        notify_info "Cache cleared"
        ;;
      "📹 View Download Logs")
        if [[ -f "$download_log" ]]; then
          tail -n 30 "$download_log" | rofi -i -dmenu -p "📹 Download Logs" -config "$rofi_theme_menu" >/dev/null
        else
          notify_info "No downloads yet"
        fi
        ;;
      "📝 View System Logs")
        tail -n 50 "$log_file" | rofi -i -dmenu -p "📝 System Logs" -config "$rofi_theme_menu" >/dev/null
        ;;
      "ℹ️ About RofiBEATS")
        local about_info="🎵 RofiBEATS v$SCRIPT_VERSION
Advanced Music Player for Rofi

✨ Features:
✓ YouTube & Online Streaming
✓ Local Music Library
✓ Favorites & History
✓ Queue Management
✓ Video Download Support
✓ Audio Download (MP3)
✓ Browser Integration
✓ Seek Control
✓ Quality Selection

📍 Directories:
Music: $mDIR
Videos: $video_downloads_dir
Cache: $cache_dir"
        echo -e "$about_info" | rofi -i -dmenu -p "ℹ️ About" -config "$rofi_theme_menu" >/dev/null
        ;;
    esac
  done
}

# ═══════════════════════════════════════════════════════════════════
# 🎼 MAIN MENU & LOOP
# ═══════════════════════════════════════════════════════════════════

main_menu() {
  while true; do
    local music_status=""
    if music_playing; then
      local track_info=$(get_current_track_info)
      local current_title="${track_info%%|*}"
      current_title="${current_title:0:25}"
      [[ ${#current_title} -gt 25 ]] && current_title="${current_title}..."
      music_status="🎵 $current_title"
    else
      music_status="🎵 Not Playing"
    fi
    
    local queue_indicator=""
    [[ -s "$queue_file" ]] && queue_indicator=" ($(wc -l < "$queue_file"))"
    
    local options=(
      "🔎 Search YouTube & Play"
      "🎵 Now Playing"
      "⭐ Favorites"
      "📜 History"
      "📋 Queue$queue_indicator"
      "🌐 Online Stations"
      "🎧 Local Music"
      "🔀 Shuffle Play"
      "⬇️ Downloaded Tracks"
      "⚙️ Settings"
      "⏹️ Stop Playback"
      "❌ Exit"
    )
    
    local user_choice=$(printf "%s\n" "${options[@]}" | rofi -dmenu -p "$music_status" -config "$rofi_theme_menu")
    
    [[ -z "$user_choice" || "$user_choice" == "❌ Exit" ]] && exit 0
    
    case "$user_choice" in
      "🔎 Search YouTube & Play") search_and_play_youtube ;;
      "🎵 Now Playing") show_now_playing ;;
      "⭐ Favorites") show_favorites ;;
      "📜 History") show_history ;;
      "📋 Queue"*) show_queue ;;
      "🌐 Online Stations") play_online_music ;;
      "🎧 Local Music") play_local_music ;;
      "🔀 Shuffle Play") shuffle_local_music ;;
      "⬇️ Downloaded Tracks") list_downloads ;;
      "⚙️ Settings") show_settings ;;
      "⏹️ Stop Playback") stop_music notify ;;
    esac
  done
}

# ═══════════════════════════════════════════════════════════════════
# 🚀 STARTUP & INITIALIZATION
# ═══════════════════════════════════════════════════════════════════

initialize_system() {
  log_info "RofiBEATS v$SCRIPT_VERSION started"
  
  local required_tools=(rofi mpv yt-dlp socat notify-send jq)
  for tool in "${required_tools[@]}"; do
    if ! command -v "$tool" &>/dev/null; then
      notify_error "Missing dependency: $tool"
      log_error "Missing dependency: $tool"
      exit 1
    fi
  done
  
  # Load cached URL/title
  load_cached_url
  
  if [[ ! -f "$config_file" ]]; then
    cat > "$config_file" << 'EOF'
AUTOPLAY=1
SHUFFLE_ENABLED=0
REPEAT_MODE="none"
VOLUME_LEVEL=100
DOWNLOAD_QUALITY="best"
EOF
  fi
  
  source "$config_file" 2>/dev/null || true
  
  log_info "System initialized successfully"
  log_info "Browser detected: ${DEFAULT_BROWSER:-None}"
}

# ═══════════════════════════════════════════════════════════════════
# ⏁ ENTRY POINT
# ═══════════════════════════════════════════════════════════════════

handle_args() {
  case "$1" in
    "--next")
      initialize_system >/dev/null
      next_track
      ;;
    "--prev")
      initialize_system >/dev/null
      previous_track
      ;;
    "--play-pause")
      initialize_system >/dev/null
      toggle_pause
      ;;
    "--stop")
      initialize_system >/dev/null
      stop_music notify
      ;;
    *)
      initialize_system
      main_menu
      ;;
  esac
}

if [[ "${BASH_SOURCE}" == "${0}" ]]; then
  handle_args "$1"
fi

# End of RofiBEATS v3.6.0
