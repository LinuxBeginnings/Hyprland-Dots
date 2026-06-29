#!/usr/bin/env bash
# ==================================================
#  KoolDots (2026)
#  Project URL: https://github.com/LinuxBeginnings
#  License: GNU GPLv3
#  SPDX-License-Identifier: GPL-3.0-or-later
# ==================================================
# Adds a user ssh-agent systemd service and wires SSH_AUTH_SOCK into Hyprland.

set -euo pipefail

SCRIPT_NAME="$(basename "$0")"
CONFIG_HOME="${XDG_CONFIG_HOME:-$HOME/.config}"
HYPR_DIR="$CONFIG_HOME/hypr"
USER_CONFIGS_DIR="$HYPR_DIR/UserConfigs"
ENV_CONF="$USER_CONFIGS_DIR/ENVariables.conf"
ENV_LUA="$USER_CONFIGS_DIR/user_env.lua"
SYSTEMD_USER_DIR="$CONFIG_HOME/systemd/user"
SERVICE_NAME="ssh-agent"
SERVICE_FILE="$SYSTEMD_USER_DIR/${SERVICE_NAME}.service"
SSH_CONFIG="$HOME/.ssh/config"

DRY_RUN=0
ACTION="status"
SHOW_SYSTEMD_STATUS=0
SHOW_HELP=0

info() { printf '[INFO] %s\n' "$*"; }
warn() { printf '[WARN] %s\n' "$*"; }
step() { printf '[STEP] %s\n' "$*"; }

usage() {
  cat <<USAGE
Usage: $SCRIPT_NAME [options]

Options:
  -h, --help        Show help.
  -d, --dry-run     Show what would change without writing files or running systemctl.
  -s, --status      Show installed/config status and systemctl status output.
  -e, --enable      Install/enable the user service.
  -D, --disable     Stop/disable the user service.
  -r, --remove      Disable and remove the user service file.

Notes:
  --disable has a short flag -D to avoid clashing with -d (dry-run).
  Set HYPR_CONFIG_MODE=lua|conf|hyprlang|auto to override detection.
  Keys must be loaded separately (e.g. ssh-add ~/.ssh/id_ed25519). AddKeysToAgent only auto-adds after first use.
USAGE
}

ORIGINAL_ARGS=$#
if [ "$ORIGINAL_ARGS" -eq 0 ]; then
  SHOW_HELP=1
  SHOW_SYSTEMD_STATUS=1
fi

while [ "$#" -gt 0 ]; do
  case "$1" in
    -h|--help)
      usage
      exit 0
      ;;
    -d|--dry-run)
      DRY_RUN=1
      ;;
    -s|--status)
      ACTION="status"
      SHOW_SYSTEMD_STATUS=1
      ;;
    -e|--enable)
      ACTION="enable"
      ;;
    -D|--disable|--disable-service|--disable)
      ACTION="disable"
      ;;
    -r|--remove)
      ACTION="remove"
      ;;
    *)
      warn "Unknown option: $1"
      usage
      exit 1
      ;;
  esac
  shift
done

run_cmd() {
  if [ "$DRY_RUN" -eq 1 ]; then
    printf '[DRY-RUN] %s\n' "$*"
    return 0
  fi
  "$@"
}

detect_hypr_config_mode() {
  local lua_entry="$HYPR_DIR/hyprland.lua"
  local legacy_lua_entry="$CONFIG_HOME/hyprland.lua"
  local mode="${HYPR_CONFIG_MODE:-}"
  if [ -n "$mode" ]; then
    case "${mode,,}" in
      lua) echo "lua"; return ;;
      conf|hyprlang) echo "conf"; return ;;
      auto) ;;
      *) ;;
    esac
  fi
  if [ -f "$lua_entry" ] || [ -f "$legacy_lua_entry" ]; then
    echo "lua"
  else
    echo "conf"
  fi
}

service_exists() {
  [ -f "$SERVICE_FILE" ]
}

systemctl_user() {
  if ! command -v systemctl >/dev/null 2>&1; then
    warn "systemctl not found; cannot manage the user service."
    return 1
  fi
  run_cmd systemctl --user "$@"
}

service_status_summary() {
  local enabled="unknown"
  local active="unknown"
  if command -v systemctl >/dev/null 2>&1; then
    enabled="$(systemctl --user is-enabled "$SERVICE_NAME" 2>/dev/null || true)"
    active="$(systemctl --user is-active "$SERVICE_NAME" 2>/dev/null || true)"
  fi
  if service_exists; then
    info "Service file exists: $SERVICE_FILE"
  else
    warn "Service file missing: $SERVICE_FILE"
  fi
  info "Service enabled: ${enabled:-unknown}"
  info "Service active: ${active:-unknown}"
}

env_present_conf() {
  [ -f "$ENV_CONF" ] && grep -Eq '^[[:space:]]*env[[:space:]]*=[[:space:]]*SSH_AUTH_SOCK,' "$ENV_CONF"
}

env_present_lua() {
  [ -f "$ENV_LUA" ] && grep -Eq 'hl\.env\([[:space:]]*["'\'']SSH_AUTH_SOCK["'\'']' "$ENV_LUA"
}

