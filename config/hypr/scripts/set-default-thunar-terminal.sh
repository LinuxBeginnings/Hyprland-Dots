#!/usr/bin/env bash
# ==================================================
#  KoolDots (2026)
#  Project URL: https://github.com/LinuxBeginnings
#  License: GNU GPLv3
#  SPDX-License-Identifier: GPL-3.0-or-later
# ==================================================
#
setup_default_terminal() {
  echo "Setting kitty as the default terminal for Thunar and CLI apps..."

  # 1. Configure XFCE/Exo (Thunar's primary helper)
  # This handles "Open Terminal Here" and "Open with [CLI App]"
  HELPER_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/xfce4"
  mkdir -p "$HELPER_DIR"
  KITTY_PATH="$(command -v kitty 2>/dev/null || true)"
  if [ -z "$KITTY_PATH" ]; then
    echo "Warning: kitty not found in PATH. Thunar may report no terminal available."
  fi
  # Prefer exo-preferred-applications when available (XFCE/Thunar)
  if command -v exo-preferred-applications >/dev/null 2>&1; then
    exo-preferred-applications --set TerminalEmulator kitty >/dev/null 2>&1 || true
  fi

  # Ensure helpers.rc exists and has a [Default] section
  if [ ! -f "$HELPER_DIR/helpers.rc" ]; then
    printf "[Default]\n" >"$HELPER_DIR/helpers.rc"
  elif ! grep -q '^\[Default\]$' "$HELPER_DIR/helpers.rc"; then
    printf "[Default]\n%s" "$(cat "$HELPER_DIR/helpers.rc")" >"$HELPER_DIR/helpers.rc"
  fi

  # Update TerminalEmulator entry in [Default] section
  if grep -q '^TerminalEmulator=' "$HELPER_DIR/helpers.rc"; then
    sed -i 's|^TerminalEmulator=.*|TerminalEmulator=kitty|' "$HELPER_DIR/helpers.rc"
  else
    sed -i '/^\[Default\]$/a TerminalEmulator=kitty' "$HELPER_DIR/helpers.rc"
  fi
  # Set a full path if available (GUI PATH can differ)
  if [ -n "$KITTY_PATH" ]; then
    if grep -q '^TerminalEmulatorPath=' "$HELPER_DIR/helpers.rc"; then
      sed -i "s|^TerminalEmulatorPath=.*|TerminalEmulatorPath=$KITTY_PATH|" "$HELPER_DIR/helpers.rc"
    else
      sed -i "/^\[Default\]$/a TerminalEmulatorPath=$KITTY_PATH" "$HELPER_DIR/helpers.rc"
    fi
  fi

  # 2. Create a User-Level "xterm" Shim
  # Many older .desktop files and scripts have 'xterm' hardcoded.
  # By placing this in ~/.local/bin, we intercept those calls.
  BIN_DIR="$HOME/.local/bin"
  mkdir -p "$BIN_DIR"
  if ! printf "%s" "$PATH" | tr ':' '\n' | grep -qx "$BIN_DIR"; then
    echo "Warning: $BIN_DIR is not in PATH for this session. GUI apps may still use /usr/bin/xterm."
  fi

  cat <<EOF >"$BIN_DIR/xterm"
#!/usr/bin/env bash
# ==================================================
#  KoolDots (2026)
#  Project URL: https://github.com/LinuxBeginnings
#  License: GNU GPLv3
#  SPDX-License-Identifier: GPL-3.0-or-later
# ==================================================
#
# Shim to redirect xterm calls to kitty 
# Resolves Open with (vim/neovim/etc) opening in xterm 
args=()
pass_through=()
while [ \$# -gt 0 ]; do
  case "\$1" in
    -e)
      shift
      if [ \$# -gt 0 ]; then
        pass_through+=("\$@")
      fi
      break
      ;;
    -T|-title|-geometry|-bg|-fg|-fs|-fa|-fn)
      # Skip common xterm-only flags and their values
      shift
      [ \$# -gt 0 ] && shift
      ;;
    -class|-name)
      shift
      [ \$# -gt 0 ] && shift
      ;;
    -hold|-ls|-sb|-sk|-sr|-s)
      # Ignore boolean flags that kitty doesn't understand
      shift
      ;;
    *)
      args+=("\$1")
      shift
      ;;
  esac
done

if [ \${#pass_through[@]} -gt 0 ]; then
  exec kitty "\${args[@]}" -- "\${pass_through[@]}"
else
  exec kitty "\${args[@]}"
fi
EOF
  chmod +x "$BIN_DIR/xterm"

  # 3. Update GLib/GIO Default Terminal (for GNOME-based backends)
  # Some distros use gsettings to define the terminal schema.
  if command -v gsettings >/dev/null 2>&1; then
    gsettings set org.gnome.desktop.default-applications.terminal exec 'kitty' 2>/dev/null || true
  fi

  # 4. Refresh Mime Database
  # Ensures Thunar sees the changes to terminal handling immediately.
  if command -v update-desktop-database >/dev/null 2>&1; then
    update-desktop-database ~/.local/share/applications 2>/dev/null || true
  fi

  # 5. Hide Kitty URL Handler from "Open With"
  # Prevents Kitty URL handler from showing up for text files.
  USER_APP_DIR="$HOME/.local/share/applications"
  mkdir -p "$USER_APP_DIR"
  KITTY_URL_HANDLER=""
  for dir in $XDG_DATA_DIRS /usr/local/share /usr/share; do
    [ -z "$dir" ] && continue
    if [ -f "$dir/applications/kitty-url-handler.desktop" ]; then
      KITTY_URL_HANDLER="$dir/applications/kitty-url-handler.desktop"
      break
    fi
  done

  if [ -n "$KITTY_URL_HANDLER" ]; then
    cp "$KITTY_URL_HANDLER" "$USER_APP_DIR/kitty-url-handler.desktop"
    if grep -q '^NoDisplay=' "$USER_APP_DIR/kitty-url-handler.desktop"; then
      sed -i 's|^NoDisplay=.*|NoDisplay=true|' "$USER_APP_DIR/kitty-url-handler.desktop"
    else
      printf "\nNoDisplay=true\n" >>"$USER_APP_DIR/kitty-url-handler.desktop"
    fi
    if grep -q '^Hidden=' "$USER_APP_DIR/kitty-url-handler.desktop"; then
      sed -i 's|^Hidden=.*|Hidden=true|' "$USER_APP_DIR/kitty-url-handler.desktop"
    else
      printf "Hidden=true\n" >>"$USER_APP_DIR/kitty-url-handler.desktop"
    fi
  fi

  echo "Default terminal set to kitty successfully."
}

setup_default_terminal
