#!/usr/bin/env bash
# ==================================================
#  KoolDots (2026)
#  Project URL: https://github.com/LinuxBeginnings
#  License: GNU GPLv3
#  SPDX-License-Identifier: GPL-3.0-or-later
# ==================================================
# Helpers for KooLsDotsUpgrade.sh: the download-and-upgrade flow that pulls the
# distro installer and Hyprland-Dots into a temp directory under $HOME, runs the
# installer's install-scripts/update-deps.sh, then runs
# copy.sh --tty --express-upgrade.
#
# Everything here is a small, pure function so the flow can be tested without a
# real system: distro detection, installer/branch resolution, the temp
# directory, the command lines, and the version comparison. The one exception is
# kdu_remote_branches, which asks GitHub and is therefore not unit tested.
#
# This file is sourced, never executed.

# The upgrade guide linked from the preflight advisory on Debian.
KDU_DEBIAN_GUIDE_URL="https://github.com/LinuxBeginnings/Debian-Hyprland/blob/main/Debian-Hyprland-Install-Upgrade.md"

# Where the dotfiles-only distros are told to get their packages. There is no
# installer to run update-deps.sh for them, so the wiki is the dependency list.
KDU_PACKAGES_WIKI_URL="https://github.com/LinuxBeginnings/Hyprland-Dots/wiki/Packages_Required"

# kdu_running_as_root -> 0 when the effective uid is 0.
# KOOLDOTS_UPGRADE_UID is a test seam: it lets the suite exercise the refusal
# without becoming root. It can only ever make the script refuse more.
kdu_running_as_root() {
  [ "${KOOLDOTS_UPGRADE_UID:-${EUID:-$(id -u)}}" -eq 0 ]
}

# kdu_os_release_value <file> <KEY> -> the value, quotes stripped
# Either quote style is stripped, because both are in the wild: Gentoo writes
# `ID='gentoo'`, and the double-quoted form is what the spec shows. Stripping
# only one left the value with its quotes, so ID read as 'gentoo' and the distro
# fell through to unknown.
kdu_os_release_value() {
  local file="$1" key="$2"
  [ -f "$file" ] || return 1
  sed -nE "s/^[[:space:]]*${key}=//p" "$file" | tail -n1 | sed -E "s/^['\"]//; s/['\"]\$//"
}

# kdu_distro_from_osrelease <file> -> debian|ubuntu|arch|fedora|opensuse|nixos|gentoo|unknown
# Reads the file only, so it is deterministic and testable. Mint and Zorin are
# named directly and treated as Ubuntu. Other derivatives resolve through
# ID_LIKE, ordered most specific first: Pop!_OS reports "ubuntu debian" and
# belongs with Ubuntu, Kali reports "debian" and belongs with Debian.
kdu_distro_from_osrelease() {
  local file="$1" id like word
  id="$(kdu_os_release_value "$file" ID || true)"
  like="$(kdu_os_release_value "$file" ID_LIKE || true)"

  case "$id" in
  debian) echo debian; return 0 ;;
  ubuntu | linuxmint | zorin) echo ubuntu; return 0 ;;
  nixos) echo nixos; return 0 ;;
  gentoo) echo gentoo; return 0 ;;
  arch | archarm | artix | endeavouros | manjaro | cachyos) echo arch; return 0 ;;
  fedora | rhel | centos | rocky | almalinux) echo fedora; return 0 ;;
  opensuse* | suse | sles) echo opensuse; return 0 ;;
  esac

  for word in $like; do
    case "$word" in
    ubuntu) echo ubuntu; return 0 ;;
    debian) echo debian; return 0 ;;
    arch) echo arch; return 0 ;;
    fedora | rhel) echo fedora; return 0 ;;
    suse | opensuse) echo opensuse; return 0 ;;
    esac
  done

  echo unknown
}

# kdu_distro_detect <file> -> kdu_distro_from_osrelease, then package managers
# The probes cover a host whose os-release does not name a known family.
kdu_distro_detect() {
  local file="${1:-/etc/os-release}" key
  key="$(kdu_distro_from_osrelease "$file")"
  if [ "$key" = "unknown" ]; then
    if command -v pacman >/dev/null 2>&1; then
      key="arch"
    elif command -v dnf >/dev/null 2>&1; then
      key="fedora"
    elif command -v zypper >/dev/null 2>&1; then
      key="opensuse"
    fi
  fi
  printf '%s' "$key"
}

