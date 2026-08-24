#!/usr/bin/env bash
# ==================================================
#  KoolDots (2026)
#  Project URL: https://github.com/LinuxBeginnings
#  License: GNU GPLv3
#  SPDX-License-Identifier: GPL-3.0-or-later
# ==================================================
# 💫 https://github.com/LinuxBeginnings 💫 #
# Setup & Verify SSH Agent on Localhost for Shells and Hyprland #

set -uo pipefail

SCRIPT_NAME="$(basename "$0")"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
AGENT_SCRIPT="$SCRIPT_DIR/kooldots-add-ssh-agent.sh"

CONFIG_HOME="${XDG_CONFIG_HOME:-$HOME/.config}"
HYPR_DIR="$CONFIG_HOME/hypr"
USER_CONFIGS_DIR="$HYPR_DIR/UserConfigs"
ENV_CONF="$USER_CONFIGS_DIR/ENVariables.conf"
ENV_LUA="$USER_CONFIGS_DIR/user_env.lua"
ZSHRC="$HOME/.zshrc"
BASHRC="$HOME/.bashrc"
SSH_CONFIG="$HOME/.ssh/config"
SERVICE_NAME="ssh-agent"
SERVICE_FILE="$CONFIG_HOME/systemd/user/${SERVICE_NAME}.service"

ACTION="status"
DRY_RUN=0

# Formatting & Colors
if tput sgr0 >/dev/null 2>&1; then
  OK="$(tput setaf 2)[OK]$(tput sgr0)"
  ERROR="$(tput setaf 1)[ERROR]$(tput sgr0)"
  NOTE="$(tput setaf 3)[NOTE]$(tput sgr0)"
  INFO="$(tput setaf 4)[INFO]$(tput sgr0)"
  WARN="$(tput setaf 1)[WARN]$(tput sgr0)"
  ACTION_TAG="$(tput setaf 6)[ACTION]$(tput sgr0)"
  GREEN="$(tput setaf 2)"
  RED="$(tput setaf 1)"
  YELLOW="$(tput setaf 3)"
  BLUE="$(tput setaf 4)"
  MAGENTA="$(tput setaf 5)"
  CYAN="$(tput setaf 6)"
  BOLD="$(tput bold)"
  RESET="$(tput sgr0)"
else
  OK="[OK]"; ERROR="[ERROR]"; NOTE="[NOTE]"; INFO="[INFO]"; WARN="[WARN]"; ACTION_TAG="[ACTION]"
  GREEN=""; RED=""; YELLOW=""; BLUE=""; MAGENTA=""; CYAN=""; BOLD=""; RESET=""
fi

ICON_KEY="󰌆"
ICON_CHECK="󰄲"
ICON_CROSS="󰅖"
ICON_HOST="󰣀"

usage() {
  cat <<EOF
Usage: ${SCRIPT_NAME} [OPTIONS]

Manage, verify, and wire the localhost SSH agent service and SSH_AUTH_SOCK
environment variable into shell profiles (~/.zshrc, ~/.bashrc) and Hyprland configs.

Options:
  -h, --help       Show this help message and exit
  -s, --status     Check and report status of all config files and the ssh-agent service
  -u, --update     Update/install all config files and ensure the ssh-agent service is running
  -r, --remove     Uninstall SSH_AUTH_SOCK variables and optionally disable the user service
  -d, --dry-run    Show planned modifications without making changes
EOF
}

check_service_installed() {
  [[ -f "$SERVICE_FILE" ]]
}

check_service_active() {
  command -v systemctl >/dev/null 2>&1 && systemctl --user is-active --quiet "$SERVICE_NAME" 2>/dev/null
}

check_service_enabled() {
  command -v systemctl >/dev/null 2>&1 && systemctl --user is-enabled --quiet "$SERVICE_NAME" 2>/dev/null
}

has_zshrc_env() {
  [[ -f "$ZSHRC" ]] && grep -Eq '^[[:space:]]*(export[[:space:]]+)?SSH_AUTH_SOCK=' "$ZSHRC"
}

