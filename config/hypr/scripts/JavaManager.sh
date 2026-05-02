#!/usr/bin/env bash

# ==================================================
#  KoolDots (2026)
#  Project URL: https://github.com/LinuxBeginnings
#  License: GNU GPLv3
#  SPDX-License-Identifier: GPL-3.0-or-later
# ==================================================
# Script to manage Java runtimes
# Based on script from https://github.com/jmhorcas
# Submitted to KoolDots >https://github.com/LinuxBeginnings/Hyprland-Dots/issues/49

# --- 1. Icons (Nerd Fonts) ---
ICON_JAVA=""
ICON_ACTIVE="󰄬"
ICON_INSTALLED=""
ICON_REMOTE=" "

# --- 2. Distro detection ---
if [ -r /etc/os-release ]; then
  . /etc/os-release
fi

DISTRO="unknown"
case "${ID:-}" in
arch) DISTRO="arch" ;;
debian | ubuntu | linuxmint) DISTRO="debian" ;;
fedora) DISTRO="fedora" ;;
opensuse* | sles) DISTRO="opensuse" ;;
esac

if [ "$DISTRO" = "unknown" ] && [ -n "${ID_LIKE:-}" ]; then
  case "$ID_LIKE" in
  *arch*) DISTRO="arch" ;;
  *debian* | *ubuntu*) DISTRO="debian" ;;
  *fedora*) DISTRO="fedora" ;;
  *suse*) DISTRO="opensuse" ;;
  esac
fi

if [ "$DISTRO" = "unknown" ]; then
  notify-send "Error" "Unsupported distro for now."
  exit 1
fi

# --- 3. Package helpers ---
list_installed_pkgs() {
  case "$DISTRO" in
  arch) pacman -Qq | grep -E '^jdk.*-openjdk$' ;;
  debian) dpkg -l 'openjdk-*-jdk' 2>/dev/null | awk '/^ii/ {print $2}' ;;
  fedora | opensuse) rpm -qa | grep -E '^java-[0-9]+-openjdk' ;;
  esac
}

list_available_pkgs() {
  case "$DISTRO" in
  arch) pacman -Ssq '^jdk.*-openjdk$' | sort -u ;;
  debian) apt-cache search openjdk- | awk '{print $1}' | grep -E '^openjdk-[0-9]+-jdk$' | sort -u ;;
  fedora) dnf -q repoquery --qf '%{name}' 'java-*-openjdk' 2>/dev/null | grep -E '^java-[0-9]+-openjdk' | sort -u ;;
  opensuse) zypper -n search -s 'java-*-openjdk' 2>/dev/null | awk -F'|' '{print $2}' | xargs -n1 | grep -E '^java-[0-9]+-openjdk' | sort -u ;;
  esac
}

pkg_description() {
  local pkg="$1"
  case "$DISTRO" in
  arch) pacman -Si "$pkg" | grep "Description" | cut -d ':' -f2- | head -n 1 | xargs ;;
  debian) apt-cache show "$pkg" 2>/dev/null | awk -F': ' '/^Description/ {print $2; exit}' ;;
  fedora) dnf info -q "$pkg" 2>/dev/null | awk -F': ' '/^Summary/ {print $2; exit}' ;;
  opensuse) zypper -n info "$pkg" 2>/dev/null | awk -F': ' '/^Summary/ {print $2; exit}' ;;
  esac
}

get_active_version_raw() {
  case "$DISTRO" in
  arch) archlinux-java get ;;
  *) java -version 2>&1 | awk -F\" '/version/ {print $2; exit}' ;;
  esac
}

get_active_version_num() {
  local raw="$1"
  echo "$raw" | grep -oE '[0-9]+' | head -n1
}

list_java_alternatives() {
  case "$DISTRO" in
  debian) update-alternatives --list java 2>/dev/null ;;
  fedora | opensuse) alternatives --list java 2>/dev/null ;;
  *) echo "" ;;
  esac
}

set_default_java() {
  local sel_num="$1"
  case "$DISTRO" in
  arch)
    local java_env
    java_env=$(archlinux-java status | grep "java-$sel_num" | awk '{print $1}' | head -n 1)
    if [ -n "$java_env" ]; then
      notify-send "Java" "Setting $java_env as default..."
      pkexec archlinux-java set "$java_env"
    else
      notify-send "Error" "Version $sel_num is not installed. Install it first."
    fi
    ;;
  debian | fedora | opensuse)
    local alt_path
    alt_path=$(list_java_alternatives | grep -E "java-$sel_num|jdk-$sel_num|openjdk-$sel_num" | head -n1)
    if [ -n "$alt_path" ]; then
      notify-send "Java" "Setting Java $sel_num as default..."
      if [ "$DISTRO" = "debian" ]; then
        pkexec update-alternatives --set java "$alt_path"
      else
        pkexec alternatives --set java "$alt_path"
      fi
    else
      notify-send "Error" "Version $sel_num is not installed. Install it first."
    fi
    ;;
  esac
}

