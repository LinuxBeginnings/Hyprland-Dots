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
# Qt Quick Controls style safety: enable Hyprland style only when module exists.
adjust_qt_quick_controls_style() {
  local log="$1"
  local source_hypr_dir="config/hypr"
  local target_hypr_dir="${XDG_CONFIG_HOME:-$HOME/.config}/hypr"
  local style="Basic"
  local qt_style_override="Fusion"
  local has_kvantum_qml=0
  local set_env_conf_vars
  local set_env_lua_vars

  set_env_conf_vars() {
    local file="$1"
    [ -f "$file" ] || return 0

    if grep -q '^env = QT_QUICK_CONTROLS_STYLE,' "$file"; then
      sed -i -E "s|^env = QT_QUICK_CONTROLS_STYLE,.*$|env = QT_QUICK_CONTROLS_STYLE,${style}|" "$file"
    else
      printf '\nenv = QT_QUICK_CONTROLS_STYLE,%s\n' "$style" >>"$file"
    fi

    if grep -q '^env = QT_STYLE_OVERRIDE,' "$file"; then
      sed -i -E "s|^env = QT_STYLE_OVERRIDE,.*$|env = QT_STYLE_OVERRIDE,${qt_style_override}|" "$file"
    else
      printf 'env = QT_STYLE_OVERRIDE,%s\n' "$qt_style_override" >>"$file"
    fi
  }

  set_env_lua_vars() {
    local file="$1"
    [ -f "$file" ] || return 0

    if grep -q '^hl\.env("QT_QUICK_CONTROLS_STYLE",' "$file"; then
      sed -i -E "s|^hl\\.env\\(\"QT_QUICK_CONTROLS_STYLE\", \".*\"\\)$|hl.env(\"QT_QUICK_CONTROLS_STYLE\", \"${style}\")|" "$file"
    else
      printf '\nhl.env("QT_QUICK_CONTROLS_STYLE", "%s")\n' "$style" >>"$file"
    fi

    if grep -q '^hl\.env("QT_STYLE_OVERRIDE",' "$file"; then
      sed -i -E "s|^hl\\.env\\(\"QT_STYLE_OVERRIDE\", \".*\"\\)$|hl.env(\"QT_STYLE_OVERRIDE\", \"${qt_style_override}\")|" "$file"
    else
      printf 'hl.env("QT_STYLE_OVERRIDE", "%s")\n' "$qt_style_override" >>"$file"
    fi
  }

  if find /usr/lib /usr/lib64 /usr/share -type d -path '*/qml/*/org/hyprland/style' -print -quit 2>/dev/null | grep -q .; then
    style="org.hyprland.style"
  elif command -v dpkg >/dev/null 2>&1 && dpkg -s qml6-module-org-hyprland-style >/dev/null 2>&1; then
    style="org.hyprland.style"
  fi

  if find /usr/lib /usr/lib64 /usr/share -type d -path '*/qml/*/kvantum' -print -quit 2>/dev/null | grep -q .; then
    has_kvantum_qml=1
    qt_style_override="kvantum"
  fi

  set_env_conf_vars "$source_hypr_dir/configs/ENVariables.conf"
  set_env_lua_vars "$source_hypr_dir/lua/env.lua"
  set_env_lua_vars "$source_hypr_dir/configs/system_env.lua"

  set_env_conf_vars "$target_hypr_dir/configs/ENVariables.conf"
  set_env_lua_vars "$target_hypr_dir/lua/env.lua"
  set_env_lua_vars "$target_hypr_dir/configs/system_env.lua"

  if [ "$style" = "org.hyprland.style" ]; then
    echo "${INFO:-[INFO]} hyprland Qt style module detected. Using QT_QUICK_CONTROLS_STYLE=$style" 2>&1 | tee -a "$log" || true
  else
    echo "${WARN:-[WARN]} hyprland Qt style module not found. Using QT_QUICK_CONTROLS_STYLE=Basic to avoid Qt app crashes." 2>&1 | tee -a "$log" || true
  fi
  if [ "$has_kvantum_qml" -eq 1 ]; then
    echo "${INFO:-[INFO]} Kvantum QML module detected. Using QT_STYLE_OVERRIDE=kvantum" 2>&1 | tee -a "$log" || true
  else
    echo "${WARN:-[WARN]} Kvantum QML module not found. Using QT_STYLE_OVERRIDE=Fusion as fallback." 2>&1 | tee -a "$log" || true
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
