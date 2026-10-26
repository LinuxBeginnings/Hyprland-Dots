#!/usr/bin/env bash
# ==================================================
#  KoolDots (2026)
#  Project URL: https://github.com/LinuxBeginnings
#  License: GNU GPLv3
#  SPDX-License-Identifier: GPL-3.0-or-later
# ==================================================
# Downloads the distro installer and the current Hyprland-Dots into a temp
# directory under the user's home directory, runs the installer's
# install-scripts/update-deps.sh, then runs copy.sh --tty --express-upgrade.
# At the end it asks before removing the downloaded files.
#
# It needs a terminal: update-deps.sh uses sudo and copy.sh asks questions.
# KooLsDotsUpdate.sh opens one and calls this script, so it is normally not run
# by hand.
#
# Usage: KooLsDotsUpgrade.sh [--dry-run] [--keep-temp] [--force]
#
# Env overrides:
#   KOOLDOTS_UPGRADE_TMP_ROOT  parent for the temp directory (default: $HOME)
#   KOOLDOTS_OS_RELEASE        os-release file to read (default: /etc/os-release)
#   KOOLDOTS_UPGRADE_UID       test seam: pretend to be this uid

# No `set -e`: every step is checked, and a failure has to reach the summary and
# the cleanup prompt instead of ending the run early.
set -uo pipefail

SCRIPT_NAME="$(basename "${BASH_SOURCE[0]}")"
SCRIPTS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LIB_FILE="$SCRIPTS_DIR/lib_dotfiles_upgrade.sh"

if [ ! -f "$LIB_FILE" ]; then
  printf '%s\n' "[ERROR] Missing helper: $LIB_FILE" >&2
  exit 1
fi
# shellcheck source=./lib_dotfiles_upgrade.sh
. "$LIB_FILE"

iDIR="${XDG_CONFIG_HOME:-$HOME/.config}/swaync/images"
LOG_FILE=""
TEMPDIR=""
OS_RELEASE="${KOOLDOTS_OS_RELEASE:-/etc/os-release}"
DRY_RUN=0
KEEP_TEMP=0
FORCE=0

# Set some colors for output messages
if tput sgr0 >/dev/null 2>&1; then
  OK="$(tput setaf 2)[OK]$(tput sgr0)"
  ERROR="$(tput setaf 1)[ERROR]$(tput sgr0)"
  NOTE="$(tput setaf 3)[NOTE]$(tput sgr0)"
  INFO="$(tput setaf 4)[INFO]$(tput sgr0)"
  WARN="$(tput setaf 1)[WARN]$(tput sgr0)"
  CAT="$(tput setaf 6)[ACTION]$(tput sgr0)"
  RESET="$(tput sgr0)"
else
  OK="[OK]"; ERROR="[ERROR]"; NOTE="[NOTE]"; INFO="[INFO]"; WARN="[WARN]"
  CAT="[ACTION]"; RESET=""
fi

# log prints to the terminal and, once the temp directory exists, to the run log
log() {
  printf '%s\n' "$*"
  if [ -n "$LOG_FILE" ]; then
    printf '%s\n' "$*" >>"$LOG_FILE" 2>/dev/null
  fi
  return 0
}

notify() {
  local urgency="${1:-normal}" title="$2" body="$3" icon=""
  command -v notify-send >/dev/null 2>&1 || return 0
  icon="$iDIR/ja.png"
  [ "$urgency" = "critical" ] && icon="$iDIR/error.png"
  [ -f "$icon" ] || icon="dialog-information"
  notify-send -u "$urgency" -i "$icon" "$title" "$body" 2>/dev/null || true
  return 0
}

