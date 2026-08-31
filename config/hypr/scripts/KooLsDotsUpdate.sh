#!/usr/bin/env bash
# ==================================================
#  KoolDots (2026)
#  Project URL: https://github.com/LinuxBeginnings
#  License: GNU GPLv3
#  SPDX-License-Identifier: GPL-3.0-or-later
# ==================================================
# Checks for updates to KooL Hyprland dotfiles by comparing local version
# to upstream GitHub repository.

set -euo pipefail

# Local Paths & URLs
config_dir="${XDG_CONFIG_HOME:-$HOME/.config}/hypr"
env_lua="$config_dir/lua/env.lua"
iDIR="${XDG_CONFIG_HOME:-$HOME/.config}/swaync/images"
CHANGELOG_URL="https://github.com/LinuxBeginnings/Hyprland-Dots/CHANGELOG.md"
REMOTE_ENV_URL="https://raw.githubusercontent.com/LinuxBeginnings/Hyprland-Dots/main/config/hypr/lua/env.lua"
REMOTE_API_CONTENTS="https://api.github.com/repos/LinuxBeginnings/Hyprland-Dots/contents/config/hypr"
REMOTE_TREE_URL="https://github.com/LinuxBeginnings/Hyprland-Dots/tree/main/config/hypr"

# Resolve notification icon
get_icon() {
  local preferred="$1"
  if [[ -f "$iDIR/$preferred" ]]; then
    printf '%s' "$iDIR/$preferred"
  elif [[ -f "$iDIR/ja.png" ]]; then
    printf '%s' "$iDIR/ja.png"
  else
    printf '%s' "dialog-information"
  fi
}

send_notification() {
  local icon="$1"
  local title="$2"
  local message="$3"
  local urgency="${4:-normal}"
  if command -v notify-send >/dev/null 2>&1; then
    notify-send -i "$icon" -u "$urgency" "$title" "$message" 2>/dev/null || true
  fi
}

# Check for curl
if ! command -v curl >/dev/null 2>&1; then
  send_notification "$(get_icon "error.png")" "Error" "curl is required to check for updates." "critical"
  echo "Error: curl not found. Please install curl." >&2
  exit 1
fi

# 1. Detect Local Version
# Precedence:
# 1) DOTS_VERSION in ~/.config/hypr/lua/env.lua
# 2) $DOTS_VERSION environment variable (if exported)
# 3) ~/.config/hypr/vx.x.x.x file
local_version=""

