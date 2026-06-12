#!/usr/bin/env bash
# ==================================================
#  KoolDots (2026)
#  Project URL: https://github.com/LinuxBeginnings
#  License: GNU GPLv3
#  SPDX-License-Identifier: GPL-3.0-or-later
# ==================================================
# 💫 https://github.com/LinuxBeginnings 💫 #
# Add/revert status-aware portal override for Hyprland #

set -euo pipefail

SCRIPT_NAME="$(basename "$0")"
DRY_RUN=0
ACTION="apply"

OVERRIDE_DIR="$HOME/.config/systemd/user/xdg-desktop-portal.service.d"
OVERRIDE_FILE="$OVERRIDE_DIR/override.conf"
PORTAL_UNITS=(
  "xdg-desktop-portal.service"
  "xdg-desktop-portal-hyprland.service"
  "xdg-desktop-portal-gtk.service"
)

OS_PRETTY_NAME="Unknown"
OS_ID="unknown"
OS_VERSION_ID="unknown"

usage() {
  cat <<EOF
Usage: ${SCRIPT_NAME} [OPTIONS]

Install/revert a user systemd override for xdg-desktop-portal on Hyprland
and validate portal service health.

Default action (no options):
  - report OS + current status
  - install override if missing
  - restart portal units
  - validate and report success/failure

Options:
  -h, --help       Show this help message and exit
  -d, --dry-run    Print planned actions only (no changes made)
  -r, --r, --revert
                   Remove override, restart, then validate (for upstream-fixed systems)
  -s, --status     Print status only (includes: override_installed=true|false)
EOF
}

info() {
  printf "[INFO] %s\n" "$1"
}

warn() {
  printf "[WARN] %s\n" "$1"
}

error() {
  printf "[ERROR] %s\n" "$1" >&2
}

fail() {
  error "$1"
  exit 1
}

set_action() {
  local requested="$1"
  if [[ "$ACTION" != "apply" && "$ACTION" != "$requested" ]]; then
    fail "Conflicting options: cannot combine '$ACTION' with '$requested'."
  fi
  ACTION="$requested"
}

format_command() {
  printf "%q " "$@"
}

run_cmd() {
  if ((DRY_RUN)); then
    info "[dry-run] $(format_command "$@")"
    return 0
  fi
  "$@"
}

run_cmd_allow_fail() {
  if ((DRY_RUN)); then
    info "[dry-run] $(format_command "$@")"
    return 0
  fi
  "$@" || true
}

detect_os() {
  if [[ -r /etc/os-release ]]; then
    # shellcheck disable=SC1091
    . /etc/os-release
    OS_PRETTY_NAME="${PRETTY_NAME:-${NAME:-Unknown}}"
    OS_ID="${ID:-unknown}"
    OS_VERSION_ID="${VERSION_ID:-unknown}"
  fi
}

is_ubuntu_family() {
  [[ "$OS_ID" == "ubuntu" ||
    "$OS_ID" == "linuxmint" ||
    "$OS_ID" == "zorin" ||
    "$OS_ID" == "rhino" ||
    "${ID_LIKE:-}" == *ubuntu* ]]
}

require_user_systemd() {
  command -v systemctl >/dev/null 2>&1 || fail "systemctl is required but was not found."
  systemctl --user show-environment >/dev/null 2>&1 || fail "Cannot contact systemd user manager."
}

unit_load_state() {
  systemctl --user show --property=LoadState --value "$1" 2>/dev/null || true
}

unit_exists() {
  local load_state
  load_state="$(unit_load_state "$1")"
  [[ -n "$load_state" && "$load_state" != "not-found" ]]
}

unit_active_state() {
  local state
  state="$(systemctl --user is-active "$1" 2>/dev/null || true)"
  [[ -n "$state" ]] || state="unknown"
  printf "%s" "$state"
}

render_override_content() {
  cat <<'EOF'
[Unit]
Requisite=
Requires=graphical-session.target
After=graphical-session.target
EOF
}

