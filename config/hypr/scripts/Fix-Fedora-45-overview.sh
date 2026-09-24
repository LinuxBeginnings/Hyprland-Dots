#!/usr/bin/env bash
# ==================================================
#  KoolDots (2026)
#  Project URL: https://github.com/LinuxBeginnings
#  License: GNU GPLv3
#  SPDX-License-Identifier: GPL-3.0-or-later
# ==================================================
# 💫 https://github.com/LinuxBeginnings 💫 #
# Resolve Quickshell Overview & Qt 6.11 Private API Symbol Lookup Errors on Fedora 45+ #

set -uo pipefail

SCRIPT_NAME="$(basename "$0")"
CHECK_ONLY=0
DRY_RUN=0
FORCE=0
QUIET=0
ASSUME_YES=1

# Color definitions
if tput sgr0 >/dev/null 2>&1; then
  OK="$(tput setaf 2)[OK]$(tput sgr0)"
  ERROR="$(tput setaf 1)[ERROR]$(tput sgr0)"
  NOTE="$(tput setaf 3)[NOTE]$(tput sgr0)"
  INFO="$(tput setaf 4)[INFO]$(tput sgr0)"
  WARN="$(tput setaf 1)[WARN]$(tput sgr0)"
  YELLOW="$(tput setaf 3)"
  GREEN="$(tput setaf 2)"
  BLUE="$(tput setaf 4)"
  MAGENTA="$(tput setaf 5)"
  RESET="$(tput sgr0)"
else
  OK="[OK]"; ERROR="[ERROR]"; NOTE="[NOTE]"; INFO="[INFO]"; WARN="[WARN]"
  YELLOW=""; GREEN=""; BLUE=""; MAGENTA=""; RESET=""
fi

iDIR="${XDG_CONFIG_HOME:-$HOME/.config}/swaync/images"
OVERVIEW_CONFIG_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/quickshell/overview"
DOTS_OVERVIEW_DIR="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")/../../quickshell/overview" 2>/dev/null && pwd || true)"

usage() {
  cat <<EOF
Usage: ${SCRIPT_NAME} [OPTIONS]

Checks for Quickshell Qt 6.11 Private API symbol lookup errors on Fedora 45+
(e.g., undefined symbol: _ZN23QUntypedPropertyBindingC1EP23QPropertyBindingPrivate, version Qt_6.11_PRIVATE_API)
and resolves them by enabling the errornointernet/quickshell COPR and migrating
to quickshell-git which provides the updated Qt 6.11 ABI build.

Options:
  -h, --help       Show this help message and exit
  -c, --check      Check and report status only (exit 0 if healthy, 1 if broken)
  -d, --dry-run    Report planned changes without modifying any packages or files
  -f, --force      Force swap/reinstallation to quickshell-git even if no error is detected
  -q, --quiet      Suppress informational output
EOF
}

log_info() {
  [[ $QUIET -eq 0 ]] && echo -e "${INFO} $1"
}

log_ok() {
  [[ $QUIET -eq 0 ]] && echo -e "${OK} $1"
}

log_warn() {
  echo -e "${WARN} $1" >&2
}

log_error() {
  echo -e "${ERROR} $1" >&2
}

notify_user() {
  local urgency="${1:-normal}"
  local title="$2"
  local body="$3"
  if command -v notify-send >/dev/null 2>&1 && [[ -n "${WAYLAND_DISPLAY:-}${DISPLAY:-}" ]]; then
    local icon="$iDIR/ja.png"
    [[ "$urgency" == "critical" ]] && icon="$iDIR/error.png"
    notify-send -i "$icon" -u "$urgency" "$title" "$body" 2>/dev/null || true
  fi
}

check_fedora() {
  if [[ -f /etc/os-release ]]; then
    # shellcheck disable=SC1091
    source /etc/os-release
    if [[ "${ID:-}" != "fedora" && "${ID_LIKE:-}" != *"fedora"* ]]; then
      log_warn "This system is not identified as Fedora (ID=${ID:-unknown})."
    fi
  else
    log_warn "Could not read /etc/os-release to verify distribution."
  fi
}

check_qs_symbol_error() {
  local error_output=""
  if command -v qs >/dev/null 2>&1; then
    error_output="$(qs --version 2>&1 || true)"
    if echo "$error_output" | grep -qiE "symbol lookup error|undefined symbol.*Qt_6\.11_PRIVATE_API|QUntypedPropertyBinding"; then
      echo "$error_output"
      return 1
    fi
  elif [[ -f /usr/bin/qs ]]; then
    error_output="$(/usr/bin/qs --version 2>&1 || true)"
    if echo "$error_output" | grep -qiE "symbol lookup error|undefined symbol.*Qt_6\.11_PRIVATE_API|QUntypedPropertyBinding"; then
      echo "$error_output"
      return 1
    fi
  fi
  return 0
}

check_installed_pkg() {
  if command -v rpm >/dev/null 2>&1; then
    if rpm -q quickshell-git >/dev/null 2>&1; then
      echo "quickshell-git"
    elif rpm -q quickshell >/dev/null 2>&1; then
      echo "quickshell"
    else
      echo "none"
    fi
  else
    echo "unknown"
  fi
}

