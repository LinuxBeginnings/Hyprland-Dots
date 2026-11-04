// Which function a keybind belongs to, so the panel can group and sort by it.
//
// The bind list carries no category of its own. `keybind_index.lua` records the
// chord and the description that `hl.bind` was given, and nothing else, so the
// grouping is derived here from the description. That keeps the taxonomy out of
// the config files: adding a bind needs no category marker, and a description
// that fits an existing rule is filed without touching this file.
//
// The rules are ordered, and the first one that matches wins. Specific patterns
// therefore have to come before general ones - "waybar layout menu" is Theming,
// not Layouts, and "switch keyboard layout" is System, not Layouts, because
// those rules sit above Layouts.
//
// Matching is on the description alone, lowercased. The chord is deliberately
// not searched: every chord contains SUPER or CTRL, which would match nothing
// useful. A bind with no description, or one no rule claims, lands in "Other".

import QtQuick

Item {
    id: categories

    // Display order. A category with no matches is dropped by the panel, so this
    // is the reading order of the groups, not a promise that all of them appear.
    readonly property var order: [
        "Launchers",
        "Windows",
        "Workspaces",
        "Layouts",
        "Displays",
        "Media",
        "Brightness",
        "Screenshots",
        "Theming",
        "System",
        "Help",
        "Other"
    ]

    readonly property var rules: [
        ["Launchers", [
            "app launcher", "browser", "terminal", "file manager", "ssh",
            "calculator", "emoji menu", "web search", "online music", "warp"
        ]],
        ["Screenshots", [
            "screenshot", "screen capture", "swappy", "hyprshot"
        ]],
        ["Brightness", [
            "brightness"
        ]],
        // Before Theming: "Display wallpapers" is a display bind, and before
        // Layouts: "Display layouts" names a layout store, not a tiling layout.
        ["Displays", [
            "display layouts", "display wallpapers", "zoom"
        ]],
        // Before Layouts for "waybar layout menu", before Windows for the window
        // opacity and wobble toggles.
        ["Theming", [
            "theme", "wallpaper", "waybar", "animations", "blur", "wobble",
            "opacity", "hyprsunset", "night light", "rainbow"
        ]],
        // Before Windows: "Toggle Mute/Unmute for Active-Window" is a media bind.
        ["Media", [
            "volume", "mute", "mic", "play", "pause", "track", "stop"
        ]],
        ["Windows", [
            "close active window", "terminate active process", "window switcher",
            "overview", "fullscreen", "maximize", "float", "focus ", "resize ",
            "swap window", "move window", "cycle next", "cycle previous",
            "toggle split", "toggle pseudo", "group", "bring active"
        ]],
        // Before Layouts, so "move workspace to left monitor" is a workspace bind
        // and not a monitor one.
        ["Workspaces", [
            "workspace"
        ]],
        // Before Layouts for "switch keyboard layout" and the keyboard RGB binds.
        ["System", [
            "exit", "lock screen", "powermenu", "dock", "notification",
            "quick settings", "game mode", "clipboard", "airplane", "sleep",
            "touchpad", "asus", "armory", "fn+f", "keyboard rgb", "fan profile",
            "keyboard layout", "passthrough", "refresh"
        ]],
        ["Layouts", [
            "layout", "column", "scroll", "split ratio", "master"
        ]],
        ["Help", [
            "keybind", "cheat sheet"
        ]]
    ]

    function of(entry) {
        var description = (entry && entry.description ? entry.description : "").toLowerCase();
        if (description === "") return "Other";

        for (var rule = 0; rule < categories.rules.length; rule++) {
            var patterns = categories.rules[rule][1];
            for (var pattern = 0; pattern < patterns.length; pattern++) {
                if (description.indexOf(patterns[pattern]) !== -1) {
                    return categories.rules[rule][0];
                }
            }
        }
        return "Other";
    }
}