usage() {
  cat <<EOF
Usage: $SCRIPT_NAME [options]

Downloads the distro installer for this OS and the current Hyprland-Dots into a
temp directory under \$HOME, runs the installer's install-scripts/update-deps.sh,
then runs copy.sh --tty --express-upgrade. A terminal is required.

Options:
  --dry-run    Show the advisory, the resolved installer and branch, the temp
               directory and the exact commands, then exit without changing
               anything.
  --keep-temp  Do not offer to delete the temp directory at the end.
  --force      Skip the check for a newer dotfiles version.
  -h, --help   Show this help and exit.

Env overrides:
  KOOLDOTS_UPGRADE_TMP_ROOT  Parent directory for the temp dir (default: \$HOME)
  KOOLDOTS_OS_RELEASE        os-release file to read (default: /etc/os-release)
EOF
}

while [ $# -gt 0 ]; do
  case "$1" in
  --dry-run) DRY_RUN=1 ;;
  --keep-temp) KEEP_TEMP=1 ;;
  --force) FORCE=1 ;;
  -h | --help)
    usage
    exit 0
    ;;
  *)
    echo "${ERROR} Unknown option: $1" >&2
    usage >&2
    exit 2
    ;;
  esac
  shift
done

# join the arguments of a command line for display, without re-quoting them
show_cmd() {
  local arg out=""
  for arg in "$@"; do
    out+="$arg "
  done
  printf '%s' "${out% }"
}

# ---- preflight -------------------------------------------------------------
if kdu_running_as_root; then
  log "${ERROR} This script must NOT be run as root. Exiting."
  exit 1
fi

missing=()
for cmd in git curl rsync; do
  command -v "$cmd" >/dev/null 2>&1 || missing+=("$cmd")