has_bashrc_env() {
  [[ -f "$BASHRC" ]] && grep -Eq '^[[:space:]]*(export[[:space:]]+)?SSH_AUTH_SOCK=' "$BASHRC"
}

has_lua_env() {
  [[ -f "$ENV_LUA" ]] && grep -Eq 'hl\.env\([[:space:]]*["'\'']SSH_AUTH_SOCK["'\'']' "$ENV_LUA"
}

has_conf_env() {
  [[ -f "$ENV_CONF" ]] && grep -Eq '^[[:space:]]*env[[:space:]]*=[[:space:]]*SSH_AUTH_SOCK,' "$ENV_CONF"
}

has_ssh_add_keys() {
  [[ -f "$SSH_CONFIG" ]] && grep -Eq '^[[:space:]]*AddKeysToAgent[[:space:]]+yes' "$SSH_CONFIG"
}

has_github_host() {
  [[ -f "$SSH_CONFIG" ]] && grep -Eq '^[[:space:]]*Host[[:space:]]+github\.com\b' "$SSH_CONFIG"
}

ensure_service_ready() {
  if ! check_service_installed || ! check_service_enabled; then
    echo -e "${INFO} ${ICON_KEY} Setting up user ssh-agent service..."
    if [[ -x "$AGENT_SCRIPT" ]]; then
      if [[ $DRY_RUN -eq 1 ]]; then
        echo -e "  [dry-run] $AGENT_SCRIPT --enable"
      else
        "$AGENT_SCRIPT" --enable >/dev/null 2>&1 || true
      fi
    else
      echo -e "${WARN} Helper script $AGENT_SCRIPT not found; configuring service manually."
      if [[ $DRY_RUN -eq 0 ]]; then
        mkdir -p "$(dirname "$SERVICE_FILE")"
        cat <<'EOF' > "$SERVICE_FILE"
[Unit]
Description=SSH key agent

[Service]
Type=simple
Environment=SSH_AUTH_SOCK=%t/ssh-agent.socket
ExecStart=/usr/bin/ssh-agent -D -a $SSH_AUTH_SOCK

[Install]
WantedBy=default.target
EOF
        systemctl --user daemon-reload || true
        systemctl --user enable --now "$SERVICE_NAME" || true
      fi
    fi
  elif ! check_service_active; then
    echo -e "${ACTION_TAG} Starting inactive ssh-agent service..."
    if [[ $DRY_RUN -eq 0 ]]; then
      systemctl --user start "$SERVICE_NAME" || true
    fi
  fi
}

