-- Converted from config/hypr/UserConfigs/01-UserDefaults.conf (active values only).

KOOLDOTS_DEFAULTS = KOOLDOTS_DEFAULTS or {}
local editor = os.getenv("EDITOR")
if editor == nil or editor == "" then
  editor = "nano"
end
KOOLDOTS_DEFAULTS.edit = editor
KOOLDOTS_DEFAULTS.term = "kitty"
KOOLDOTS_DEFAULTS.files = "thunar"
KOOLDOTS_DEFAULTS.search_engine = "https://www.google.com/search?q={}"
