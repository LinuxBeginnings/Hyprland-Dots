-- ==================================================
--  KoolDots (2026)
--  Project URL: https://github.com/LinuxBeginnings
--  License: GNU GPLv3
--  SPDX-License-Identifier: GPL-3.0-or-later
-- ==================================================

-- Loads split system/user-editable Lua override files.
-- System files are loaded from ~/.config/hypr/configs (with UserConfigs fallback for legacy setups).
local configHome = os.getenv("XDG_CONFIG_HOME") or ((os.getenv("HOME") or "") .. "/.config")
local hyprDir = configHome .. "/hypr"
local systemDir = hyprDir .. "/configs"
local userDir = configHome .. "/hypr/UserConfigs"
local function qml_module_exists(subpath)
  local candidate_roots = {
    "/usr/lib/qt6/qml",
    "/usr/lib64/qt6/qml",
    "/usr/lib/x86_64-linux-gnu/qt6/qml",
    "/usr/lib/aarch64-linux-gnu/qt6/qml",
    "/usr/lib/qt5/qml",
    "/usr/lib64/qt5/qml",
    "/usr/lib/x86_64-linux-gnu/qt5/qml",
    "/usr/lib/aarch64-linux-gnu/qt5/qml",
    "/usr/lib/qt/qml",
    "/usr/lib64/qt/qml",
    "/usr/share/qt6/qml",
    "/usr/share/qt5/qml",
    "/usr/share/qml",
  }
  for _, root in ipairs(candidate_roots) do
    local f = io.open(root .. "/" .. subpath, "r")
    if f then
      f:close()
      return true
    end
  end
  return false
end

local function has_kvantum_qml_module()
  return qml_module_exists("kvantum") or qml_module_exists("org/kde/kvantum")
end

local function has_hyprland_qml_style_module()
  return qml_module_exists("org/hyprland/style")
end

local function apply_qt_style_fallbacks()
  if not hl or not hl.env then
    return
  end

  if not has_kvantum_qml_module() then
    local style_override = (os.getenv("QT_STYLE_OVERRIDE") or ""):lower()
    if style_override == "kvantum" or style_override == "kvantum-dark" then
      hl.env("QT_STYLE_OVERRIDE", "Fusion")
    end
  end
  if not has_hyprland_qml_style_module() then
    local quick_controls = (os.getenv("QT_QUICK_CONTROLS_STYLE") or ""):lower()
    if quick_controls == "" or quick_controls == "org.hyprland.style" then
      hl.env("QT_QUICK_CONTROLS_STYLE", "Basic")
    end
  end
end

local function load_optional(path)
  local ok, err = pcall(dofile, path)
  if ok then
    return true
  end
  if err and tostring(err):find("No such file or directory", 1, true) == nil then
    print("[WARN] Unable to load user override file " .. path .. ": " .. tostring(err))
  end
  return false
end

local loaded_user_split = false

local system_files = {
  "system_env.lua",
  "system_startup.lua",
  "system_window_rules.lua",
  "system_layer_rules.lua",
  "system_keybinds.lua",
  "system_settings.lua",
  "system_laptops.lua",
}
for _, file in ipairs(system_files) do
  local primary = systemDir .. "/" .. file
  local legacy = userDir .. "/" .. file
  if not load_optional(primary) then
    load_optional(legacy)
  end
end

local user_files = {
  "user_env.lua",
  "user_startup.lua",
  "user_window_rules.lua",
  "user_layer_rules.lua",
  "user_keybinds.lua",
  "user_settings.lua",
  "user_decorations.lua",
  "user_animations.lua",
  "user_laptops.lua",
}
for _, file in ipairs(user_files) do
  local path = userDir .. "/" .. file
  if load_optional(path) then
    loaded_user_split = true
  end
end
if not loaded_user_split then
  load_optional(userDir .. "/user_overrides.lua") -- legacy single-file support
end
apply_qt_style_fallbacks()
