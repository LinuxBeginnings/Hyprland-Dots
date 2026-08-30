#!/usr/bin/env bash
# ==================================================
#  KoolDots (2026)
#  Project URL: https://github.com/LinuxBeginnings
#  License: GNU GPLv3
#  SPDX-License-Identifier: GPL-3.0-or-later
# ==================================================
# 💫 https://github.com/LinuxBeginnings 💫 #
# Resolve Hyprland / Fastfetch Version Mismatch on Debian #

set -uo pipefail

SCRIPT_NAME="$(basename "$0")"
DRY_RUN=0
CHECK_ONLY=0
FORCE=0
QUIET=0

# Standard header paths queried by Fastfetch and Hyprland tooling
PRIMARY_HEADER_DIR="/usr/include/hyprland/src"
PRIMARY_HEADER_FILE="$PRIMARY_HEADER_DIR/version.h"
LOCAL_HEADER_DIR="/usr/local/include/hyprland/src"
LOCAL_HEADER_FILE="$LOCAL_HEADER_DIR/version.h"

# Colors for terminal output
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

usage() {
  cat <<EOF
Usage: ${SCRIPT_NAME} [OPTIONS]

Checks for Hyprland version mismatches between hyprctl and fastfetch
(typically caused by outdated/missing Debian header files or backport packages)
and resolves them by updating/creating the expected version header files.

Options:
  -h, --help       Show this help message and exit
  -c, --check      Check and report version status only (exit 0 if matching, 1 if mismatch)
  -d, --dry-run    Report planned changes without modifying any files
  -f, --force      Force rewrite of header files even if versions appear to match
  -q, --quiet      Suppress informational output (errors still reported)
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

get_hyprctl_version_info() {
  HYPR_ACTIVE_VER=""
  HYPR_ACTIVE_TAG=""
  HYPR_COMMIT_HASH=""
  HYPR_BRANCH="main"
  HYPR_COMMIT_MSG="Hyprland release build"
  HYPR_DIRTY="clean"

  local raw_output=""
  if command -v hyprctl >/dev/null 2>&1; then
    raw_output="$(hyprctl version 2>/dev/null || true)"
  fi

  if [[ -z "$raw_output" ]] && command -v Hyprland >/dev/null 2>&1; then
    raw_output="$(Hyprland --version 2>/dev/null || true)"
  fi

  if [[ -n "$raw_output" ]]; then
    # Extract tag (e.g. Tag: v0.56.2 or v0.56.2)
    local raw_tag
    raw_tag="$(echo "$raw_output" | awk -F': ' '/^[[:space:]]*Tag:/{print $2}' | awk -F',' '{print $1}' | tr -d ' ' || true)"
    if [[ -n "$raw_tag" ]]; then
      HYPR_ACTIVE_TAG="$raw_tag"
      HYPR_ACTIVE_VER="${raw_tag#v}"
    else
      # Fallback to first line: Hyprland 0.56.2 ...
      local first_line_ver
      first_line_ver="$(echo "$raw_output" | awk '/^Hyprland/{print $2}' || true)"
      if [[ -n "$first_line_ver" ]]; then
        HYPR_ACTIVE_VER="${first_line_ver#v}"
        HYPR_ACTIVE_TAG="v${HYPR_ACTIVE_VER}"
      fi
    fi

    # Extract commit hash
    local hash
    hash="$(echo "$raw_output" | sed -n 's/.*at commit \([0-9a-fA-F]*\).*/\1/p' | head -n1 || true)"
    [[ -n "$hash" ]] && HYPR_COMMIT_HASH="$hash"

    # Extract branch
    local branch
    branch="$(echo "$raw_output" | sed -n 's/.*built from branch \([^ ]*\) at.*/\1/p' | head -n1 || true)"
    [[ -n "$branch" ]] && HYPR_BRANCH="$branch"

    # Extract commit message
    local msg
    msg="$(echo "$raw_output" | sed -n 's/.*dirty (\(.*\))\.*/\1/p' || true)"
    [[ -z "$msg" ]] && msg="$(echo "$raw_output" | sed -n 's/.*clean (\(.*\))\.*/\1/p' || true)"
    [[ -n "$msg" ]] && HYPR_COMMIT_MSG="$msg"

    if echo "$raw_output" | grep -qi "dirty"; then
      HYPR_DIRTY="dirty"
    fi
  fi

  # Fallback to hypr-tags.env if hyprctl is not active
  if [[ -z "$HYPR_ACTIVE_VER" ]]; then
    local tags_file=""
    for tf in "$HOME/Debian-Hyprland/hypr-tags.env" "/etc/hypr/hypr-tags.env"; do
      if [[ -f "$tf" ]]; then
        tags_file="$tf"
        break
      fi
    done
    if [[ -n "$tags_file" ]]; then
      local env_tag
      env_tag="$(grep -E '^HYPRLAND_TAG=' "$tags_file" | cut -d'=' -f2 | tr -d ' "' || true)"
      if [[ -n "$env_tag" && "$env_tag" != "auto" && "$env_tag" != "latest" ]]; then
        HYPR_ACTIVE_TAG="$env_tag"
        HYPR_ACTIVE_VER="${env_tag#v}"
      fi
    fi
  fi
}

get_fastfetch_wm_version() {
  FASTFETCH_VER=""
  if command -v fastfetch >/dev/null 2>&1; then
    local ff_out
    ff_out="$(fastfetch -s wm 2>/dev/null || true)"
    local ver
    ver="$(echo "$ff_out" | sed 's/\x1b\[[0-9;]*m//g' | grep -i 'WM:' | sed -n 's/.*Hyprland[[:space:]]\+\([0-9][0-9.]*\).*/\1/p' | head -n1 || true)"
    [[ -n "$ver" ]] && FASTFETCH_VER="$ver"
  fi
}

get_header_tag() {
  local file="$1"
  if [[ -f "$file" ]]; then
    local tag
    tag="$(grep -E '^[[:space:]]*#[[:space:]]*define[[:space:]]+GIT_TAG[[:space:]]+' "$file" | awk '{print $3}' | tr -d '" ' || true)"
    echo "${tag#v}"
  fi
}

write_header() {
  local target_dir="$1"
  local target_file="$target_dir/version.h"
  local ver_tag="$2"
  local hash="${3:-unknown}"
  local branch="${4:-main}"
  local msg="${5:-Hyprland build}"
  local dirty="${6:-clean}"

  local content
  content="#pragma once
#define GIT_COMMIT_HASH \"${hash}\"
#define GIT_BRANCH \"${branch}\"
#define GIT_COMMIT_MESSAGE \"${msg}\"
#define GIT_DIRTY \"${dirty}\"
#define GIT_TAG \"${ver_tag}\"
"

  if [[ $DRY_RUN -eq 1 ]]; then
    log_info "[dry-run] Would write header to ${YELLOW}${target_file}${RESET}:"
    echo "$content" | sed 's/^/  [dry-run] /'
    return 0
  fi

  if [[ -w "$target_dir" || (! -d "$target_dir" && -w "$(dirname "$target_dir")") ]]; then
    mkdir -p "$target_dir"
    printf "%s" "$content" > "$target_file"
  else
    sudo mkdir -p "$target_dir"
    printf "%s" "$content" | sudo tee "$target_file" >/dev/null
  fi

  log_ok "Wrote version header to ${GREEN}${target_file}${RESET} (Tag: ${ver_tag})"
}

update_pkgconfig_if_needed() {
  local pc_file="$1"
  local new_ver="$2"

  if [[ -f "$pc_file" ]]; then
    local cur_ver
    cur_ver="$(grep -E '^Version:' "$pc_file" | awk '{print $2}' || true)"
    if [[ -n "$cur_ver" && "$cur_ver" != "$new_ver" ]]; then
      if [[ $DRY_RUN -eq 1 ]]; then
        log_info "[dry-run] Would update ${pc_file} Version from ${cur_ver} to ${new_ver}"
      else
        if [[ -w "$pc_file" ]]; then
          sed -i "s/^Version:.*/Version: ${new_ver}/" "$pc_file"
        else
          sudo sed -i "s/^Version:.*/Version: ${new_ver}/" "$pc_file"
        fi
        log_ok "Updated ${pc_file} Version -> ${new_ver}"
      fi
    fi
  fi
}

# Parse options
while [[ $# -gt 0 ]]; do
  case "$1" in
    -h|--help)
      usage
      exit 0
      ;;\
    -c|--check|-s|--status)
      CHECK_ONLY=1
      ;;
    -d|--dry-run)
      DRY_RUN=1
      ;;
    -f|--force)
      FORCE=1
      ;;
    -q|--quiet)
      QUIET=1
      ;;
    *)
      log_error "Unknown option: $1"
      usage
      exit 1
      ;;
  esac
  shift
