// Centralized Help Service for KoolDots Control Center
// Provides page-level overviews, section details, syntax guides, and examples.

import QtQuick

Item {
    id: helpService

    property string activeTopic: "home"
    property string activeSubtopic: "overview"

    readonly property var topics: ({
        "home": {
            "title": "KoolDots Control Center",
            "file": "Control Center Dashboard",
            "summary": "Unified graphical management suite for your KoolDots Hyprland configuration.",
            "description": "Welcome to KoolDots Control Center! This application manages all your personal customizations in ~/.config/hypr/UserConfigs/ and provides quick access to system toggles and display profiles. All modifications are validated before saving, with automated backups and instant revert options."
        },
        "keybinds": {
            "title": "Keybindings Manager",
            "file": "~/.config/hypr/UserConfigs/user_keybinds.lua",
            "summary": "Inspect, remap, customize, and clone keyboard shortcuts.",
            "description": "KoolDots separates keyboard shortcuts into System binds (~/.config/hypr/configs/system_keybinds.lua) and User Defined binds (~/.config/hypr/UserConfigs/user_keybinds.lua).\n\n• Rebinding rule: To replace an existing shortcut, unbind() it first, then bind() the replacement.\n• Pre-flight validation: Every edit is verified for correct Lua syntax and chord collision (duplicate bindings) before applying.\n• In-process closures: Compositor actions (killactive, togglefloating) run inside Hyprland's Lua VM for maximum performance."
        },
        "window_rules": {
            "title": "Window & Layer Rules",
            "file": "~/.config/hypr/UserConfigs/user_window_rules.lua",
            "summary": "Configure window floating, dimensions, opacity, positioning, and tags.",
            "description": "Window rules let you control how applications behave when launched. Rules match windows using regex on class, title, or tags.\n\n• Common actions: float = true, center = true, size = '800 600', opacity = 0.95.\n• Class discovery: Run 'hyprctl activewindow' in a terminal to inspect the class and title of any running window.\n• Validation: Syntax and regex validity are tested before applying to prevent compositor startup hangs."
        },
        "startup": {
            "title": "Startup Applications",
            "file": "~/.config/hypr/UserConfigs/user_startup.lua",
            "summary": "Manage background applets, daemons, and autostart scripts.",
            "description": "Commands defined here run once when starting your Hyprland session via the exec_once() helper.\n\n• Session locks: Uses marker files in /tmp so reloading Hyprland configuration does not spawn duplicate app instances.\n• Diagnostics: Logs for each startup process are saved to /tmp/hypr-lua-user-startup-<cmd>.log."
        },
        "settings": {
            "title": "Settings & Appearance",
            "file": "~/.config/hypr/UserConfigs/ (user_settings, user_decorations, user_animations)",
            "summary": "Tune input devices, touchpad gestures, blur variants, animations, and defaults.",
            "description": "Covers all modular settings in UserConfigs/:\n\n• Input & Keyboard: Configure layout (e.g. us, es, fr), toggle chords (grp:alt_shift_toggle), repeat delay, sensitivity.\n• Touchpad & Mouse: Natural scrolling, tap-to-click, middle button emulation.\n• Decorations: Active and inactive opacity, borders, gaps, blur passes, and Hyprland 0.57 blur variants (kawase, frost, ripple, etc.).\n• Wobble Physics: Real-time physics parameters for window movement elasticity.\n• Defaults: Default terminal ($term), editor ($edit), and file manager ($files)."
        },
        "toggles": {
            "title": "Quick Toggles Switchboard",
            "file": "Kool Quick Settings & Environmental Toggles",
            "summary": "Fast toggles for desktop utilities and visual modes.",
            "description": "Switch between configuration presets without opening text files:\n\n• Waybar Weather Units: Toggle Celsius (°C) and Fahrenheit (°F).\n• Waybar Clock: Switch between 12-hour and 24-hour time.\n• Game Mode: Instantly disable blur, rounding, and animations to maximize FPS.\n• Window Wobble: Toggle live window transformation physics.\n• Rainbow Borders: Cycle border styles (Off, Original, Wallust, Gradient Flow)."
        },
        "monitors": {
            "title": "Monitors & Display Profiles",
            "file": "~/.config/hypr/UserConfigs/monitors.lua",
            "summary": "Manage multi-monitor arrangements, resolutions, refresh rates, and profiles.",
            "description": "KoolDots identifies monitors by hardware device and vendor rather than port order, ensuring layouts survive reboots and docking stations.\n\n• DisplayProfile: Save current screen arrangement into named profiles (e.g. Work, Mobile, Home).\n• Clamshell mode: Automatically switches off internal laptop screen when external displays are active."
        },
        "waybar": {
            "title": "Waybar Editor",
            "file": "~/.config/hypr/waybar/",
            "summary": "Visual bar layout and theme editor (Phase 2).",
            "description": "The Waybar Visual Editor is scheduled for Phase 2.\n\nIn the meantime, you can customize your Waybar typography and scaling using the newly added Waybar Font & Size Settings applet, or choose themes via WaybarStyles.sh."
        }
    })

    function getHelp(topicKey, subtopicKey) {
        if (topicKey === "settings" && subtopicKey) {
            var sHelp = Object.assign({}, helpService.topics["settings"]);
            if (subtopicKey === "decorations" || subtopicKey === "wobble") {
                sHelp.file = "~/.config/hypr/UserConfigs/user_decorations.lua";
                sHelp.title = (subtopicKey === "wobble") ? "Window Wobble Physics" : "Appearance & Blur Engine";
            } else if (subtopicKey === "defaults") {
                sHelp.file = "~/.config/hypr/UserConfigs/user_defaults.lua";
                sHelp.title = "Default Applications";
            } else {
                sHelp.file = "~/.config/hypr/UserConfigs/user_settings.lua";
                sHelp.title = (subtopicKey === "touchpad") ? "Touchpad & Mouse Behavior" : "Keyboard Layouts & Input";
            }
            return sHelp;
        }
        if (helpService.topics.hasOwnProperty(topicKey)) {
            return helpService.topics[topicKey];
        }
        return helpService.topics["home"];
    }
}