is_override_installed() {
  [[ -f "$OVERRIDE_FILE" ]] || return 1
  grep -Fxq "[Unit]" "$OVERRIDE_FILE" &&
    grep -Fxq "Requisite=" "$OVERRIDE_FILE" &&
    grep -Fxq "Requires=graphical-session.target" "$OVERRIDE_FILE" &&
    grep -Fxq "After=graphical-session.target" "$OVERRIDE_FILE"
}

ensure_portal_env() {
  export XDG_CURRENT_DESKTOP="${XDG_CURRENT_DESKTOP:-Hyprland}"
  export XDG_SESSION_DESKTOP="${XDG_SESSION_DESKTOP:-Hyprland}"
  export XDG_SESSION_TYPE="${XDG_SESSION_TYPE:-wayland}"

  if [[ -f "/usr/share/glib-2.0/schemas/gschemas.compiled" ]]; then
    export GSETTINGS_SCHEMA_DIR="/usr/share/glib-2.0/schemas"
  fi

  local data_dirs="${XDG_DATA_DIRS:-}"
  if [[ -z "$data_dirs" ]]; then
    data_dirs="/usr/local/share:/usr/share"
  else
    if [[ ":$data_dirs:" != *":/usr/local/share:"* ]]; then
      data_dirs="/usr/local/share:$data_dirs"
    fi
    if [[ ":$data_dirs:" != *":/usr/share:"* ]]; then
      data_dirs="$data_dirs:/usr/share"
    fi
  fi
  export XDG_DATA_DIRS="$data_dirs"
}

sync_activation_env() {
  if command -v dbus-update-activation-environment >/dev/null 2>&1; then
    run_cmd_allow_fail dbus-update-activation-environment --systemd WAYLAND_DISPLAY XDG_CURRENT_DESKTOP XDG_SESSION_DESKTOP XDG_SESSION_TYPE XDG_DATA_DIRS GSETTINGS_SCHEMA_DIR
  fi
  run_cmd_allow_fail systemctl --user import-environment WAYLAND_DISPLAY XDG_CURRENT_DESKTOP XDG_SESSION_DESKTOP XDG_SESSION_TYPE XDG_DATA_DIRS GSETTINGS_SCHEMA_DIR
}

stop_stale_portal_processes() {
  local uid
  uid="$(id -u)"
  run_cmd_allow_fail pkill -u "$uid" -f '/xdg-desktop-portal-hyprland$'
  run_cmd_allow_fail pkill -u "$uid" -f '/xdg-desktop-portal-gtk$'
  run_cmd_allow_fail pkill -u "$uid" -f '/xdg-desktop-portal$'
}

restart_portals() {
  ensure_portal_env
  sync_activation_env

  run_cmd systemctl --user daemon-reload

  local unit
  for unit in "${PORTAL_UNITS[@]}"; do
    if unit_exists "$unit"; then
      run_cmd_allow_fail systemctl --user stop "$unit"
    fi
  done

  stop_stale_portal_processes

  for unit in "${PORTAL_UNITS[@]}"; do
    if unit_exists "$unit"; then
      run_cmd_allow_fail systemctl --user reset-failed "$unit"
    fi
  done

  run_cmd_allow_fail systemctl --user start graphical-session.target

  if unit_exists "xdg-desktop-portal-hyprland.service"; then
    run_cmd_allow_fail systemctl --user start xdg-desktop-portal-hyprland.service
  else
    warn "xdg-desktop-portal-hyprland.service is not installed."
  fi

  if is_ubuntu_family && unit_exists "xdg-desktop-portal-gtk.service"; then
    run_cmd_allow_fail systemctl --user start xdg-desktop-portal-gtk.service
  fi

  if unit_exists "xdg-desktop-portal.service"; then
    run_cmd_allow_fail systemctl --user start xdg-desktop-portal.service
  fi
}