ensure_env_conf() {
  if env_present_conf; then
    info "Hyprland ENV already set in $ENV_CONF"
    return 0
  fi
  step "Adding SSH_AUTH_SOCK to $ENV_CONF"
  if [ "$DRY_RUN" -eq 1 ]; then
    printf '[DRY-RUN] append SSH_AUTH_SOCK to %s\n' "$ENV_CONF"
    return 0
  fi
  mkdir -p "$(dirname "$ENV_CONF")"
  touch "$ENV_CONF"
  printf '\n# SSH agent socket\nenv = SSH_AUTH_SOCK,$XDG_RUNTIME_DIR/ssh-agent.socket\n' >> "$ENV_CONF"
}

ensure_env_lua() {
  if env_present_lua; then
    info "Hyprland ENV already set in $ENV_LUA"
    return 0
  fi
  step "Adding SSH_AUTH_SOCK to $ENV_LUA"
  if [ "$DRY_RUN" -eq 1 ]; then
    printf '[DRY-RUN] append SSH_AUTH_SOCK to %s\n' "$ENV_LUA"
    return 0
  fi
  mkdir -p "$(dirname "$ENV_LUA")"
  touch "$ENV_LUA"
  cat <<'LUA' >> "$ENV_LUA"

-- SSH agent socket
hl.env("SSH_AUTH_SOCK", (os.getenv("XDG_RUNTIME_DIR") or "") .. "/ssh-agent.socket")
LUA
}

ensure_ssh_config() {
  if [ ! -f "$SSH_CONFIG" ]; then
    warn "$SSH_CONFIG not found; skipping AddKeysToAgent check."
    return 0
  fi
  if grep -Eq '^[[:space:]]*AddKeysToAgent[[:space:]]+yes' "$SSH_CONFIG"; then
    info "AddKeysToAgent already set in $SSH_CONFIG"
    return 0
  fi
  step "Adding AddKeysToAgent to $SSH_CONFIG"
  if [ "$DRY_RUN" -eq 1 ]; then
    printf '[DRY-RUN] append AddKeysToAgent to %s\n' "$SSH_CONFIG"
    return 0
  fi
  printf '\n# Automatically add keys to ssh-agent\nAddKeysToAgent yes\n' >> "$SSH_CONFIG"
}

create_service_file() {
  if service_exists; then
    info "Service file already exists: $SERVICE_FILE"
    return 0
  fi
  step "Creating systemd user service file"
  if [ "$DRY_RUN" -eq 1 ]; then
    printf '[DRY-RUN] create service file %s\n' "$SERVICE_FILE"
    return 0
  fi
  mkdir -p "$SYSTEMD_USER_DIR"
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
}

enable_service() {
  step "Enabling ssh-agent user service"
  systemctl_user daemon-reload
  systemctl_user enable --now "$SERVICE_NAME"
}

disable_service() {
  step "Disabling ssh-agent user service"
  systemctl_user disable --now "$SERVICE_NAME"
}

remove_service() {
  step "Removing ssh-agent user service"
  if service_exists; then
    disable_service || true
    if [ "$DRY_RUN" -eq 1 ]; then
      printf '[DRY-RUN] remove service file %s\n' "$SERVICE_FILE"
    else
      rm -f "$SERVICE_FILE"
    fi
    systemctl_user daemon-reload
  else
    warn "Service file not found; nothing to remove."
  fi
}

show_status() {
  info "Detected Hyprland config mode: $(detect_hypr_config_mode)"
  service_status_summary
  info "SSH_AUTH_SOCK in ENVariables.conf: $(env_present_conf && echo yes || echo no)"
  info "SSH_AUTH_SOCK in user_env.lua: $(env_present_lua && echo yes || echo no)"
  if [ -f "$SSH_CONFIG" ]; then
    info "AddKeysToAgent in ~/.ssh/config: $(grep -Eq '^[[:space:]]*AddKeysToAgent[[:space:]]+yes' "$SSH_CONFIG" && echo yes || echo no)"
  else
    warn "~/.ssh/config not found."
  fi
  if [ "$SHOW_SYSTEMD_STATUS" -eq 1 ] && command -v systemctl >/dev/null 2>&1; then
    systemctl --user status "$SERVICE_NAME" || true
  fi
}

apply_hypr_env() {
  local mode
  mode="$(detect_hypr_config_mode)"
  if [ "$mode" = "lua" ]; then
    ensure_env_lua
  else
    ensure_env_conf
  fi
}

if [ "$SHOW_HELP" -eq 1 ]; then
  usage
fi

case "$ACTION" in
  status)
    show_status
    ;;
  enable)
    step "Step 1/4: Ensure service file"
    create_service_file
    step "Step 2/4: Enable user service"
    enable_service
    step "Step 3/4: Update Hyprland environment"
    apply_hypr_env
    step "Step 4/4: Update SSH config"
    ensure_ssh_config
    show_status
    ;;
  disable)
    disable_service
    show_status
    ;;
  remove)
    remove_service
    show_status
    ;;
  *)
    warn "Unknown action: $ACTION"
    usage
    exit 1
    ;;
esac
