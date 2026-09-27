#!/usr/bin/env bash
# ==================================================
#  KoolDots (2026)
#  Project URL: https://github.com/LinuxBeginnings
#  License: GNU GPLv3
#  SPDX-License-Identifier: GPL-3.0-or-later
# ==================================================
# Remove stale Thunar & GTK-3 Wallust CSS overrides and template targets.

set -euo pipefail

CONFIG_HOME="${XDG_CONFIG_HOME:-$HOME/.config}"
GTK3_DIR="${CONFIG_HOME}/gtk-3.0"
HYPR_DIR="${CONFIG_HOME}/hypr"
WALLUST_DIR="${HYPR_DIR}/wallust"

echo "=== Cleaning up Thunar & GTK-3 theme overrides ==="

# 1. Remove colors-wallust.css in gtk-3.0 directory
if [ -f "${GTK3_DIR}/colors-wallust.css" ]; then
  rm -f "${GTK3_DIR}/colors-wallust.css"
  echo "[OK] Removed ${GTK3_DIR}/colors-wallust.css"
fi

# 2. Clean up gtk.css in gtk-3.0 directory
if [ -f "${GTK3_DIR}/gtk.css" ]; then
  # If gtk.css only contains comments, whitespace, or colors-wallust import, remove it
  if ! grep -Ev '^[[:space:]]*(/\*.*\*/|@import[[:space:]]+[\x27"]colors-wallust\.css[\x27"];|[[:space:]]*)$' "${GTK3_DIR}/gtk.css" >/dev/null 2>&1; then
    rm -f "${GTK3_DIR}/gtk.css"
    echo "[OK] Removed ${GTK3_DIR}/gtk.css (contained only Wallust overrides)"
  else
    sed -i "/@import[[:space:]]*['\"]colors-wallust\.css['\"];/d" "${GTK3_DIR}/gtk.css" 2>/dev/null || true
    echo "[OK] Removed colors-wallust.css import from ${GTK3_DIR}/gtk.css"
  fi
fi

# 3. Remove colors-gtk.css template from hypr wallust templates
if [ -f "${WALLUST_DIR}/templates/colors-gtk.css" ]; then
  rm -f "${WALLUST_DIR}/templates/colors-gtk.css"
  echo "[OK] Removed ${WALLUST_DIR}/templates/colors-gtk.css"
fi

# 4. Remove gtk3 template entries from wallust.toml and wallust-v4.toml
for wcfg in "${WALLUST_DIR}/wallust.toml" "${WALLUST_DIR}/wallust-v4.toml" "${CONFIG_HOME}/wallust/wallust.toml" "${CONFIG_HOME}/wallust/wallust-v4.toml"; do
  if [ -f "$wcfg" ] && grep -q "colors-gtk\.css" "$wcfg" 2>/dev/null; then
    sed -i '/gtk3\.template[[:space:]]*=[[:space:]]*[\x27"]colors-gtk\.css[\x27"]/d' "$wcfg" 2>/dev/null || true
    sed -i '/gtk3\.target[[:space:]]*=[[:space:]]*[\x27"]~\/\.config\/gtk-3\.0\/colors-wallust\.css[\x27"]/d' "$wcfg" 2>/dev/null || true
    echo "[OK] Removed gtk3 template targets from ${wcfg}"
  fi
done

# 5. Quit running Thunar daemon so GTK picks up the active theme cleanly
if command -v thunar >/dev/null 2>&1; then
  thunar -q 2>/dev/null || pkill -x thunar 2>/dev/null || true
  echo "[OK] Restarted Thunar daemon"
fi

echo "=== Cleanup complete. Thunar will now follow the theme configured in nwg-look ==="
