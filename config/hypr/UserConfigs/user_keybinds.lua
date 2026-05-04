local keybind_helpers = nil
do
  local source = (debug.getinfo(1, "S") or {}).source or ""
  local source_path = source:match("^@(.+)$")
  local source_dir = source_path and source_path:match("^(.*)/[^/]+$") or nil
  local home = os.getenv("HOME") or ""
  local candidate_paths = {
    source_dir and (source_dir .. "/keybind_helpers.lua") or nil,
    home ~= "" and (home .. "/.config/hypr/lua/keybind_helpers.lua") or nil,
    home ~= "" and (home .. "/.config/hypr/keybind_helpers.lua") or nil,
  }

  local tried_paths = {}
  for _, helper_path in ipairs(candidate_paths) do
    if helper_path then
      table.insert(tried_paths, helper_path)
      local f = io.open(helper_path, "r")
      if f then
        f:close()
        local loaded_ok, loaded_helpers = pcall(dofile, helper_path)
        if loaded_ok and type(loaded_helpers) == "table" and loaded_helpers.unbind_default_keys then
          keybind_helpers = loaded_helpers
          break
        end
      end
    end
  end

  if not keybind_helpers then
    error("Failed to load keybind_helpers.lua from: " .. table.concat(tried_paths, ", "))
  end
end
local exec_cmd = keybind_helpers.exec_cmd
local bind = keybind_helpers.bind

bind("SUPER SHIFT", "T", exec_cmd("$HOME/.config/hypr/scripts/Dropterminal.sh kitty"), {
  description = "DropDown terminal",
})