install_override() {
  if is_override_installed; then
    info "Override already installed at $OVERRIDE_FILE."
    return 0
  fi

  if ((DRY_RUN)); then
    info "[dry-run] Would install override at $OVERRIDE_FILE"
    render_override_content | sed 's/^/[dry-run]   /'
    return 0
  fi

  mkdir -p "$OVERRIDE_DIR"
  render_override_content > "$OVERRIDE_FILE"
  info "Installed override at $OVERRIDE_FILE."
}

revert_override() {
  if [[ ! -f "$OVERRIDE_FILE" ]]; then
    info "No override file found at $OVERRIDE_FILE."
    return 0
  fi

  run_cmd rm -f "$OVERRIDE_FILE"
  if [[ -d "$OVERRIDE_DIR" ]] && [[ -z "$(ls -A "$OVERRIDE_DIR" 2>/dev/null)" ]]; then
    run_cmd rmdir "$OVERRIDE_DIR"
  fi
  info "Removed override from $OVERRIDE_FILE."
}

portal_ping_ok() {
  if command -v gdbus >/dev/null 2>&1; then
    gdbus call --session \
      --dest org.freedesktop.portal.Desktop \
      --object-path /org/freedesktop/portal/desktop \
      --method org.freedesktop.DBus.Peer.Ping >/dev/null 2>&1
    return $?
  fi

  if command -v busctl >/dev/null 2>&1; then
    busctl --user call org.freedesktop.portal.Desktop /org/freedesktop/portal/desktop org.freedesktop.DBus.Peer Ping >/dev/null 2>&1
    return $?
  fi

  return 1
}

print_status_report() {
  local override_value="false"
  if is_override_installed; then
    override_value="true"
  fi

  printf "os_pretty_name=%s\n" "$OS_PRETTY_NAME"
  printf "os_id=%s\n" "$OS_ID"
  printf "os_version_id=%s\n" "$OS_VERSION_ID"
  printf "override_file=%s\n" "$OVERRIDE_FILE"
  printf "override_installed=%s\n" "$override_value"
  printf "graphical_session_target=%s\n" "$(unit_active_state "graphical-session.target")"
  printf "xdg_desktop_portal_hyprland=%s\n" "$(unit_active_state "xdg-desktop-portal-hyprland.service")"
  printf "xdg_desktop_portal=%s\n" "$(unit_active_state "xdg-desktop-portal.service")"
}

validate_portal() {
  local hypr_state portal_state ping_ok
  hypr_state="$(unit_active_state "xdg-desktop-portal-hyprland.service")"
  portal_state="$(unit_active_state "xdg-desktop-portal.service")"
  ping_ok="false"

  if portal_ping_ok; then
    ping_ok="true"
  fi

  printf "portal_ping_ok=%s\n" "$ping_ok"

  if [[ "$hypr_state" == "active" && ( "$portal_state" == "active" || "$ping_ok" == "true" ) ]]; then
    return 0
  fi
  return 1
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    -h|--help)
      usage
      exit 0
      ;;
    -d|--dry-run)
      DRY_RUN=1
      ;;
    -r|--r|--revert)
      set_action "revert"
      ;;
    -s|--status)
      set_action "status"
      ;;
    *)
      fail "Unknown option: $1 (use -h or --help)."
      ;;
  esac
  shift
done

detect_os
require_user_systemd

info "Detected OS: ${OS_PRETTY_NAME} (id=${OS_ID}, version=${OS_VERSION_ID})"

case "$ACTION" in
  status)
    print_status_report
    exit 0
    ;;
  apply)
    print_status_report
    install_override
    restart_portals
    print_status_report
    if validate_portal; then
      info "Portal override workflow completed successfully."
      exit 0
    fi
    error "Portal validation failed after applying override."
    exit 1
    ;;
  revert)
    print_status_report
    revert_override
    restart_portals
    print_status_report
    if validate_portal; then
      info "Revert completed and portal validation succeeded."
      exit 0
    fi
    error "Revert completed but portal validation failed (upstream fix may not be present yet)."
    exit 1
    ;;
esac
