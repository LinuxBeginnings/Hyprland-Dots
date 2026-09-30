local uv = require("luv")

-- Fallback check if environment variables are nil in background subshells
local instance_sig = os.getenv("HYPRLAND_INSTANCE_SIGNATURE")
local runtime_dir = os.getenv("XDG_RUNTIME_DIR") or ("/run/user/" .. (os.getenv("UID") or "1000"))

if not instance_sig then
    -- Grab active Hyprland instance signature directly if env var is missing
  local handle = io.popen("ls -td /run/user/$(id -u)/hypr/* 2>/dev/null | head -n 1")
  if handle then
    local result = handle:read("*a")
    handle:close()
    instance_sig = result:match("hypr/(%a%d+_%d+)") or result:match("hypr/([%w_]+)")
  end
end

if not instance_sig or not runtime_dir then return end

local socket_path = string.format("%s/hypr/%s/.socket2.sock", runtime_dir, instance_sig)
local client = uv.new_pipe(false)
client:connect(socket_path, function(err)
  if err then return end
  client:read_start(function(read_err, chunk)
  if read_err or not chunk then return end
    for line in chunk:gmatch("[^\r\n]+") do
      if line:find("^fullscreen") then
        local state = line:match("=(%d+)") or line:match("%->(%d+)")
        if state == "1" or state == "2" then
          os.execute("pkill -STOP -f linux-wallpaperengine 2>/dev/null")
        else
          os.execute("pkill -CONT -f linux-wallpaperengine 2>/dev/null")
        end
      elseif line:find("^closewindow") or line:find("^destroywindow") then
        os.execute("pkill -CONT -f linux-wallpaperengine 2>/dev/null")
      end
    end
  end)
end)

uv.run()
