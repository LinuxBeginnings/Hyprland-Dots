#!/usr/bin/env bash
# ==================================================
#  KoolDots (2026)
#  Project URL: https://github.com/LinuxBeginnings
#  License: GNU GPLv3
#  SPDX-License-Identifier: GPL-3.0-or-later
# ==================================================
# App enablement and editor selection helpers.

enable_asusctl() {
  local log="$1"
  local base="${DOTFILES_DIR:-.}"
  if command -v asusctl >/dev/null 2>&1; then
    local OVERLAY_SA="$base/config/hypr/configs/Startup_Apps.conf"
    mkdir -p "$(dirname "$OVERLAY_SA")"
    touch "$OVERLAY_SA"
    grep -qx 'exec-once = rog-control-center' "$OVERLAY_SA" || echo 'exec-once = rog-control-center' >>"$OVERLAY_SA"
  fi
}

enable_blueman() {
  local log="$1"
  local base="${DOTFILES_DIR:-.}"
  if command -v blueman-applet >/dev/null 2>&1; then
    local OVERLAY_SA="$base/config/hypr/configs/Startup_Apps.conf"
    mkdir -p "$(dirname "$OVERLAY_SA")"
    touch "$OVERLAY_SA"
    grep -qx 'exec-once = blueman-applet' "$OVERLAY_SA" || echo 'exec-once = blueman-applet' >>"$OVERLAY_SA"
  fi
}

enable_ags() {
  local log="$1"
  local base="${DOTFILES_DIR:-.}"
  if command -v ags >/dev/null 2>&1; then
    echo "${INFO:-[INFO]} AGS detected - enabling in startup and refresh scripts" 2>&1 | tee -a "$log"
    local OVERLAY_SA="$base/config/hypr/configs/Startup_Apps.conf"
    mkdir -p "$(dirname "$OVERLAY_SA")"
    touch "$OVERLAY_SA"
    grep -qx 'exec-once = ags' "$OVERLAY_SA" || echo 'exec-once = ags' >>"$OVERLAY_SA"
    sed -i '/#ags -q && ags &/s/^#//' "$base/config/hypr/scripts/RefreshNoWaybar.sh"
    sed -i '/#ags -q && ags &/s/^#//' "$base/config/hypr/scripts/Refresh.sh"
  fi
}

enable_quickshell() {
  local log="$1"
  local base="${DOTFILES_DIR:-.}"
  if command -v qs >/dev/null 2>&1; then
    echo "${INFO:-[INFO]} Quickshell detected - enabling in startup and refresh scripts" 2>&1 | tee -a "$log"
    local OVERLAY_SA="$base/config/hypr/configs/Startup_Apps.conf"
    mkdir -p "$(dirname "$OVERLAY_SA")"
    touch "$OVERLAY_SA"
    grep -qx 'exec-once = qs' "$OVERLAY_SA" || echo 'exec-once = qs' >>"$OVERLAY_SA"
    sed -i '/#pkill qs && qs &/s/^#//' "$base/config/hypr/scripts/RefreshNoWaybar.sh"
    sed -i '/#pkill qs && qs &/s/^#//' "$base/config/hypr/scripts/Refresh.sh"
  fi
}

ensure_keybinds_init() {
  local log="$1"
  local base="${DOTFILES_DIR:-.}"
  local OVERLAY_SA="$base/config/hypr/configs/Startup_Apps.conf"
  mkdir -p "$(dirname "$OVERLAY_SA")"
  if ! grep -qx 'exec-once = \$scriptsDir/KeybindsLayoutInit.sh' "$OVERLAY_SA"; then
    echo 'exec-once = $scriptsDir/KeybindsLayoutInit.sh' >>"$OVERLAY_SA"
    echo "${INFO:-[INFO]} Added KeybindsLayoutInit.sh to user Startup_Apps overlay" 2>&1 | tee -a "$log"
  fi
}