done

get_hyprctl_version_info
get_fastfetch_wm_version

primary_hdr_ver="$(get_header_tag "$PRIMARY_HEADER_FILE")"
local_hdr_ver="$(get_header_tag "$LOCAL_HEADER_FILE")"

log_info "Active Hyprland version (hyprctl) : ${GREEN}${HYPR_ACTIVE_VER:-unknown}${RESET}"
log_info "Fastfetch reported WM version     : ${YELLOW}${FASTFETCH_VER:-unknown}${RESET}"
log_info "Primary header ($PRIMARY_HEADER_FILE): ${BLUE}${primary_hdr_ver:-missing}${RESET}"
[[ -f "$LOCAL_HEADER_FILE" ]] && log_info "Local header ($LOCAL_HEADER_FILE): ${BLUE}${local_hdr_ver:-missing}${RESET}"

if [[ -z "$HYPR_ACTIVE_VER" ]]; then
  log_error "Could not detect active Hyprland version from hyprctl or system configs."
  notify_user "critical" "Debian Hyprland Fix" "Could not detect active Hyprland version."
  exit 1
fi

mismatch_detected=0

if [[ -z "$primary_hdr_ver" || "$primary_hdr_ver" != "$HYPR_ACTIVE_VER" ]]; then
  mismatch_detected=1