if [[ -f "$env_lua" ]]; then
  local_version=$(sed -n -E 's/^[[:space:]]*hl\.env\([[:space:]]*["'\'']DOTS_VERSION["'\''][[:space:]]*,[[:space:]]*["'\'']([^"'\'']+)["'\''].*$/\1/p' "$env_lua" | head -n1 || true)
  if [[ -z "$local_version" ]]; then
    local_version=$(sed -n -E 's/^[[:space:]]*DOTS_VERSION[[:space:]]*=[[:space:]]*["'\'']([^"'\'']+)["'\''].*$/\1/p' "$env_lua" | head -n1 || true)
  fi
fi

if [[ -z "$local_version" && -n "${DOTS_VERSION:-}" ]]; then
  local_version="$DOTS_VERSION"
fi

if [[ -z "$local_version" && -d "$config_dir" ]]; then
  vfile=$(find "$config_dir" -maxdepth 1 -name 'v*' -printf '%f\n' 2>/dev/null | sort -V | tail -n 1 || true)
  if [[ -n "$vfile" ]]; then
    local_version="${vfile#v}"
  fi
fi

# Strip leading 'v' if present
local_version="${local_version#v}"

if [[ -z "$local_version" ]]; then
  send_notification "$(get_icon "error.png")" "KooL Hyprland" "Unable to detect installed dotfiles version." "critical"
  echo "Error: Unable to detect installed KooL's dots version in $config_dir" >&2
  exit 1
fi

# 2. Detect Remote Version
# Primary: fetch config/hypr/lua/env.lua from GitHub raw
# Fallback: GitHub Contents API for config/hypr or repo tree
remote_version=""

remote_env_content=$(curl -fsSL -m 10 -A "Mozilla/5.0" "$REMOTE_ENV_URL" 2>/dev/null || true)
if [[ -n "$remote_env_content" ]]; then
  remote_version=$(printf '%s\n' "$remote_env_content" | sed -n -E 's/^[[:space:]]*hl\.env\([[:space:]]*["'\'']DOTS_VERSION["'\''][[:space:]]*,[[:space:]]*["'\'']([^"'\'']+)["'\''].*$/\1/p' | head -n1 || true)
  if [[ -z "$remote_version" ]]; then
    remote_version=$(printf '%s\n' "$remote_env_content" | sed -n -E 's/^[[:space:]]*DOTS_VERSION[[:space:]]*=[[:space:]]*["'\'']([^"'\'']+)["'\''].*$/\1/p' | head -n1 || true)
  fi
fi

if [[ -z "$remote_version" ]]; then
  api_response=$(curl -fsSL -m 10 -A "Mozilla/5.0" "$REMOTE_API_CONTENTS" 2>/dev/null || true)
  if [[ -n "$api_response" ]]; then
    remote_version=$(printf '%s\n' "$api_response" | grep -o '"name": *"v[0-9][0-9.]*"' | sed -E 's/.*"v([0-9][0-9.]*)".*/\1/' | sort -V | tail -n1 || true)
  fi
fi

if [[ -z "$remote_version" ]]; then
  tree_response=$(curl -fsSL -m 10 -A "Mozilla/5.0" "$REMOTE_TREE_URL" 2>/dev/null || true)
  if [[ -n "$tree_response" ]]; then
    remote_version=$(printf '%s\n' "$tree_response" | grep -o 'v[0-9]\+\.[0-9]\+\.[0-9]\+\(\.[0-9]\+\)\?' | sed 's/^v//' | sort -V | tail -n1 || true)
  fi
fi

remote_version="${remote_version#v}"

if [[ -z "$remote_version" ]]; then
  send_notification "$(get_icon "error.png")" "KooL Hyprland" "Unable to determine latest GitHub version." "critical"
  echo "Error: Unable to determine latest version from GitHub." >&2
  exit 1
fi

# 3. Compare Local and Remote Versions
highest_version=$(printf '%s\n%s\n' "$local_version" "$remote_version" | sort -V | tail -n1)

if [[ "$highest_version" == "$local_version" ]]; then
  # No update available
  send_notification "$(get_icon "note.png")" "KooL Hyprland" "Current installed version v${local_version} is most recent" "normal"
  echo "Current installed version v${local_version} is most recent"
  exit 0
fi

# 4. Update is Available -> Display Window with Current Version, Detected Version, Link, and OK Button
send_notification "$(get_icon "ja.png")" "Update Available!" "Current: v${local_version} -> Latest: v${remote_version}" "normal"
echo "Update available: Installed v${local_version} -> Latest v${remote_version}"

# Display dialog window
show_update_window() {
  local cur_v="v${local_version}"
  local new_v="v${remote_version}"

  # Priority 1: YAD (if installed)
  if command -v yad >/dev/null 2>&1; then
    local yad_icon
    yad_icon=$(get_icon "ja.png")
    local yad_text="<b><big>KooL Hyprland Dots Update Available!</big></b>\n\n"
    yad_text+="<b>Current installed version:</b> ${cur_v}\n"
    yad_text+="<b>Most current version detected:</b> ${new_v}\n\n"
    yad_text+="<b>Changelog:</b>\n<a href=\"${CHANGELOG_URL}\">${CHANGELOG_URL}</a>\n"

    yad --center \
      --title="KooL Hyprland Update" \
      --window-icon="$yad_icon" \
      --text="$yad_text" \
      --button="View Changelog:2" \
      --button="OK:0" \
      --width=480 \
      --fixed || true

    local ret=$?
    if [[ $ret -eq 2 ]]; then
      if command -v xdg-open >/dev/null 2>&1; then
        xdg-open "$CHANGELOG_URL" >/dev/null 2>&1 &
      fi
    fi
    return 0
  fi

  # Priority 2: Rofi (guaranteed available in KooL Hyprland)
  if command -v rofi >/dev/null 2>&1; then
    "${XDG_CONFIG_HOME:-$HOME/.config}/hypr/scripts/RofiFocusedWallpaperLink.sh" >/dev/null 2>&1 || true
    
    local rofi_msg="<b>Update Available for KooL Hyprland Dots!</b>\n\n"
    rofi_msg+="• Current installed version:      <b>${cur_v}</b>\n"
    rofi_msg+="• Most current version detected:  <b>${new_v}</b>\n\n"
    rofi_msg+="Changelog: ${CHANGELOG_URL}"

    local opt_changelog="🌐 View Changelog (Opens in Browser)"
    local opt_ok=" OK (Close)"

    local choice
    choice=$(printf '%s\n%s\n' "$opt_changelog" "$opt_ok" | rofi -dmenu -i -p "Update Available" -mesg "$rofi_msg" 2>/dev/null || true)

    if [[ "$choice" == "$opt_changelog" ]]; then
      if command -v xdg-open >/dev/null 2>&1; then
        xdg-open "$CHANGELOG_URL" >/dev/null 2>&1 &
      fi
    fi
    return 0
  fi

  # Priority 3: Zenity (if installed)
  if command -v zenity >/dev/null 2>&1; then
    zenity --info \
      --title="KooL Hyprland Update" \
      --text="Update available for KooL Hyprland Dots!\n\nCurrent installed version: ${cur_v}\nMost current version detected: ${new_v}\n\nChangelog:\n${CHANGELOG_URL}" \
      --ok-label="OK" 2>/dev/null || true
    return 0
  fi
}

show_update_window