done
if [ ${#missing[@]} -gt 0 ]; then
  log "${ERROR} Missing required command(s): ${missing[*]}"
  notify critical "KooL Dots upgrade" "Missing: ${missing[*]}"
  exit 1
fi

# ---- which installer does this OS need -------------------------------------
distro="$(kdu_distro_detect "$OS_RELEASE")"
if ! kdu_supported_distro "$distro"; then
  log "${WARN} Automatic upgrade is not available for this OS (${distro})."
  log "${INFO} NixOS and Gentoo are not covered, and neither is any other distro."
  log "${INFO} Upgrade the dotfiles by hand: docs/HOWTO-Upgrade-Dotfiles.md"
  notify normal "KooL Dots upgrade" "Automatic upgrade is not available for this OS."
  exit 0
fi

repo="$(kdu_repo_for_distro "$distro")"
version_id="$(kdu_os_release_value "$OS_RELEASE" VERSION_ID || true)"
branch="main"
if [ "$(kdu_branch_mode_for_distro "$distro")" = "per-release" ]; then
  branches="$(kdu_remote_branches "$repo" || true)"
  branch="$(kdu_branch_for_distro "$distro" "$version_id" "$branches")"
  if [ "$branch" = "main" ]; then
    log "${WARN} No $repo branch matches ${version_id:-this release}; using main."
  fi
fi

# A terminal is only needed for the real run: --dry-run changes nothing.
if [ "$DRY_RUN" -eq 0 ]; then
  if [ ! -t 0 ] || [ ! -t 1 ]; then
    log "${ERROR} A terminal is required: update-deps.sh needs sudo and copy.sh asks questions."
    notify critical "KooL Dots upgrade" "A terminal is required. Run $SCRIPT_NAME from a terminal."
    exit 1
  fi

  LOCK_FILE="${XDG_RUNTIME_DIR:-/tmp}/kooldots-upgrade-$(id -u).lock"
  if command -v flock >/dev/null 2>&1; then
    if ! exec 9>"$LOCK_FILE"; then
      log "${ERROR} Cannot create the lock file: $LOCK_FILE"
      exit 1
    fi
    if ! flock -n 9; then
      log "${WARN} Another KooL dots upgrade is already running."
      notify normal "KooL Dots upgrade" "Another upgrade is already running."
      exit 1
    fi
  fi
fi

# ---- advisory --------------------------------------------------------------
log ""
log "${NOTE} Before upgrading, please make sure:"
log "  - Your OS is fully up to date, including a reboot if the update asks for one."
if [ "$distro" = "debian" ]; then
  log "  - If you built Hyprland from source, you are on the most current version."
  log "    How to upgrade Hyprland:"
  log "    ${KDU_DEBIAN_GUIDE_URL}"
fi
log ""

if [ "$DRY_RUN" -eq 1 ]; then
  tmp_root="${KOOLDOTS_UPGRADE_TMP_ROOT:-$HOME}"
  TEMPDIR="$(kdu_tempdir_label "$tmp_root")"
  log "${INFO} --dry-run: nothing is downloaded and nothing is changed."
  log "${INFO} Installer : $repo (branch $branch)"
  log "${INFO} Temp dir  : $TEMPDIR"
  log "${INFO} Then      : $TEMPDIR/$repo and $TEMPDIR/Hyprland-Dots"
  log ""
  log "${INFO} Commands, in order:"
  clone_args=()
  while IFS= read -r arg; do clone_args+=("$arg"); done < <(kdu_clone_args "$repo" "$branch" "$TEMPDIR/$repo")
  log "  1. git $(show_cmd "${clone_args[@]}")"
  clone_args=()
  while IFS= read -r arg; do clone_args+=("$arg"); done < <(kdu_clone_args "Hyprland-Dots" "main" "$TEMPDIR/Hyprland-Dots")
  log "  2. git $(show_cmd "${clone_args[@]}")"
  log "  3. $(kdu_updatedeps_cmd "$repo" "$TEMPDIR")"
  log "  4. $(kdu_copy_cmd "$TEMPDIR")"
  log ""
  log "${INFO} Afterwards it asks before removing $TEMPDIR."
  exit 0
fi

# ---- is there still something to upgrade -----------------------------------
if [ "$FORCE" -eq 0 ]; then
  installed_version="$(kdu_installed_dots_version || true)"
  remote_version="$(kdu_remote_dots_version || true)"
  if [ -z "$installed_version" ] || [ -z "$remote_version" ]; then
    log "${NOTE} Could not compare versions (installed ${installed_version:-unknown}, remote ${remote_version:-unknown}); continuing."
  elif kdu_version_is_newer "$remote_version" "$installed_version"; then
    log "${OK} Update available: v${installed_version} -> v${remote_version}."
  else
    log "${NOTE} No newer dotfiles version detected (installed v${installed_version}, remote v${remote_version})."
    printf '%s' "${CAT} Upgrade anyway? [y/N]: "
    read -r answer || answer=""
    case "${answer,,}" in
    y | yes) ;;
    *)
      log "${INFO} Aborted at your request. Nothing was changed."
      exit 0
      ;;
    esac
  fi
fi

printf '%s' "${CAT} Download the installer and upgrade now? [y/N]: "
read -r answer || answer=""
case "${answer,,}" in
y | yes) ;;
*)
  log "${INFO} Aborted at your request. Nothing was changed."
  exit 0
  ;;
esac

# ---- temp directory --------------------------------------------------------
tmp_root="${KOOLDOTS_UPGRADE_TMP_ROOT:-$HOME}"
TEMPDIR="$(kdu_tempdir_create "$tmp_root")" || {
  log "${ERROR} Could not create a temp directory under $tmp_root"
  exit 1
}
LOG_FILE="$TEMPDIR/kooldots-upgrade.log"
log "${INFO} Working directory: $TEMPDIR"

# ---- clones ----------------------------------------------------------------
clone_repo() { # <repo> <branch> <dest>
  local args=()
  while IFS= read -r arg; do args+=("$arg"); done < <(kdu_clone_args "$1" "$2" "$3")
  git "${args[@]}"
}

