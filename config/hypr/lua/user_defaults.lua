-- ==================================================
--  KoolDots (2026)
--  Project URL: https://github.com/LinuxBeginnings
--  License: GNU GPLv3
--  SPDX-License-Identifier: GPL-3.0-or-later
-- ==================================================

-- Converted from config/hypr/UserConfigs/01-UserDefaults.conf (active values only).

KOOLDOTS_DEFAULTS = KOOLDOTS_DEFAULTS or {}
local editor = os.getenv("EDITOR")
if editor == nil or editor == "" then
  editor = "nano"
end
local visual = os.getenv("VISUAL")
if visual == nil then
  visual = ""
end
KOOLDOTS_DEFAULTS.edit = editor
KOOLDOTS_DEFAULTS.visual = visual
KOOLDOTS_DEFAULTS.term = "kitty"
KOOLDOTS_DEFAULTS.files = "thunar"
KOOLDOTS_DEFAULTS.search_engine = "https://www.google.com/search?q={}"

-- Optional user overrides live outside the pristine lua/ source tree.
do
  local configHome = os.getenv("XDG_CONFIG_HOME") or ((os.getenv("HOME") or "") .. "/.config")
  local userDefaults = configHome .. "/hypr/UserConfigs/user_defaults.lua"
  local ok, err = pcall(dofile, userDefaults)
  if not ok and err and tostring(err):find("No such file or directory", 1, true) == nil then
    print("[WARN] Unable to load user defaults file " .. userDefaults .. ": " .. tostring(err))
  end
end

-- Make the resolved editor the session default so tools started from a
-- terminal use the same one. VISUAL is pinned to EDITOR as well, because most
-- tools prefer VISUAL and an inherited or stale one would otherwise shadow the
-- editor chosen in Quick Settings.
if hl and hl.env then
  local resolved_edit = KOOLDOTS_DEFAULTS.edit or ""
  if resolved_edit ~= "" then
    hl.env("EDITOR", resolved_edit)
    hl.env("VISUAL", resolved_edit)
  end
end