ensure_overview_config() {
  if [[ ! -d "$OVERVIEW_CONFIG_DIR" && -n "$DOTS_OVERVIEW_DIR" && -d "$DOTS_OVERVIEW_DIR" ]]; then
    log_info "Overview config missing at $OVERVIEW_CONFIG_DIR. Linking from $DOTS_OVERVIEW_DIR..."
    if [[ $DRY_RUN -eq 1 ]]; then
      log_info "[dry-run] mkdir -p $(dirname "$OVERVIEW_CONFIG_DIR") && ln -s $DOTS_OVERVIEW_DIR $OVERVIEW_CONFIG_DIR"
    else
      mkdir -p "$(dirname "$OVERVIEW_CONFIG_DIR")"
      ln -s "$DOTS_OVERVIEW_DIR" "$OVERVIEW_CONFIG_DIR"
      log_ok "Linked overview config to $OVERVIEW_CONFIG_DIR"
    fi
  fi
}

run_command() {
  if [[ $DRY_RUN -eq 1 ]]; then
    log_info "[dry-run] $*"
    return 0
  fi
  "$@"
}

# Parse CLI options
while [[ $# -gt 0 ]]; do
  case "$1" in
    -h|--help)
      usage
      exit 0
      ;;
    -c|--check)
      CHECK_ONLY=1
      shift
      ;;
    -d|--dry-run)
      DRY_RUN=1
      shift
      ;;
    -f|--force)
      FORCE=1
      shift
      ;;
    -q|--quiet)
      QUIET=1
      shift
      ;;
    *)
      log_error "Unknown option: $1"
      usage
      exit 1
      ;;
  esac
done

check_fedora

INSTALLED_PKG="$(check_installed_pkg)"
SYMBOL_ERROR=""
HAS_SYMBOL_ERROR=0

if ! SYMBOL_ERROR="$(check_qs_symbol_error)"; then
  HAS_SYMBOL_ERROR=1
fi

log_info "Detected Quickshell Package: ${YELLOW}${INSTALLED_PKG}${RESET}"

if [[ $HAS_SYMBOL_ERROR -eq 1 ]]; then
  log_warn "Detected Qt 6.11 Private API Symbol Lookup Error in 'qs':"
  echo "    ${SYMBOL_ERROR}" >&2
elif [[ "$INSTALLED_PKG" == "quickshell" ]]; then
  log_warn "'quickshell' (release build) is installed, which may encounter Qt 6.11 private API mismatch on Fedora 45."
else
  log_ok "Quickshell is running without symbol errors (${INSTALLED_PKG})."
fi

# If check-only requested
if [[ $CHECK_ONLY -eq 1 ]]; then
  if [[ $HAS_SYMBOL_ERROR -eq 1 || ("$INSTALLED_PKG" == "quickshell" && $FORCE -eq 0) ]]; then
    log_error "Check failed: Quickshell needs resolution."
    exit 1
  fi
  log_ok "Check passed: Quickshell is healthy."
  exit 0
fi

# Determine if action is required
if [[ $HAS_SYMBOL_ERROR -eq 0 && "$INSTALLED_PKG" == "quickshell-git" && $FORCE -eq 0 ]]; then
  log_ok "No fix needed. Quickshell-git is already active and healthy."
  ensure_overview_config
  exit 0
fi

log_info "Applying fix for Quickshell Qt 6.11 Private API compatibility..."

if ! command -v dnf >/dev/null 2>&1; then
  log_error "DNF package manager not found. Unable to apply RPM package fixes automatically."
  exit 1
fi

# 1. Enable errornointernet/quickshell COPR repository
log_info "Ensuring 'errornointernet/quickshell' COPR repository is enabled..."
run_command sudo dnf copr enable -y errornointernet/quickshell

# 2. Swap or Install quickshell-git
if [[ "$INSTALLED_PKG" == "quickshell" ]]; then
  log_info "Swapping 'quickshell' with 'quickshell-git'..."
  run_command sudo dnf swap -y quickshell quickshell-git
elif [[ "$INSTALLED_PKG" == "none" ]]; then
  log_info "Installing 'quickshell-git'..."
  run_command sudo dnf install -y quickshell-git
else
  log_info "Reinstalling / updating 'quickshell-git' to match system Qt 6.11 libraries..."
  run_command sudo dnf upgrade --refresh -y quickshell-git || run_command sudo dnf reinstall -y quickshell-git
fi

# 3. Ensure Overview configuration directory is linked/present
ensure_overview_config

# 4. Post-fix validation
if [[ $DRY_RUN -eq 0 ]]; then
  log_info "Validating Quickshell resolution..."
  if ! POST_CHECK="$(check_qs_symbol_error)"; then
    log_error "Quickshell is still reporting symbol errors:"
    echo "    ${POST_CHECK}" >&2
    notify_user "critical" "Quickshell Fix Failed" "Symbol lookup error still persists after update."
    exit 1
  fi
  log_ok "Quickshell Overview fix applied successfully! 'qs' is functional."
  notify_user "normal" "Quickshell Fix Complete" "Quickshell-git installed and verified on Fedora 45."
else
  log_ok "Dry run completed. Planned fixes were reported above."
fi
