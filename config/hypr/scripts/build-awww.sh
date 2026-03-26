#!/usr/bin/env bash
set -euo pipefail

RED="\033[0;31m"
GREEN="\033[0;32m"
YELLOW="\033[1;33m"
BLUE="\033[0;34m"
NC="\033[0m"

ICON_OK="✅"
ICON_WARN="⚠️"
ICON_ERR="❌"
ICON_INFO="ℹ️"

fail() {
  printf "${RED}${ICON_ERR} %s${NC}\n" "$1" >&2
  exit 1
}

info() {
  printf "${BLUE}${ICON_INFO} %s${NC}\n" "$1"
}

warn() {
  printf "${YELLOW}${ICON_WARN} %s${NC}\n" "$1"
}

ok() {
  printf "${GREEN}${ICON_OK} %s${NC}\n" "$1"
}

trap 'fail "Script failed at line $LINENO."' ERR

if [[ ! -t 0 ]]; then
  fail "This script requires an interactive terminal. Run it directly in a terminal (e.g. ./build-awww.sh)."
fi

info "Starting awww installer..."

if command -v awww >/dev/null 2>&1; then
  ok "awww is already installed. Nothing to do."
  exit 0
fi

if ! command -v git >/dev/null 2>&1; then
  fail "git is required but not installed."
fi

detect_distro() {
  if [[ -r /etc/os-release ]]; then
    # shellcheck disable=SC1091
    . /etc/os-release
    echo "${ID:-}"
    return
  fi
  echo ""
}

prompt_confirm_distro() {
  local detected="$1"
  local choice=""
  if [[ -n "$detected" ]]; then
    printf "${BLUE}${ICON_INFO} Detected distro: %s${NC}\n" "$detected" >/dev/tty
    printf "Confirm? (Y/y to confirm, N/n to choose, Q/q to quit): " >/dev/tty
    read -r choice </dev/tty
    case "$choice" in
      [Yy]) echo "$detected"; return ;;
      [Qq]) exit 0 ;;
      [Nn]) ;;
      *) warn "Invalid choice, continuing to manual selection." ;;
    esac
  fi
  echo "Supported distros:"
  echo "  1) debian"
  echo "  2) ubuntu"
  echo "  3) arch"
  echo "  4) opensuse"
  echo "  5) fedora"
  echo "  6) gentoo"
  printf "Select your distro (1-6) or Q/q to quit: " >/dev/tty
  read -r choice </dev/tty
  read -r choice
  case "$choice" in
    1) echo "debian" ;;
    2) echo "ubuntu" ;;
    3) echo "arch" ;;
    4) echo "opensuse" ;;
    5) echo "fedora" ;;
    6) echo "gentoo" ;;
    [Qq]) exit 0 ;;
    *) fail "Invalid selection." ;;
  esac
}

distro="$(prompt_confirm_distro "$(detect_distro)")"

install_deps_debian_ubuntu() {
  local missing=()
  for pkg in pkg-config liblz4-dev; do
    dpkg -s "$pkg" >/dev/null 2>&1 || missing+=("$pkg")
  done
  if (( ${#missing[@]} )); then
    info "Installing deps: ${missing[*]}"
    sudo apt update
    sudo apt install -y "${missing[@]}"
  else
    ok "All required deps already installed."
  fi
}

install_deps_fedora() {
  local missing=()
  for pkg in wayland-protocols lz4-devel wayland-devel; do
    rpm -q "$pkg" >/dev/null 2>&1 || missing+=("$pkg")
  done
  if (( ${#missing[@]} )); then
    info "Installing deps: ${missing[*]}"
    sudo dnf install -y "${missing[@]}"
  else
    ok "All required deps already installed."
  fi
}

install_deps_opensuse() {
  local missing=()
  for pkg in pkg-config liblz4-devel; do
    rpm -q "$pkg" >/dev/null 2>&1 || missing+=("$pkg")
  done
  if (( ${#missing[@]} )); then
    info "Installing deps: ${missing[*]}"
    sudo zypper install -y "${missing[@]}"
  else
    ok "All required deps already installed."
  fi
}

install_deps_arch() {
  local missing=()
  for pkg in pkgconf lz4 wayland-protocols; do
    pacman -Qi "$pkg" >/dev/null 2>&1 || missing+=("$pkg")
  done
  if (( ${#missing[@]} )); then
    info "Installing deps: ${missing[*]}"
    sudo pacman -S --needed --noconfirm "${missing[@]}"
  else
    ok "All required deps already installed."
  fi
}

ensure_cargo() {
  if command -v cargo >/dev/null 2>&1; then
    ok "cargo is available."
    return
  fi
  case "$distro" in
    debian|ubuntu|fedora|opensuse)
      info "Installing Rust toolchain via rustup..."
      curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y
      # shellcheck disable=SC1091
      source "$HOME/.cargo/env"
      ;;
    arch)
      info "Installing Rust toolchain..."
      sudo pacman -S --needed --noconfirm rust
      ;;
    gentoo)
      ;;
    *)
      fail "Unknown distro for cargo install."
      ;;
  esac
  command -v cargo >/dev/null 2>&1 || fail "cargo is still not available."
}

case "$distro" in
  debian) install_deps_debian_ubuntu ;;
  ubuntu) install_deps_debian_ubuntu ;;
  fedora) install_deps_fedora ;;
  opensuse) install_deps_opensuse ;;
  arch) install_deps_arch ;;
  gentoo)
    info "Installing awww via Portage..."
    sudo emerge gui-apps/awww
    ok "awww installed successfully."
    exit 0
    ;;
  *) fail "Unsupported distro: $distro" ;;
esac

ensure_cargo

info "Cloning or updating awww..."
cd "$HOME"
if [[ -d awww/.git ]]; then
  git -C awww pull --rebase
else
  git clone https://codeberg.org/LGFae/awww.git
fi

cd "$HOME/awww"
info "Building awww..."
cargo build --release

info "Installing binaries..."
sudo install -vDm755 target/release/awww -t /usr/bin/
sudo install -vDm755 target/release/awww-daemon -t /usr/bin/
sudo install -vDm644 completions/_awww -t /usr/share/zsh/site-functions/

ok "awww installed successfully."