install_terminal_configs() {
  local log="$1"
  local base="${DOTFILES_DIR:-.}"

  # Ghostty
  local GHOSTTY_SRC="$base/config/ghostty/config"
  local GHOSTTY_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/ghostty"
  local GHOSTTY_DEST="$GHOSTTY_DIR/config"
  if [ -f "$GHOSTTY_SRC" ]; then
    if [ -d "$GHOSTTY_DIR" ]; then
      BACKUP_DIR=$(get_backup_dirname)
      local GHOSTTY_BACKUP="$GHOSTTY_DIR-backup-$BACKUP_DIR"
      if [ ! -d "$GHOSTTY_BACKUP" ]; then
        cp -a "$GHOSTTY_DIR" "$GHOSTTY_BACKUP" 2>&1 | tee -a "$log"
        echo "${NOTE:-[NOTE]} - Backed up Ghostty config to $GHOSTTY_BACKUP." 2>&1 | tee -a "$log"
      fi
    fi
    mkdir -p "$GHOSTTY_DIR"
    install -m 0644 "$GHOSTTY_SRC" "$GHOSTTY_DEST" 2>&1 | tee -a "$log"
    if [ -f "$GHOSTTY_DIR/wallust.conf" ]; then
      sed -i -E 's/^(\\s*palette\\s*=\\s*)([0-9]{1,2}):/\\1\\2=/' "$GHOSTTY_DIR/wallust.conf" 2>&1 | tee -a "$log" || true
    fi
  else
    echo "${ERROR:-[ERROR]} - $GHOSTTY_SRC not found; skipping Ghostty config install." 2>&1 | tee -a "$log"
  fi

  # WezTerm
  local WEZTERM_SRC="$base/config/wezterm/wezterm.lua"
  local WEZTERM_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/wezterm"
  local WEZTERM_DEST="$WEZTERM_DIR/wezterm.lua"
  if [ -f "$WEZTERM_SRC" ]; then
    mkdir -p "$WEZTERM_DIR"
    install -m 0644 "$WEZTERM_SRC" "$WEZTERM_DEST" 2>&1 | tee -a "$log"
  else
    echo "${ERROR:-[ERROR]} - $WEZTERM_SRC not found; skipping WezTerm config install." 2>&1 | tee -a "$log"
  fi
}

