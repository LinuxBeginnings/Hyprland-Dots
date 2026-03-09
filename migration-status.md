# Migration Status (AWWW fallback)
Date: 2026-03-09
Branch: awww-conversion
Host: CachyOS VM (Warp installed, direct commands)

## Goal
Replace all direct SWWW calls with AWWW-first fallback to SWWW, without breaking existing users. Commands are compatible; daemon name changes to `awww-daemon`.

## Completed changes (repo)
Added:
- `config/hypr/scripts/WallpaperCmd.sh`
  - Selects `WWW_CMD` (`awww` or `swww`), `WWW_DAEMON` (`awww-daemon` or `swww-daemon`), `WWW_CACHE_DIR`.
- `config/hypr/scripts/WallpaperDaemon.sh`
  - Starts daemon using `WallpaperCmd.sh`.

Updated to use helper:
- `config/hypr/configs/Startup_Apps.conf`
  - `exec-once = $scriptsDir/WallpaperDaemon.sh`
  - Persistent wallpaper comment updated with awww fallback.
- `config/hypr/scripts/WallustSwww.sh`
  - Uses `WallpaperCmd.sh`, cache dir now `WWW_CACHE_DIR`, `swww query` → `$WWW_CMD query`.
- `config/hypr/scripts/DarkLight.sh`
  - Uses `WWW_CMD/WWW_DAEMON`.
- `config/hypr/scripts/GameMode.sh`
  - Uses `WWW_CMD/WWW_DAEMON`.
- `config/hypr/initial-boot.sh`
  - Uses `WWW_CMD/WWW_DAEMON`.
- `config/hypr/UserScripts/WallpaperSelect.sh`
  - Uses helper, daemon start uses `WWW_DAEMON`, image uses `WWW_CMD`.
  - Startup config toggles now include `WallpaperDaemon.sh` and legacy `swww-daemon` lines for backward compat.
  - Removed duplicate sed lines.
- `config/hypr/UserScripts/WallpaperAutoChange.sh`
  - Uses `WWW_CMD`.
- `config/hypr/UserScripts/WallpaperRandom.sh`
  - Uses `WWW_CMD/WWW_DAEMON`.
- `config/hypr/UserScripts/WallpaperEffects.sh`
  - Uses `WWW_CMD`.
- `config/hypr/scripts/KeyHints.sh`
  - UI text updated to “awww/swww”.

## Remaining swww mentions (expected)
Only in:
- Helper fallback strings in `WallpaperCmd.sh`
- Comments/UI text
- SWWW_* transition env vars
- Legacy `swww-daemon` sed lines in WallpaperSelect.sh for backward compatibility

## Live config sync
Live Hypr config is NOT symlinked.
Copied repo config to live:
```
cp -a /home/dwilliams/Hyprland-Dots/config/hypr/. /home/dwilliams/.config/hypr/
```

## No commits/pushes
User requested: do NOT commit or push. None were done.

## Next steps to test
1) Logout/login (to start awww-daemon via `WallpaperDaemon.sh`).
2) Verify `awww` / `awww-daemon` installed and in PATH (awww-git on Arch).
3) Test:
   - Wallpaper select (SUPER+W), random (CTRL+ALT+W), effects (SUPER+SHIFT+W)
   - GameMode toggle (ensures daemon fallback path works)
   - Dark/Light switch (wallpaper changes)

## If issues
Check:
- `~/.config/hypr/scripts/WallpaperCmd.sh` selects correct command.
- `exec-once = $scriptsDir/WallpaperDaemon.sh` is active in `~/.config/hypr/configs/Startup_Apps.conf`.
- AWWW binaries exist: `command -v awww` and `awww-daemon`.

## Phase 2  Add awww-daemon and awww to Distro-Hyprland installers 
- debian 
```bash 
git clone https://codeberg.org/LGFae/awww.git
cd awww
cargo build --release

sudo install -vDm755 target/release/awww -t /usr/bin/
sudo install -vDm755 target/release/awww-daemon -t /usr/bin/
# For Zsh
sudo install -vDm644 completions/_awww -t /usr/share/zsh/site-functions/
# For Fish
sudo install -vDm644 completions/awww.fish -t /usr/share/fish/vendor_completions.d/

```
 - ubuntu (24.04 / 25.10 / 26.04)
 ```bash
 # Install Rust toolchain (if not already)
 curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh
 source "$HOME/.cargo/env"
 
 # Build from source
 git clone https://codeberg.org/LGFae/awww.git
 cd awww
 cargo build --release
 
 sudo install -vDm755 target/release/awww -t /usr/bin/
 sudo install -vDm755 target/release/awww-daemon -t /usr/bin/
 # For Zsh
 sudo install -vDm644 completions/_awww -t /usr/share/zsh/site-functions/
 # For Fish
 sudo install -vDm644 completions/awww.fish -t /usr/share/fish/vendor_completions.d/
 
 # If build fails, install deps:
 # sudo apt install -y pkg-config liblz4-dev
 ```
 - fedora
 ```bash
 # Install Rust toolchain (if not already)
 curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh
 source "$HOME/.cargo/env"
 
 git clone https://codeberg.org/LGFae/awww.git
 cd awww
 cargo build --release
 
 sudo install -vDm755 target/release/awww -t /usr/bin/
 sudo install -vDm755 target/release/awww-daemon -t /usr/bin/
 # For Zsh
 sudo install -vDm644 completions/_awww -t /usr/share/zsh/site-functions/
 # For Fish
 sudo install -vDm644 completions/awww.fish -t /usr/share/fish/vendor_completions.d/
 
 # If build fails, install deps:
 # sudo dnf install -y pkgconf-pkg-config lz4-devel
 ```
 - openSUSE
 ```bash
 # Install Rust toolchain (if not already)
 curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh
 source "$HOME/.cargo/env"
 
 git clone https://codeberg.org/LGFae/awww.git
 cd awww
 cargo build --release
 
 sudo install -vDm755 target/release/awww -t /usr/bin/
 sudo install -vDm755 target/release/awww-daemon -t /usr/bin/
 # For Zsh
 sudo install -vDm644 completions/_awww -t /usr/share/zsh/site-functions/
 # For Fish
 sudo install -vDm644 completions/awww.fish -t /usr/share/fish/vendor_completions.d/
 
 # If build fails, install deps:
 # sudo zypper install -y pkg-config liblz4-devel
 ```
 - gentoo
 ```bash
 sudo emerge gui-apps/awww
 ```

