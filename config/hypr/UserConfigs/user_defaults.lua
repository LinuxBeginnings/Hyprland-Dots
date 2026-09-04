-- ==================================================
--  KoolDots (2026)
--  Project URL: https://github.com/LinuxBeginnings
--  License: GNU GPLv3
--  SPDX-License-Identifier: GPL-3.0-or-later
-- ==================================================
-- User defaults overrides template.
-- This file defines user-preferred default applications used across KoolDots scripts and keybinds.
-- Sourced by lua/user_defaults.lua.
--
-- =============================================================================
-- DEFAULT APPLICATION EXAMPLES (KoolDots Lua)
-- =============================================================================

KOOLDOTS_DEFAULTS = KOOLDOTS_DEFAULTS or {}

-- 1. TERMINAL EMULATORS:
-- Options: "kitty", "ghostty", "alacritty", "foot", "wezterm", "gnome-terminal"
KOOLDOTS_DEFAULTS.term = "kitty"

-- 2. TEXT EDITORS:
-- Options: "nvim", "code", "zed", "emacs", "helix", "micro", "nano", "kate"
KOOLDOTS_DEFAULTS.editor = "nvim"

-- 3. VISUAL / GUI EDITORS:
-- Options: "nvim", "code", "zed", "emacsclient -c -a 'emacs'", "vscodium", "subl", "gedit"
KOOLDOTS_DEFAULTS.visual = "nvim"

-- 4. FILE MANAGERS:
-- Options: "thunar", "nautilus", "dolphin", "yazi", "nemo", "pcmanfm-qt", "ranger"
KOOLDOTS_DEFAULTS.files = "thunar"

-- 5. WEB BROWSERS:
-- Options: "zen-browser", "google-chrome-stable", "firefox", "brave", "chromium", "microsoft-edge"
KOOLDOTS_DEFAULTS.browser = "zen-browser"

-- 6. WEB SEARCH ENGINE FOR ROFI / LAUNCHERS:
-- Examples:
--   "https://duckduckgo.com/?q={}"
--   "https://www.google.com/search?q={}"
--   "https://search.brave.com/search?q={}"
--   "https://kagi.com/search?q={}"
--   "https://www.startpage.com/sp/search?query={}"
KOOLDOTS_DEFAULTS.search_engine = "https://duckduckgo.com/?q={}"

-- 7. APPLICATION LAUNCHERS / MENUS:
-- Options: "rofi", "fuzzel", "wofi", "tofi", "anyrun"
-- KOOLDOTS_DEFAULTS.launcher = "rofi"

-- 8. AUDIO MIXER / VOLUME CONTROL:
-- Options: "pavucontrol", "pulsemixer", "wireplumber", "helvum"
-- KOOLDOTS_DEFAULTS.audio_mixer = "pavucontrol"

-- 9. IMAGE VIEWERS:
-- Options: "nomacs", "eog", "loupe", "imv", "swayimg", "feh"
-- KOOLDOTS_DEFAULTS.image_viewer = "nomacs"