apply_updates() {
  local changes_made=0

  echo -e "\n${BOLD}${CYAN}=== Applying Localhost SSH Agent Configuration ===${RESET}\n"

  # 1. Service check & installation
  ensure_service_ready

  # 2. ~/.zshrc
  if [[ -f "$ZSHRC" ]]; then
    if ! has_zshrc_env; then
      echo -e "${ACTION_TAG} Adding SSH_AUTH_SOCK to ${YELLOW}$ZSHRC${RESET}"
      if [[ $DRY_RUN -eq 0 ]]; then
        printf '\n# SSH Agent\nexport SSH_AUTH_SOCK="${XDG_RUNTIME_DIR:-/run/user/$(id -u)}/ssh-agent.socket"\n' >> "$ZSHRC"
      fi
      changes_made=1
    fi
  fi

  # 3. ~/.bashrc
  if [[ -f "$BASHRC" ]]; then
    if ! has_bashrc_env; then
      echo -e "${ACTION_TAG} Adding SSH_AUTH_SOCK to ${YELLOW}$BASHRC${RESET}"
      if [[ $DRY_RUN -eq 0 ]]; then
        printf '\n# SSH Agent\nexport SSH_AUTH_SOCK="${XDG_RUNTIME_DIR:-/run/user/$(id -u)}/ssh-agent.socket"\n' >> "$BASHRC"
      fi
      changes_made=1
    fi
  fi

  # 4. Hyprland user_env.lua
  if ! has_lua_env; then
    echo -e "${ACTION_TAG} Adding SSH_AUTH_SOCK to ${YELLOW}$ENV_LUA${RESET}"
    if [[ $DRY_RUN -eq 0 ]]; then
      mkdir -p "$USER_CONFIGS_DIR"
      touch "$ENV_LUA"
      cat <<'LUA' >> "$ENV_LUA"

-- SSH agent socket
hl.env("SSH_AUTH_SOCK", (os.getenv("XDG_RUNTIME_DIR") or "") .. "/ssh-agent.socket")
LUA
    fi
    changes_made=1
  fi

  # 5. Hyprland ENVariables.conf (for hybrid/conf mode)
  if ! has_conf_env; then
    echo -e "${ACTION_TAG} Adding SSH_AUTH_SOCK to ${YELLOW}$ENV_CONF${RESET}"
    if [[ $DRY_RUN -eq 0 ]]; then
      mkdir -p "$USER_CONFIGS_DIR"
      touch "$ENV_CONF"
      printf '\n# SSH agent socket\nenv = SSH_AUTH_SOCK,$XDG_RUNTIME_DIR/ssh-agent.socket\n' >> "$ENV_CONF"
    fi
    changes_made=1
  fi

  # 6. ~/.ssh/config (AddKeysToAgent & GitHub entry)
  if [[ -f "$SSH_CONFIG" ]]; then
    if ! has_ssh_add_keys; then
      echo -e "${ACTION_TAG} Adding AddKeysToAgent to ${YELLOW}$SSH_CONFIG${RESET}"
      if [[ $DRY_RUN -eq 0 ]]; then
        printf '\n# Automatically add keys to ssh-agent\nAddKeysToAgent yes\n' >> "$SSH_CONFIG"
      fi
      changes_made=1
    fi
    if ! has_github_host && [[ -f "$HOME/.ssh/id_ed25519" ]]; then
      echo -e "${ACTION_TAG} Adding github.com host entry to ${YELLOW}$SSH_CONFIG${RESET}"
      if [[ $DRY_RUN -eq 0 ]]; then
        printf '\nHost github.com\n    HostName github.com\n    User git\n    IdentityFile ~/.ssh/id_ed25519\n    IdentitiesOnly yes\n    AddKeysToAgent yes\n' >> "$SSH_CONFIG"
      fi
      changes_made=1
    fi
  fi

  if [[ $changes_made -eq 0 ]]; then
    echo -e "${OK} All configuration files and services are already up to date."
  else
    echo -e "${OK} Configuration updates completed successfully."
  fi
}

remove_configurations() {
  echo -e "\n${BOLD}${MAGENTA}=== Removing SSH Agent Wiring ===${RESET}\n"

  # Remove from zshrc
  if [[ -f "$ZSHRC" ]] && has_zshrc_env; then
    echo -e "${ACTION_TAG} Removing SSH_AUTH_SOCK from ${YELLOW}$ZSHRC${RESET}"
    if [[ $DRY_RUN -eq 0 ]]; then
      sed -i '/# SSH Agent/d' "$ZSHRC"
      sed -i '/export SSH_AUTH_SOCK=/d' "$ZSHRC"
    fi
  fi

  # Remove from bashrc
  if [[ -f "$BASHRC" ]] && has_bashrc_env; then
    echo -e "${ACTION_TAG} Removing SSH_AUTH_SOCK from ${YELLOW}$BASHRC${RESET}"
    if [[ $DRY_RUN -eq 0 ]]; then
      sed -i '/# SSH Agent/d' "$BASHRC"
      sed -i '/export SSH_AUTH_SOCK=/d' "$BASHRC"
    fi
  fi

  # Remove from user_env.lua
  if [[ -f "$ENV_LUA" ]] && has_lua_env; then
    echo -e "${ACTION_TAG} Removing SSH_AUTH_SOCK from ${YELLOW}$ENV_LUA${RESET}"
    if [[ $DRY_RUN -eq 0 ]]; then
      sed -i '/-- SSH agent socket/d' "$ENV_LUA"
      sed -i '/hl\.env("SSH_AUTH_SOCK"/d' "$ENV_LUA"
    fi
  fi

  # Remove from ENVariables.conf
  if [[ -f "$ENV_CONF" ]] && has_conf_env; then
    echo -e "${ACTION_TAG} Removing SSH_AUTH_SOCK from ${YELLOW}$ENV_CONF${RESET}"
    if [[ $DRY_RUN -eq 0 ]]; then
      sed -i '/# SSH agent socket/d' "$ENV_CONF"
      sed -i '/env = SSH_AUTH_SOCK,/d' "$ENV_CONF"
    fi
  fi

  # Ask/handle service disable
  if check_service_installed; then
    echo -e "${ACTION_TAG} Disabling user ssh-agent service..."
    if [[ $DRY_RUN -eq 0 ]]; then
      systemctl --user disable --now "$SERVICE_NAME" 2>/dev/null || true
    fi
  fi

  echo -e "${OK} Removal complete."
}