install_pkg() {
  local pkg="$1"
  case "$DISTRO" in
  arch) kitty -e sudo pacman -S "$pkg" ;;
  debian) kitty -e sudo apt install "$pkg" ;;
  fedora) kitty -e sudo dnf install "$pkg" ;;
  opensuse) kitty -e sudo zypper install "$pkg" ;;
  esac
}

remove_pkg() {
  local pkg="$1"
  case "$DISTRO" in
  arch) kitty -e sudo pacman -Rs "$pkg" ;;
  debian) kitty -e sudo apt remove "$pkg" ;;
  fedora) kitty -e sudo dnf remove "$pkg" ;;
  opensuse) kitty -e sudo zypper remove "$pkg" ;;
  esac
}

# --- 4. Initial data ---
INSTALLED_PKGS=$(list_installed_pkgs)
TEMP_ALL=$(list_available_pkgs)

ACTIVE_VERSION_RAW=$(get_active_version_raw)
ACTIVE_VERSION_NUM=$(get_active_version_num "$ACTIVE_VERSION_RAW")

if [ "$DISTRO" = "arch" ]; then
  TEMP_ALL_SYSTEM=$(archlinux-java status)
  LATEST_VERSION=$(echo "$TEMP_ALL" "$TEMP_ALL_SYSTEM" | grep -oE '[0-9]+' | sort -nr | head -n1)
else
  LATEST_VERSION=$(echo "$TEMP_ALL" | grep -oE '[0-9]+' | sort -nr | head -n1)
fi

ALL_AVAILABLE=$(echo "$TEMP_ALL" | awk -v lv="$LATEST_VERSION" '{
    v=$0; gsub(/[^0-9]/,"",v);
    if(v=="") v=lv+1;
    print v " " $0
}' | sort -nr | cut -d' ' -f2-)

# --- 5. Functions ---
get_version_num() {
  local pkg="$1"
  local v=$(echo "$pkg" | grep -oE '[0-9]+')
  # If there is not a number, it is the "latest"
  if [ -z "$v" ]; then
    echo "$LATEST_VERSION"
  else
    echo "$v"
  fi
}

generate_list() {
  for pkg in $ALL_AVAILABLE; do
    DESC=$(pkg_description "$pkg")

    VERSION=$(get_version_num "$pkg")
    ICON="$ICON_REMOTE"
    # We use a temporary variable for the icon to avoid overwriting ICON_REMOTE
    DISPLAY_ICON="$ICON_REMOTE"

    # 1. Is it installed?
    if echo "$INSTALLED_PKGS" | grep -q "^$pkg$"; then
      DISPLAY_ICON="$ICON_INSTALLED"
    fi

    # 2. Is it the active one?
    # We compare if the number matches OR if the raw name matches
    if [[ "$VERSION" == "$ACTIVE_VERSION_NUM" ]] || [[ "$pkg" == "$ACTIVE_VERSION_RAW" ]]; then
      DISPLAY_ICON="$ICON_ACTIVE"
    fi

    # Ensure that if the icon is empty (remote) it maintains the space
    [ -z "$DISPLAY_ICON" ] && DISPLAY_ICON="  "

    printf "%s %s %s │ %s\n" "$ICON_JAVA" "$DISPLAY_ICON" "$DESC" "$pkg"
  done
}

# --- 6. rofi ---
THEME="$HOME/.config/rofi/config.rasi"

SELECTION=$(generate_list | rofi -dmenu -i \
  -p "󰒓 Java" \
  -config "$THEME" \
  -theme-str '
    window { width: 1000px; }
    inputbar { children: [ "prompt", "textbox-prompt-colon", "entry" ]; }
    prompt { background-color: @selected; text-color: @background; padding: 4px 8px; border-radius: 4px; }
    ' \
  -kb-custom-1 "Alt+i" \
  -kb-custom-2 "Alt+r" \
  -mesg "<b>$ICON_ACTIVE</b> Default | <b>$ICON_INSTALLED</b> Installed | <b>Enter:</b> Set default | <b>Alt+I:</b> Install | <b>Alt+R:</b> Remove")

EXIT_CODE=$?
[ -z "$SELECTION" ] && exit 0

# --- 7. Clean selection ---
# 1. Extract the package name from the right side of the │ separator
PKG_NAME=$(echo "$SELECTION" | awk -F'│' '{print $2}' | xargs | awk '{print $1}')

# 2. Get the real number contained in the name (if it exists)
SEL_RAW_NUM=$(echo "$PKG_NAME" | grep -oE '[0-9]+')

# If it doesn't have a value (it's the latest package), assign LATEST_VERSION
if [ -z "$SEL_RAW_NUM" ]; then
  SEL_RAW_NUM="$LATEST_VERSION"
fi

# --- 8. Actions ---
case $EXIT_CODE in
0) # SET DEFAULT
  set_default_java "$SEL_RAW_NUM"
  ;;
10) # INSTALL
  install_pkg "$PKG_NAME"
  ;;
11) # REMOVE
  remove_pkg "$PKG_NAME"
  ;;
esac
