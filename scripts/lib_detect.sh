#!/usr/bin/env bash
# ==================================================
#  KoolDots (2026)
#  Project URL: https://github.com/LinuxBeginnings
#  License: GNU GPLv3
#  SPDX-License-Identifier: GPL-3.0-or-later
# ==================================================
# Detection and environment adjustment helpers shared by copy.sh.

# Nvidia tweaks: uncomments envs and adjusts hardware cursor setting.
detect_nvidia_adjust() {
  local log="$1"
  local pci_info
  local has_nvidia=0
  local has_intel=0
  local has_amd=0
  pci_info="$(lspci -k | grep -A 2 -E "(VGA|3D)" || true)"
  if echo "$pci_info" | grep -iq nvidia; then
    has_nvidia=1
  fi
  if echo "$pci_info" | grep -iq intel; then
    has_intel=1
  fi
  if echo "$pci_info" | grep -Eiq 'amd|advanced micro devices|ati'; then
    has_amd=1
  fi
  if [ "$has_nvidia" -eq 1 ]; then
    echo "${INFO:-[INFO]} Nvidia GPU detected. Setting up proper env's and configs" 2>&1 | tee -a "$log" || true
    sed -i '/env = LIBVA_DRIVER_NAME,nvidia/s/^#//' config/hypr/configs/ENVariables.conf
    sed -i '/env = __GLX_VENDOR_LIBRARY_NAME,nvidia/s/^#//' config/hypr/configs/ENVariables.conf
    sed -i '/env = NVD_BACKEND,direct/s/^#//' config/hypr/configs/ENVariables.conf
    sed -i '/env = GSK_RENDERER,ngl/s/^#//' config/hypr/configs/ENVariables.conf
    if [ "$has_intel" -eq 1 ] || [ "$has_amd" -eq 1 ]; then
      echo "${INFO:-[INFO]} Hybrid GPU detected (Intel/NVIDIA or AMD/NVIDIA). Applying cursor handoff fixes." 2>&1 | tee -a "$log" || true
      sed -i -E 's/^([[:space:]]*no_hardware_cursors[[:space:]]*=[[:space:]]*)[0-9]+/\1 0/' config/hypr/configs/SystemSettings.conf
      sed -i -E 's/^([[:space:]]*no_hardware_cursors[[:space:]]*=[[:space:]]*)[0-9]+/\1 0/' config/hypr/lua/settings.lua
      sed -i '/hyprctl setcursor/s/^#//' config/hypr/configs/Startup_Apps.conf
    else
      sed -i -E 's/^([[:space:]]*no_hardware_cursors[[:space:]]*=[[:space:]]*)[0-9]+/\1 1/' config/hypr/configs/SystemSettings.conf
      sed -i -E 's/^([[:space:]]*no_hardware_cursors[[:space:]]*=[[:space:]]*)[0-9]+/\1 1/' config/hypr/lua/settings.lua
    fi
  fi
}

# VM tweaks: enable software renderer envs and virtual monitor defaults.
detect_vm_adjust() {
  local log="$1"
  if hostnamectl | grep -q 'Chassis: vm'; then
    echo "${INFO:-[INFO]} System is running in a virtual machine. Setting up proper env's and configs" 2>&1 | tee -a "$log" || true
    sed -i 's/^\([[:space:]]*no_hardware_cursors[[:space:]]*=[[:space:]]*\)2/\1 1/' config/hypr/configs/SystemSettings.conf
    sed -i '/env = WLR_RENDERER_ALLOW_SOFTWARE,1/s/^#//' config/hypr/configs/ENVariables.conf
    sed -i '/monitor = Virtual-1, 1920x1080@60,auto,1/s/^#//' config/hypr/monitors.conf
  fi
}

# NixOS tweaks: ensure polkit overlay is enabled and default disabled.
detect_nixos_adjust() {
  local log="$1"
  if hostnamectl | grep -q 'Operating System: NixOS'; then
    echo "${INFO:-[INFO]} NixOS Distro Detected. Setting up proper env's and configs." 2>&1 | tee -a "$log" || true
    local OVERLAY_SA="config/hypr/configs/Startup_Apps.conf"
    local DISABLE_SA="config/hypr/configs/Startup_Apps.disable"
    mkdir -p "$(dirname "$OVERLAY_SA")"
    touch "$OVERLAY_SA" "$DISABLE_SA"
    grep -qx 'exec-once = $scriptsDir/Polkit-NixOS.sh' "$OVERLAY_SA" || echo 'exec-once = $scriptsDir/Polkit-NixOS.sh' >>"$OVERLAY_SA"
    grep -qx '\$scriptsDir/Polkit.sh' "$DISABLE_SA" || echo '$scriptsDir/Polkit.sh' >>"$DISABLE_SA"
  fi
}

# Decide waybar config/style based on chassis type. Echoes chosen config path.
detect_waybar_config() {
  if hostnamectl | grep -q 'Chassis: desktop'; then
    echo "desktop"
  else
    echo "laptop"
  fi
}