show_status_report() {
  echo -e "\n${BOLD}${BLUE}╔══════════════════════════════════════════════════════════════╗${RESET}"
  echo -e "${BOLD}${BLUE}║        KoolDots SSH Agent Status & Verification              ║${RESET}"
  echo -e "${BOLD}${BLUE}╚══════════════════════════════════════════════════════════════╝${RESET}\n"

  # Service status
  local s_inst s_en s_act
  if check_service_installed; then s_inst="${GREEN}${ICON_CHECK} installed${RESET}"; else s_inst="${RED}${ICON_CROSS} missing${RESET}"; fi
  if check_service_enabled; then s_en="${GREEN}${ICON_CHECK} enabled${RESET}"; else s_en="${YELLOW}${ICON_CROSS} disabled${RESET}"; fi
  if check_service_active; then s_act="${GREEN}${ICON_CHECK} active (running)${RESET}"; else s_act="${RED}${ICON_CROSS} inactive${RESET}"; fi

  echo -e " ${BOLD}Systemd User Service:${RESET}"
  echo -e "   • Service Unit  : ${CYAN}${SERVICE_FILE}${RESET} [$s_inst]"
  echo -e "   • Enable Status : $s_en"
  echo -e "   • Run Status    : $s_act"

  local socket_path="${XDG_RUNTIME_DIR:-/run/user/$(id -u)}/ssh-agent.socket"
  if [[ -S "$socket_path" ]]; then
    echo -e "   • Socket Path   : ${GREEN}${socket_path}${RESET} (${GREEN}listening${RESET})"
  else
    echo -e "   • Socket Path   : ${YELLOW}${socket_path}${RESET} (${YELLOW}not found${RESET})"
  fi

  echo -e "\n ${BOLD}Environment & Config Files:${RESET}"

  # zshrc
  if has_zshrc_env; then
    echo -e "   [${GREEN}${ICON_CHECK}${RESET}] ~/.zshrc                       : ${GREEN}configured${RESET}"
  else
    echo -e "   [${RED}${ICON_CROSS}${RESET}] ~/.zshrc                       : ${RED}missing SSH_AUTH_SOCK${RESET}"
  fi

  # bashrc
  if has_bashrc_env; then
    echo -e "   [${GREEN}${ICON_CHECK}${RESET}] ~/.bashrc                      : ${GREEN}configured${RESET}"
  else
    echo -e "   [${YELLOW}${ICON_CROSS}${RESET}] ~/.bashrc                      : ${YELLOW}missing SSH_AUTH_SOCK${RESET}"
  fi

  # user_env.lua
  if has_lua_env; then
    echo -e "   [${GREEN}${ICON_CHECK}${RESET}] Hyprland Lua (user_env.lua)     : ${GREEN}configured${RESET}"
  else
    echo -e "   [${RED}${ICON_CROSS}${RESET}] Hyprland Lua (user_env.lua)     : ${RED}missing SSH_AUTH_SOCK${RESET}"
  fi

  # ENVariables.conf
  if has_conf_env; then
    echo -e "   [${GREEN}${ICON_CHECK}${RESET}] Hyprland Conf (ENVariables.conf): ${GREEN}configured${RESET}"
  else
    echo -e "   [${YELLOW}${ICON_CROSS}${RESET}] Hyprland Conf (ENVariables.conf): ${YELLOW}missing SSH_AUTH_SOCK${RESET}"
  fi

  # ~/.ssh/config
  if has_ssh_add_keys; then
    echo -e "   [${GREEN}${ICON_CHECK}${RESET}] ~/.ssh/config (AddKeysToAgent) : ${GREEN}configured${RESET}"
  else
    echo -e "   [${YELLOW}${ICON_CROSS}${RESET}] ~/.ssh/config (AddKeysToAgent) : ${YELLOW}missing${RESET}"
  fi

  if has_github_host; then
    echo -e "   [${GREEN}${ICON_CHECK}${RESET}] ~/.ssh/config (Host github.com) : ${GREEN}configured${RESET}"
  else
    echo -e "   [${YELLOW}${ICON_CROSS}${RESET}] ~/.ssh/config (Host github.com) : ${YELLOW}not defined${RESET}"
  fi

  # SSH Keys on disk
  echo -e "\n ${BOLD}Local SSH Keys on Disk:${RESET}"
  local found_keys=0
  for k in "$HOME/.ssh/id_ed25519" "$HOME/.ssh/id_local" "$HOME/.ssh/id_rsa"; do
    if [[ -f "$k" ]]; then
      echo -e "   • ${ICON_KEY} ${CYAN}${k}${RESET}"
      found_keys=1
    fi
  done
  [[ $found_keys -eq 0 ]] && echo -e "   • ${YELLOW}No standard key files found in ~/.ssh/${RESET}"

  # Loaded Keys in Agent
  echo -e "\n ${BOLD}Loaded Keys in Active Agent:${RESET}"
  if [[ -S "$socket_path" ]] && check_service_active; then
    local loaded
    loaded=$(SSH_AUTH_SOCK="$socket_path" ssh-add -l 2>&1 || true)
    if [[ "$loaded" == *"The agent has no identities"* ]]; then
      echo -e "   • ${YELLOW}(No keys currently loaded into agent)${RESET}"
    else
      echo "$loaded" | sed 's/^/   • /'
    fi
  else
    echo -e "   • ${YELLOW}(Agent not accessible)${RESET}"
  fi

  print_activation_instructions
}