fi

if [[ -n "$FASTFETCH_VER" && "$FASTFETCH_VER" != "$HYPR_ACTIVE_VER" ]]; then
  mismatch_detected=1
fi

if [[ $CHECK_ONLY -eq 1 ]]; then
  if [[ $mismatch_detected -eq 1 ]]; then
    log_warn "Version mismatch detected: hyprctl=${HYPR_ACTIVE_VER}, fastfetch=${FASTFETCH_VER:-none}, header=${primary_hdr_ver:-missing}"
    exit 1
  else
    log_ok "Versions are in sync (Hyprland ${HYPR_ACTIVE_VER})."
    exit 0
  fi
fi

if [[ $mismatch_detected -eq 0 && $FORCE -eq 0 ]]; then
  log_ok "No mismatch detected. Fastfetch and Hyprland versions match (${GREEN}${HYPR_ACTIVE_VER}${RESET})."
  exit 0
fi

log_info "Resolving version mismatch -> setting headers to ${GREEN}v${HYPR_ACTIVE_VER}${RESET}..."

# Ensure target header contains correct information
write_header "$PRIMARY_HEADER_DIR" "v${HYPR_ACTIVE_VER}" "${HYPR_COMMIT_HASH:-}" "${HYPR_BRANCH:-main}" "${HYPR_COMMIT_MSG:-}" "${HYPR_DIRTY:-clean}"

# Also write to /usr/local/include/hyprland/src if /usr/local/include is used
if [[ -d "/usr/local/include" ]]; then
  write_header "$LOCAL_HEADER_DIR" "v${HYPR_ACTIVE_VER}" "${HYPR_COMMIT_HASH:-}" "${HYPR_BRANCH:-main}" "${HYPR_COMMIT_MSG:-}" "${HYPR_DIRTY:-clean}"
fi

# Sync pkgconfig files
update_pkgconfig_if_needed "/usr/local/share/pkgconfig/hyprland.pc" "$HYPR_ACTIVE_VER"
update_pkgconfig_if_needed "/usr/share/pkgconfig/hyprland.pc" "$HYPR_ACTIVE_VER"

# Validate with fastfetch
if [[ $DRY_RUN -eq 0 ]]; then
  get_fastfetch_wm_version
  if [[ "$FASTFETCH_VER" == "$HYPR_ACTIVE_VER" ]]; then
    log_ok "Verification SUCCESS: Fastfetch now reports Hyprland ${GREEN}${FASTFETCH_VER}${RESET}."
    notify_user "normal" "Hyprland Version Fixed" "Fastfetch and hyprctl are now synchronized to v${FASTFETCH_VER}."
  else
    log_warn "Verification Note: Fastfetch reports '${FASTFETCH_VER}'. If hyprctl is ${HYPR_ACTIVE_VER}, restart terminal to refresh."
  fi
fi