# kdu_repo_for_distro <key> -> installer repository name, non-zero if unsupported
# NixOS and Gentoo are deliberately absent: NixOS is declarative and has no
# update-deps.sh, and there is no Gentoo installer repo.
kdu_repo_for_distro() {
  case "${1:-}" in
  debian) echo "Debian-Hyprland" ;;
  ubuntu) echo "Ubuntu-Hyprland" ;;
  arch) echo "Arch-Hyprland" ;;
  fedora) echo "Fedora-Hyprland" ;;
  opensuse) echo "OpenSUSE-Hyprland" ;;
  *) return 1 ;;
  esac
}

# kdu_branch_mode_for_distro <key> -> main|per-release
kdu_branch_mode_for_distro() {
  case "${1:-}" in
  ubuntu) echo "per-release" ;;
  debian | arch | fedora | opensuse) echo "main" ;;
  *) return 1 ;;
  esac
}

# kdu_supported_distro <key> -> 0 when the flow can upgrade this OS
kdu_supported_distro() {
  kdu_repo_for_distro "${1:-}" >/dev/null 2>&1
}

# kdu_dotfiles_only_distro <key> -> 0 when only the dots can be upgraded
# NixOS is declarative and ships no update-deps.sh, and there is no Gentoo
# installer repo, so both skip the installer and the dependency step. The list
# is explicit rather than "everything unsupported": an unrecognised distro keeps
# the old check-only notice instead.
kdu_dotfiles_only_distro() {
  case "${1:-}" in
  nixos | gentoo) return 0 ;;
  *) return 1 ;;
  esac
}

# kdu_repo_url <repo> -> the clone URL
kdu_repo_url() {
  printf 'https://github.com/LinuxBeginnings/%s.git' "$1"
}

# kdu_remote_branches <repo> -> one branch name per line (network)
kdu_remote_branches() {
  git ls-remote --heads "$(kdu_repo_url "$1")" 2>/dev/null | sed -n 's#.*refs/heads/##p'
}

# kdu_branch_for_distro <key> <version_id> <available_branches> -> branch
# Ubuntu's installer is branched per release. The exact release wins, then its
# -development branch, then main, so a release without a branch still upgrades.
kdu_branch_for_distro() {
  local distro="$1" version_id="$2" available="$3" branch
  local mode
  mode="$(kdu_branch_mode_for_distro "$distro")" || return 1

  if [ "$mode" = "main" ]; then
    echo "main"
    return 0
  fi

  [ -n "$version_id" ] || { echo "main"; return 0; }

  for branch in $available; do
    if [ "$branch" = "$version_id" ]; then
      echo "$version_id"
      return 0
    fi
  done
  for branch in $available; do
    if [ "$branch" = "$version_id-development" ]; then
      echo "$version_id-development"
      return 0
    fi
  done

  echo "main"
}

# kdu_branch_override <id> <version_id> -> a branch, or empty for no override
# Mint and Zorin are Ubuntu 24.04 based for now, so they take that branch whatever
# their own VERSION_ID says. Ubuntu 26.10 predates a branch of its own and still
# runs the 26.04 installer. Both skip the upstream branch probe.
kdu_branch_override() {
  case "${1:-}" in
  linuxmint | zorin) printf '%s' "24.04" ;;
  ubuntu)
    case "${2:-}" in
    26.10) printf '%s' "26.04" ;;
    esac
    ;;
  esac
}

# kdu_release_notice <id> <version_id> -> a warning to show, or empty
kdu_release_notice() {
  if [ "${1:-}" = "ubuntu" ] && [ "${2:-}" = "26.10" ]; then
    printf '%s' "Ubuntu 26.10 not officially supported. Use at own risk"
  fi
}

