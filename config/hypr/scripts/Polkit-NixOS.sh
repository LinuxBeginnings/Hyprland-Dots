#!/usr/bin/env bash
# ==================================================
#  KoolDots (2026)
#  Project URL: https://github.com/LinuxBeginnings
#  License: GNU GPLv3
#  SPDX-License-Identifier: GPL-3.0-or-later
# ==================================================
# For NixOS starting of polkit agents. Prefer xfce4-polkit, fallback to polkit-gnome.

# Find all xfce4-polkit executables in the Nix store
xfce_polkit_paths=$(find /nix/store -name 'xfce4-polkit' -type f 2>/dev/null)

for xfce_polkit_path in $xfce_polkit_paths; do
  # Extract the directory containing the executable
  xfce_polkit_dir=$(dirname "$xfce_polkit_path")

  # Check if the executable is valid and exists
  if [ -x "$xfce_polkit_dir/xfce4-polkit" ]; then
    # Start the xfce4-polkit Authentication Agent
    "$xfce_polkit_dir/xfce4-polkit" &
    exit 0
  fi
done

# Find all polkit-gnome executables in the Nix store
polkit_gnome_paths=$(find /nix/store -name 'polkit-gnome-authentication-agent-1' -type f 2>/dev/null)

for polkit_gnome_path in $polkit_gnome_paths; do
  # Extract the directory containing the executable
  polkit_gnome_dir=$(dirname "$polkit_gnome_path")

  # Check if the executable is valid and exists
  if [ -x "$polkit_gnome_dir/polkit-gnome-authentication-agent-1" ]; then
    # Start the Polkit-GNOME Authentication Agent
    "$polkit_gnome_dir/polkit-gnome-authentication-agent-1" &
    exit 0
  fi
done

# If no valid executable is found, report an error
echo "No valid polkit authentication agent executable found."
