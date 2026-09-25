-- User keybind overrides.
-- Add, override, or rebind keybinds here.
--
-- =============================================================================
-- KEYBIND RULES & SYNTAX
-- =============================================================================
-- • bind("MODS", "KEY", action, [options])
-- • unbind("MODS", "KEY")
--
-- Supported modifiers:
--   "SUPER", "SHIFT", "CTRL", "ALT", or combinations like "SUPER SHIFT", "SUPER ALT"
--
-- Actions:
--   • exec_cmd("command")       -> launches a terminal command or script
--   • dispatch("dispatcher", [arg]) -> triggers a Hyprland dispatcher (e.g. killactive, togglefloating)
--
-- =============================================================================
-- EXAMPLES
-- =============================================================================
--
-- NOTE ON LUA REBINDS:
--   Yes — same rule as Hyprlang applies in practice: if a key combo is already bound,
--   unbind("MODS", "KEY") first, then bind(...) it to the new action.
--   This keeps behavior explicit and avoids duplicate/conflicting binds.
--
-- 1. ADDING A BRAND NEW KEYBIND (combo not used by default):
--    bind("SUPER", "Z", exec_cmd("ghostty"), { description = "Launch Ghostty" })
--    bind("SUPER SHIFT", "V", exec_cmd("pavucontrol"), { description = "Audio Control" })
--    bind("SUPER", "X", dispatch("killactive"), { description = "Close active window" })
--
-- 2. OVERRIDING AN EXISTING COMBO WITH A DIFFERENT APP/COMMAND:
--    -- To replace what SUPER+Return opens (default: kitty):
--    unbind("SUPER", "Return")
--    bind("SUPER", "Return", exec_cmd("ghostty"), { description = "Launch Ghostty" })
--
-- 3. REBINDING / MOVING AN ACTION TO A NEW KEY COMBINATION:
--    -- Example: Move File Manager from SUPER+E to SUPER+F, and use SUPER+E for Emacs:
--    unbind("SUPER", "E")       -- unbind default file manager from SUPER+E
--    unbind("SUPER", "F")       -- unbind whatever SUPER+F was doing (default: fake fullscreen)
--    bind("SUPER", "F", exec_cmd("$HOME/.config/hypr/scripts/LaunchFileManager.sh '$files' '$term'"), { description = "File manager" })
--    bind("SUPER", "E", exec_cmd("emacsclient -c -a 'emacs'"), { description = "Launch Emacs" })
--
-- 4. REBINDING COMPOSITOR DISPATCHERS (e.g. workspace, fullscreen, floating):
--    unbind("SUPER", "Q")
--    bind("SUPER", "Q", dispatch("killactive"), { description = "Close active window" })
--    unbind("SUPER", "F") -- default fakefullscreen
--    bind("SUPER SHIFT", "F", dispatch("fullscreen", "0"), { description = "Toggle fullscreen" })
--    bind("SUPER ALT", "W", dispatch("workspace", "special:scratchpad"), { description = "Toggle scratchpad" })
--
-- 5. BIND OPTIONS (locked, repeating):
--    -- locked = true     -> runs even when lockscreen is active (e.g. media keys)
--    -- repeating = true  -> repeats when key is held down (e.g. volume / brightness)
--    bind("CTRL ALT", "bracketright", exec_cmd("$HOME/.config/hypr/scripts/Brightness.sh --inc"), { description = "Brightness up", repeating = true })
--    bind("", "XF86AudioMute", exec_cmd("$HOME/.config/hypr/scripts/Volume.sh --toggle"), { description = "Mute audio", locked = true })
--
-- =============================================================================
local user_keybinds_helper = nil
local submap_helper = nil
do
  local source = (debug.getinfo(1, "S") or {}).source or ""
  local source_path = source:match("^@(.+)$")
  local source_dir = source_path and source_path:match("^(.*)/[^/]+$") or nil
  local home = os.getenv("HOME") or ""

  -- Load a helper module from the first candidate path that defines what we
  -- expect. Each helper is loaded exactly once, so a local copy always wins
  -- over the shipped template and no module is executed twice.
  local function load_helper(file_name, validate)
    local candidate_paths = {
      source_dir and (source_dir .. "/../lua/" .. file_name) or nil,
      home ~= "" and (home .. "/.config/hypr/lua/" .. file_name) or nil,
      home ~= "" and (home .. "/.config/hypr/" .. file_name) or nil,
    }

    local tried_paths = {}
    for _, helper_path in ipairs(candidate_paths) do
      if helper_path then
        table.insert(tried_paths, helper_path)
        local f = io.open(helper_path, "r")
        if f then
          f:close()
          local loaded_ok, loaded_helpers = pcall(dofile, helper_path)
          if loaded_ok and type(loaded_helpers) == "table" and validate(loaded_helpers) then
            return loaded_helpers
          end
        end
      end
    end

    return nil, tried_paths
  end

  local tried_paths
  user_keybinds_helper, tried_paths = load_helper("user_keybinds_helper.lua", function(helpers)
    return helpers.bind ~= nil
  end)
  if not user_keybinds_helper then
    error("Failed to load user_keybinds_helper.lua from: " .. table.concat(tried_paths or {}, ", "))
  end

  -- submap_helper is optional: a missing or broken file must not take down all
  -- user keybinds, so it degrades to a warning and the keybinds below still load.
  submap_helper = load_helper("submap_helper.lua", function(helpers)
    return helpers.submap ~= nil
  end)
end

local exec_cmd = user_keybinds_helper.exec_cmd
local dispatch = user_keybinds_helper.dispatch
local bind = user_keybinds_helper.bind
local unbind = user_keybinds_helper.unbind
local submap = submap_helper and submap_helper.submap or nil
if not submap then
  print("[WARN] submap_helper.lua was not found; the submap.* helpers are unavailable. "
    .. "Copy config/hypr/lua/submap_helper.lua to ~/.config/hypr/lua/ to enable them.")
end

