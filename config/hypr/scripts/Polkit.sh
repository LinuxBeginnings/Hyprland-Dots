#!/usr/bin/env bash
# ==================================================
#  KoolDots (2026)
#  Project URL: https://github.com/LinuxBeginnings
#  License: GNU GPLv3
#  SPDX-License-Identifier: GPL-3.0-or-later
# ==================================================
# This script starts the first available Polkit agent from a list of possible locations

# Ensure Qt apps default to Wayland in a Wayland session
if [ -n "${WAYLAND_DISPLAY:-}" ] && [ -z "${QT_QPA_PLATFORM:-}" ]; then
  export QT_QPA_PLATFORM=wayland
fi

# Avoid KDE polkit agent crashing if Kvantum QML module is missing
if [ -z "${QT_QUICK_CONTROLS_STYLE:-}" ]; then
  export QT_QUICK_CONTROLS_STYLE=Basic
fi
if [ -z "${QT_STYLE_OVERRIDE:-}" ]; then
  export QT_STYLE_OVERRIDE=Fusion
fi

# List of potential Polkit agent file paths (preferred order)
polkit=(
  "/usr/libexec/xfce-polkit"
  "/usr/lib/polkit-gnome/polkit-gnome-authentication-agent-1"
  "/usr/lib/polkit-gnome-authentication-agent-1"
  "/usr/libexec/polkit-gnome-authentication-agent-1"
  "/usr/libexec/polkit-mate-authentication-agent-1"
  "/usr/lib/policykit-1-gnome/polkit-gnome-authentication-agent-1"
  "/usr/libexec/hyprpolkitagent"
  "/usr/lib/hyprpolkitagent"
  "/usr/lib/hyprpolkitagent/hyprpolkitagent"
)

executed=false

# Loop through the list of paths
for file in "${polkit[@]}"; do
  if [ -e "$file" ] && [ ! -d "$file" ]; then
    echo "Found: $file — executing..."
    exec "$file"
    executed=true
    break
  fi
done

# Fallback message if nothing executed
if [ "$executed" == false ]; then
  echo "No valid Polkit agent found. Please install one."
fi
