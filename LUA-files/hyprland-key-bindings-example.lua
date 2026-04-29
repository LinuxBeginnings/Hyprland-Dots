local terminal = "uwsm-app -- " .. (os.getenv("TERMINAL") or "")
local browser = "omarchy-launch-browser"

-- Mass Unbind
local keys_to_unbind = {
    "SUPER + V",
    "SUPER + W",
    "SUPER + P",
    "SUPER + N",
    "SUPER + T",
    "SUPER + X",
    "SUPER + CTRL + S",
    "SUPER + G",
    "SUPER + ALT + S",
    "SUPER + F",
    "SUPER + ALT + F",
    "SUPER + CTRL + F",
    "SUPER + CTRL + A",
    "SUPER + CTRL + B",
    "SUPER + CTRL + W",
    "SUPER + CTRL + T",
    "ALT + TAB",
    "SUPER + mouse_down",
    "SUPER + mouse_up",
    "SUPER + SLASH",
    "SUPER + code:61",
    "SUPER + ALT + code:61"
}

for _, key in ipairs(keys_to_unbind) do
    hl.unbind(key)
end

-- TUI Apps Configuration
local tui_apps = {
    {"CTRL + ALT + O", "opencode", "a opencode", "OpenCode"},
    {"CTRL + ALT + SHIFT + A", "cline", "-e cline", "OpenCode"},
    {"CTRL + ALT + B", "btop", "-e btop", "Task Manager"},
    {"CTRL + ALT + SHIFT + B", "bluetui", "-e bluetui", "BlueTUI"},
    {"CTRL + ALT + E", "spf", "-e spf", "SuperFile Manager"},
    {"CTRL + ALT + L", "lazygit", "-e lazygit", "LazyGit"},
    {"CTRL + ALT + N", "nvtop", "-e nvtop", "Nvtop"},
    {"CTRL + ALT + SHIFT + N", "ncdu", "-e ncdu", "Ncdu"},
    {"CTRL + ALT + W", "impala", "-e impala", "Impala Wi-Fi"},
    {"CTRL + ALT + P", "pacseek", "-e pacseek", "PacSeek"},
    {"CTRL + ALT + SHIFT + P", "pacsea", "-e pacsea", "PacSea"},
    {"CTRL + ALT + R", "fzf-uninstall", "-e ~/.config/hypr/fzfpurge", "Fzf Uninstaller"},
    {"CTRL + ALT + V", "wiremix", "-e wiremix", "WireMix Volume"},
    {"CTRL + ALT + SHIFT + H", "htop", "-e htop", "Htop"}
}

for _, app in ipairs(tui_apps) do
    hl.bind(app[1], hl.dsp.exec_cmd(terminal .. " --title=" .. app[2] .. " " .. app[3]), {description = app[4]})
end

-- Web Apps Configuration
local web_apps = {
    {"SUPER + A", "https://gemini.google.com", "Gemini AI"},
    {"SUPER + Y", "https://youtube.com", "YouTube"},
    {"SUPER + T", "https://tiktok.com", "TikTok"},
    {"SUPER + X", "https://x.com", "X.com"},
    {"SUPER + U", "http://10.24.1.1", "Unifi"},
    {"SUPER + I", "https://instagram.com", "Instagram"},
    {"SUPER + P", "https://mail.proton.me", "Proton Mail"}
}

for _, web in ipairs(web_apps) do
    hl.bind(web[1], hl.dsp.exec_cmd([[omarchy-launch-webapp "]] .. web[2] .. [["]]), {description = web[3]})
end

-- Manual Actions (Keep these explicit for clarity)
hl.bind("SUPER + F", hl.dsp.window.fullscreen({mode = 'fullscreen'}), {description = "Fullscreen Window"})
hl.bind("SUPER + CTRL + F", hl.dsp.window.fullscreen({mode = "maximized"}), {description = "Maximize Window"})
hl.bind("SUPER + Q", hl.dsp.window.kill(), {description = "Close active window"})
hl.bind("ALT + SPACE", hl.dsp.window.float({action = "toggle"}), {description = "Toggle floating"})
hl.bind("CTRL + ALT + return", hl.dsp.exec_cmd("uwsm-app -- kitty"), {description = "Kitty terminal"})
hl.bind(
    "CTRL + ALT + SHIFT + return",
    hl.dsp.exec_cmd([[uwsm-app -- xdg-terminal-exec --dir="$(omarchy-cmd-terminal-cwd)" tmux new]]),
    {description = "Tmux"}
)