if ! clone_repo "$repo" "$branch" "$TEMPDIR/$repo"; then
  log "${ERROR} Could not clone $repo. Check your network connection."
  notify critical "KooL Dots upgrade" "Could not clone $repo."
  rm -rf -- "$TEMPDIR"
  exit 1
fi
if ! clone_repo "Hyprland-Dots" "main" "$TEMPDIR/Hyprland-Dots"; then
  log "${ERROR} Could not clone Hyprland-Dots. Check your network connection."
  notify critical "KooL Dots upgrade" "Could not clone Hyprland-Dots."
  rm -rf -- "$TEMPDIR"
  exit 1
fi

# ---- dependencies ----------------------------------------------------------
deps_ok=1
if [ ! -f "$TEMPDIR/$repo/install-scripts/update-deps.sh" ]; then
  log "${WARN} $repo has no install-scripts/update-deps.sh; skipping the dependency step."
  deps_ok=0
else
  deps_cmd="$(kdu_updatedeps_cmd "$repo" "$TEMPDIR")"
  log "${INFO} Running: $deps_cmd"
  if ! bash -c "$deps_cmd"; then
    deps_ok=0
    log "${WARN} update-deps.sh reported a problem. See $TEMPDIR/$repo/Install-Logs/"
    printf '%s' "${CAT} Continue with the dotfiles copy anyway? [y/N]: "
    read -r answer || answer=""
    case "${answer,,}" in
    y | yes) ;;
    *)
      log "${INFO} Stopping here. Nothing was copied."
      log "${NOTE} Keeping $TEMPDIR. Remove it with: rm -rf -- $TEMPDIR"
      exit 1
      ;;
    esac
  fi
fi

# ---- dotfiles --------------------------------------------------------------
copy_cmd="$(kdu_copy_cmd "$TEMPDIR")"
log "${INFO} Running: $copy_cmd"
copy_status=0
bash -c "$copy_cmd" || copy_status=$?

# ---- summary ---------------------------------------------------------------
log ""
if [ "$deps_ok" -eq 0 ]; then
  log "${NOTE} The dependency step did not finish cleanly; check its log before rebooting."
fi
if [ "$copy_status" -eq 0 ]; then
  log "${OK} Dotfiles upgrade finished."
  log "${INFO} Installer logs: $TEMPDIR/$repo/Install-Logs/"
  log "${INFO} Copy logs:      $TEMPDIR/Hyprland-Dots/Copy-Logs/"
  log "${NOTE} Reboot when convenient so the session picks up the new config."
  notify normal "KooL Dots upgrade" "Upgrade finished. Reboot when convenient."
else
  log "${WARN} copy.sh exited with status $copy_status. Check the output above."
  log "${INFO} Installer logs: $TEMPDIR/$repo/Install-Logs/"
  log "${INFO} Copy logs:      $TEMPDIR/Hyprland-Dots/Copy-Logs/"
  notify critical "KooL Dots upgrade" "copy.sh reported a problem (exit $copy_status)."
fi

# ---- cleanup ---------------------------------------------------------------
if [ "$KEEP_TEMP" -eq 1 ]; then
  log "${INFO} Keeping $TEMPDIR (--keep-temp)."
elif [ "$copy_status" -ne 0 ]; then
  log "${NOTE} Keeping $TEMPDIR because the run did not complete."
  log "${NOTE} Remove it later with: rm -rf -- $TEMPDIR"
else
  printf '%s' "${CAT} Remove $TEMPDIR and the downloaded files? [y/N]: "
  read -r answer || answer=""
  case "${answer,,}" in
  y | yes)
    if rm -rf -- "$TEMPDIR"; then
      LOG_FILE=""
      log "${OK} Removed $TEMPDIR"
    else
      log "${WARN} Could not remove $TEMPDIR"
    fi
    ;;
  *)
    log "${NOTE} Kept $TEMPDIR. Remove it later with: rm -rf -- $TEMPDIR"
    ;;
  esac
fi

exit "$copy_status"