choose_default_editor() {
  local log="$1"
  local base="${DOTFILES_DIR:-.}"
  local defaults_file="$base/config/hypr/UserConfigs/01-UserDefaults.conf"
  local editor_set=0
  set_env_default() {
    local var_name="$1"
    local value="$2"
    local note="$3"
    local tmp_file
    tmp_file=$(mktemp)

    awk -v var_name="$var_name" -v value="$value" -v note="$note" '
      BEGIN { updated = 0 }
      {
        if ($0 ~ "^[[:space:]#]*env[[:space:]]*=[[:space:]]*" var_name ",") {
          if (value != "") {
            print "env = " var_name "," value note
          } else {
            print "#env = " var_name "," note
          }
          updated = 1
        } else {
          print $0
        }
      }
      END {
        if (!updated) {
          if (value != "") {
            print "env = " var_name "," value note
          } else {
            print "#env = " var_name "," note
          }
        }
      }
    ' "$defaults_file" > "$tmp_file" && mv "$tmp_file" "$defaults_file"
  }
  update_editor() {
    local editor=$1
    set_env_default "EDITOR" "$editor" " #default editor"
    echo "${OK:-[OK]} Default editor set to ${MAGENTA:-}$editor${RESET:-}." 2>&1 | tee -a "$log"
  }
  if command -v nvim &>/dev/null; then
    printf "${INFO:-[INFO]} ${MAGENTA:-}neovim${RESET:-} is detected as installed\n"
    if ! read -r -p "${CAT:-[ACTION]} Do you want to make ${MAGENTA:-}neovim${RESET:-} the default editor? (y/N): " EDITOR_CHOICE </dev/tty; then
      :
    elif [[ "$EDITOR_CHOICE" == "y" || "$EDITOR_CHOICE" == "Y" ]]; then
      update_editor "nvim"
      editor_set=1
    fi
  fi
  printf "\n"
  if [[ "$editor_set" -eq 0 ]] && command -v vim &>/dev/null; then
    printf "${INFO:-[INFO]} ${MAGENTA:-}vim${RESET:-} is detected as installed\n"
    if read -r -p "${CAT:-[ACTION]} Do you want to make ${MAGENTA:-}vim${RESET:-} the default editor? (y/N): " EDITOR_CHOICE </dev/tty; then
      if [[ "$EDITOR_CHOICE" == "y" || "$EDITOR_CHOICE" == "Y" ]]; then
        update_editor "vim"
        editor_set=1
      fi
    fi
  fi

  local visual_choice=""
  local visual_value=""
  local prompt_visual_input=0
  if [[ -n "${VISUAL:-}" ]]; then
    printf "${INFO:-[INFO]} VISUAL is currently set to ${MAGENTA:-}%s${RESET:-}\\n" "${VISUAL}"
    if read -r -p "${CAT:-[ACTION]} Use this as Quick Settings VISUAL editor? (Y/n): " visual_choice </dev/tty; then
      if [[ "$visual_choice" != [Nn]* ]]; then
        visual_value="${VISUAL}"
      else
        prompt_visual_input=1
      fi
    fi
  else
    prompt_visual_input=1
  fi

  if [[ "$prompt_visual_input" -eq 1 ]]; then
    printf "${INFO:-[INFO]} Optional GUI editor for Quick Settings (examples: neovide, geany, code, codium).\\n"
    if read -r -p "${CAT:-[ACTION]} Enter VISUAL editor command or leave empty to skip: " visual_choice </dev/tty; then
      visual_value="$visual_choice"
    fi
  fi

  if [[ -n "$visual_value" ]]; then
    set_env_default "VISUAL" "$visual_value" " #default visual editor for quick settings (optional)"
    echo "${OK:-[OK]} VISUAL editor set to ${MAGENTA:-}$visual_value${RESET:-}." 2>&1 | tee -a "$log"
  else
    set_env_default "VISUAL" "" " #default visual editor for quick settings (optional)"
    echo "${NOTE:-[NOTE]} VISUAL editor not set (optional)." 2>&1 | tee -a "$log"
  fi
}

# Install waybar-weather on non-NixOS: prefer Arch AUR, otherwise copy prebuilt asset to /usr/bin
install_waybar_weather_binary() {
  local log="$1"
  local APP_NAME="waybar-weather"
  local INSTALL_PATH="/usr/bin/${APP_NAME}"
  local ASSET="${SCRIPT_DIR:-.}/assets/${APP_NAME}.gz"

  # Helper: log wrappers may not be defined here; reuse INFO/WARN/ERROR if available
  _log() { echo "[${APP_NAME}] $*" 2>&1 | tee -a "$log"; }
  _warn() { echo "[${APP_NAME}] WARN: $*" 1>&2 | tee -a "$log"; }
  _err() { echo "[${APP_NAME}] ERROR: $*" 1>&2 | tee -a "$log"; }

  # NixOS handled by a separate helper
  if grep -qi '^ID=nixos' /etc/os-release 2>/dev/null; then
    _warn "NixOS detected. Use install_waybar_weather_nixos instead."
    return 0
  fi

  # Sudo handling for /usr/bin and /usr/local/bin
  local SUDO=""
  if [[ $EUID -ne 0 ]]; then
    if command -v sudo >/dev/null 2>&1; then
      SUDO="sudo"
    else
      _err "sudo not available; cannot write to ${INSTALL_PATH} as non-root"
      return 1
    fi
  fi

  if grep -qi '^ID=arch' /etc/os-release 2>/dev/null; then
    if command -v pacman >/dev/null 2>&1 && pacman -Qi waybar-weather >/dev/null 2>&1; then
      _log "waybar-weather already installed via pacman."
      return 0
    fi

    # If no package is installed but a static binary exists, remove it before AUR install
    if [ -x /usr/bin/waybar-weather ] || [ -x /usr/local/bin/waybar-weather ]; then
      _log "Removing waybar-weather static binary"
      ${SUDO} rm -f /usr/bin/waybar-weather /usr/local/bin/waybar-weather || _warn "Failed to remove existing waybar-weather binary."
    fi

    if command -v yay >/dev/null 2>&1; then
      _log "Attempting to install AUR package 'waybar-weather' via yay"
      if yay -S --noconfirm waybar-weather; then
        _log "AUR install succeeded."
        return 0
      else
        _warn "AUR install failed; will fall back to bundled asset."
      fi
    else
      _warn "yay not found on Arch; falling back to bundled asset."
    fi
  fi

  # Asset path validation
  if [[ ! -f "$ASSET" ]]; then
    _err "Asset not found: $ASSET"
    return 1
  fi
  if ! command -v gzip >/dev/null 2>&1; then
    _err "Missing required command: gzip"
    return 1
  fi


  _log "Installing prebuilt binary to ${INSTALL_PATH} from ${ASSET}"
  if ${SUDO} sh -c "tmp=\$(mktemp '${INSTALL_PATH}.XXXXXX') && gzip -dc '$ASSET' > \"\$tmp\" && chmod 0755 \"\$tmp\" && mv -f \"\$tmp\" '${INSTALL_PATH}'"; then
    if "${INSTALL_PATH}" -h >/dev/null 2>&1; then
      _log "Installed ${APP_NAME} successfully."
    else
      _warn "${APP_NAME} installed, but a basic self-check did not run."
    fi
  else
    _err "Failed to install ${APP_NAME} to ${INSTALL_PATH}"
    return 1
  fi
}

