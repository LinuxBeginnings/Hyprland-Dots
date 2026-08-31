#!/usr/bin/env bash
# ==================================================
#  KoolDots (2026)
#  Project URL: https://github.com/LinuxBeginnings
#  License: GNU GPLv3
#  SPDX-License-Identifier: GPL-3.0-or-later
# ==================================================
# Regenerate ${XDG_CONFIG_HOME:-$HOME/.config}/hypr/configs/system_settings.lua from SystemSettings.conf.

set -euo pipefail

CONFIG_HOME="${XDG_CONFIG_HOME:-${XDG_CONFIG_HOME:-$HOME/.config}}"
HYPR_DIR="${CONFIG_HOME}/hypr"
CONFIGS_DIR="${HYPR_DIR}/configs"
LEGACY_DIR="${CONFIGS_DIR}/LegacyConfigs"
SYSTEM_SETTINGS_CONF="${CONFIGS_DIR}/SystemSettings.conf"
SYSTEM_SETTINGS_LUA="${CONFIGS_DIR}/system_settings.lua"

cat > "${SYSTEM_SETTINGS_LUA}" <<'LUA'
-- ==================================================
--  KoolDots (2026)
--  Project URL: https://github.com/LinuxBeginnings
--  License: GNU GPLv3
--  SPDX-License-Identifier: GPL-3.0-or-later
-- ==================================================
-- System settings for the Lua workflow.
-- Loaded by user_overrides.lua on every Hyprland session start.
-- Delegates to lua/settings.lua which contains the canonical settings.

local configHome = os.getenv("XDG_CONFIG_HOME") or ((os.getenv("HOME") or "") .. "/.config")
local hyprDir = configHome .. "/hypr"
local settings_path = hyprDir .. "/lua/settings.lua"
local ok, err = pcall(dofile, settings_path)
if not ok then
  print("[ERROR] system_settings: failed to load lua/settings.lua: " .. tostring(err))
end
LUA
echo "[OK] Updated ${SYSTEM_SETTINGS_LUA}"