print_activation_instructions() {
  local sock="${XDG_RUNTIME_DIR:-/run/user/$(id -u)}/ssh-agent.socket"

  echo -e "\n${BOLD}${GREEN}╔══════════════════════════════════════════════════════════════╗${RESET}"
  echo -e "${BOLD}${GREEN}║               Quick Activation Instructions                  ║${RESET}"
  echo -e "${BOLD}${GREEN}╚══════════════════════════════════════════════════════════════╝${RESET}"
  echo -e " To activate the SSH agent in your current shell session immediately:\n"
  echo -e "   ${BOLD}${CYAN}export SSH_AUTH_SOCK=\"${sock}\"${RESET}"
  echo -e "   ${BOLD}${CYAN}ssh-add ~/.ssh/id_ed25519${RESET}  ${BLUE}# (or ~/.ssh/id_local)${RESET}\n"
  echo -e " Or simply reload your shell configuration:"
  echo -e "   ${BOLD}${CYAN}source ~/.zshrc${RESET}  ${BLUE}# (or source ~/.bashrc)${RESET}\n"
  echo -e " ${NOTE} Once added, your passphrase is remembered in memory for your session."
  echo -e "    All new Hyprland terminals and git commands will authenticate automatically.\n"
}

# Parse CLI options
while [[ $# -gt 0 ]]; do
  case "$1" in
    -h|--help)
      usage
      exit 0
      ;;
    -s|--status)
      ACTION="status"
      ;;
    -u|--update)
      ACTION="update"
      ;;
    -r|--remove)
      ACTION="remove"
      ;;
    -d|--dry-run)
      DRY_RUN=1
      ;;
    *)
      echo -e "${ERROR} Unknown option: $1" >&2
      usage
      exit 1
      ;;
  esac
  shift
done

case "$ACTION" in
  status)
    show_status_report
    ;;
  update)
    apply_updates
    show_status_report
    ;;
  remove)
    remove_configurations
    show_status_report
    ;;
esac