# Install waybar-weather on NixOS using Go from the system (no version checks)
install_waybar_weather_nixos() {
  local log="$1"
  local APP_NAME="waybar-weather"
  local DEST="$HOME/.local/bin/${APP_NAME}"

  _log() { echo "[${APP_NAME}] $*" 2>&1 | tee -a "$log"; }
  _warn() { echo "[${APP_NAME}] WARN: $*" 1>&2 | tee -a "$log"; }
  _err() { echo "[${APP_NAME}] ERROR: $*" 1>&2 | tee -a "$log"; }

  if ! grep -qi '^ID=nixos' /etc/os-release 2>/dev/null; then
    _warn "Not NixOS; skipping NixOS-specific build."
    return 0
  fi

  if ! command -v go >/dev/null 2>&1; then
    _err "Go toolchain not found in PATH. Ensure NixOS-Hyprland provides go, then re-run."
    return 1
  fi
  if ! command -v git >/dev/null 2>&1; then
    _err "git not found; install git and retry."
    return 1
  fi

  local tmp
  tmp=$(mktemp -d)
  trap 'rm -rf "${tmp}"' RETURN

  _log "Cloning waybar-weather source"
  if ! git clone --depth 1 https://github.com/wneessen/waybar-weather.git "${tmp}/src" >/dev/null 2>&1; then
    _err "git clone failed"
    return 1
  fi

  if ! (
    cd "${tmp}/src" || { _err "cd failed"; exit 1; }
    _log "Fetching modules"
    go mod download >/dev/null 2>&1 || _warn "go mod download returned non-zero; continuing"
    _log "Building ${APP_NAME}"
    CGO_ENABLED=0 go build -trimpath -ldflags "-s -w" -o "${APP_NAME}" ./cmd/${APP_NAME}
  ); then
    _err "go build failed"
    return 1
  fi

  mkdir -p "$HOME/.local/bin"
  install -m 0755 "${APP_NAME}" "${DEST}" || { _err "install to ${DEST} failed"; return 1; }

  if printf '%s' "$PATH" | grep -q "$HOME/.local/bin"; then
    :
  else
    _warn "~/.local/bin is not in PATH; add it so Waybar can find ${APP_NAME}."
  fi

  if "${DEST}" -h >/dev/null 2>&1; then
    _log "Installed ${APP_NAME} to ${DEST}"
  else
    _warn "${APP_NAME} installed, but a basic self-check did not run."
  fi
}

# Wrapper: choose NixOS builder or non-NixOS installer automatically
install_waybar_weather() {
  local log="$1"
  if grep -qi '^ID=nixos' /etc/os-release 2>/dev/null; then
    install_waybar_weather_nixos "$log"
  else
    install_waybar_weather_binary "$log"
  fi
}