# kdu_clone_args <repo> <branch> <dest> -> one git argument per line
# The `clone` subcommand is the first line, so the list is a complete git command
# line: the dry-run display and the real invocation are then the same command.
# Without it, git is handed --depth=1 as a top-level option and refuses to run.
kdu_clone_args() {
  local repo="$1" branch="$2" dest="$3"
  printf '%s\n' "clone" "--depth=1"
  if [ -n "$branch" ] && [ "$branch" != "main" ]; then
    printf '%s\n' "-b" "$branch"
  fi
  printf '%s\n' "$(kdu_repo_url "$repo")" "$dest"
}

# kdu_updatedeps_cmd <repo> <tmpdir> -> the dependency command line
kdu_updatedeps_cmd() {
  printf 'bash "%s/%s/install-scripts/update-deps.sh"' "$2" "$1"
}

# kdu_copy_cmd <tmpdir> -> the dotfiles command line
# --tty forces the plain prompts instead of whiptail; --express-upgrade skips
# the restore questions.
kdu_copy_cmd() {
  printf 'cd "%s/Hyprland-Dots" && ./copy.sh --tty --express-upgrade' "$1"
}

# kdu_tempdir_create <root> -> an existing random temp directory
kdu_tempdir_create() {
  local root="${1:-$HOME}"
  [ -d "$root" ] || mkdir -p "$root" || return 1
  mktemp -d "$root/kooldots-upgrade-XXXXXX"
}

# kdu_tempdir_label <root> -> what --dry-run prints in place of a real path
kdu_tempdir_label() {
  printf '%s/kooldots-upgrade-<random>' "${1:-$HOME}"
}

# kdu_installed_dots_version [config_dir] -> the installed version, no leading v
# Same precedence KooLsDotsUpdate.sh uses: DOTS_VERSION in lua/env.lua, then the
# vX.Y.Z marker file copy.sh reads.
kdu_installed_dots_version() {
  local config_dir="${1:-${XDG_CONFIG_HOME:-$HOME/.config}/hypr}"
  local env_lua="$config_dir/lua/env.lua" version=""

  if [ -f "$env_lua" ]; then
    version="$(sed -n -E 's/^[[:space:]]*hl\.env\([[:space:]]*"DOTS_VERSION"[[:space:]]*,[[:space:]]*"([^"]+)".*/\1/p' "$env_lua" | head -n1 || true)"
    if [ -z "$version" ]; then
      version="$(sed -n -E 's/^[[:space:]]*DOTS_VERSION[[:space:]]*=[[:space:]]*"([^"]+)".*/\1/p' "$env_lua" | head -n1 || true)"
    fi
  fi

  if [ -z "$version" ] && [ -d "$config_dir" ]; then
    version="$(find "$config_dir" -maxdepth 1 -name 'v*' -printf '%f\n' 2>/dev/null | sort -V | tail -n1 || true)"
  fi

  printf '%s' "${version#v}"
}

# kdu_remote_dots_version [url] -> upstream DOTS_VERSION, no leading v (network)
kdu_remote_dots_version() {
  local url="${1:-https://raw.githubusercontent.com/LinuxBeginnings/Hyprland-Dots/main/config/hypr/lua/env.lua}"
  local body version=""
  body="$(curl -fsSL -m 10 -A "Mozilla/5.0" "$url" 2>/dev/null || true)"
  [ -n "$body" ] || return 1
  version="$(printf '%s\n' "$body" | sed -n -E 's/^[[:space:]]*hl\.env\([[:space:]]*"DOTS_VERSION"[[:space:]]*,[[:space:]]*"([^"]+)".*/\1/p' | head -n1 || true)"
  if [ -z "$version" ]; then
    version="$(printf '%s\n' "$body" | sed -n -E 's/^[[:space:]]*DOTS_VERSION[[:space:]]*=[[:space:]]*"([^"]+)".*/\1/p' | head -n1 || true)"
  fi
  [ -n "$version" ] || return 1
  printf '%s' "${version#v}"
}

# kdu_version_is_newer <candidate> <current> -> 0 when candidate is higher
kdu_version_is_newer() {
  local candidate="${1#v}" current="${2#v}"
  [ -n "$candidate" ] && [ -n "$current" ] || return 1
  [ "$candidate" = "$current" ] && return 1
  [ "$(printf '%s\n%s\n' "$candidate" "$current" | sort -V | tail -n1)" = "$candidate" ]
}
