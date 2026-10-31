pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io

// The keybind list, straight from the compositor.
//
// Nothing here parses config files. `hypr/lua/keybind_index.lua` hooks hl.bind
// inside Hyprland's Lua VM and writes every registered chord and its description
// to $XDG_RUNTIME_DIR/kooldots-keybinds.txt - the same file `KeyBinds.sh` hands
// to rofi. That covers the chords the keybind helpers derive, the lid-switch
// binds written with a bare hl.bind, and anything another module registers,
// which a text parser cannot see.
//
// This file replaces an earlier version of the same service that ran
// `quickshell/scripts/hyprland/get_keybinds.py` over `hypr/hyprland/keybinds.conf`
// and `hypr/custom/keybinds.conf`. None of those paths exist in this repo: the
// config is Lua, and the parser was never shipped. It read nothing and reported
// an empty list, silently. It also used SplitParser, which hands over one line
// at a time, so the JSON it expected could never have parsed.
//
// Two ways in, the same order `KeyBinds.sh` uses:
//   1. ask the live VM to rewrite the cache, then read it. Rewriting first
//      matters: a bind added with `hyprctl eval` after the last reload is in the
//      VM's registry but not yet in the file.
//   2. fall back to `hyprctl -j binds`, so a config whose hyprland.lua predates
//      keybind_index.lua still lists the binds the compositor actually has.
Singleton {
    id: root

    // Every registered chord, in registration order, as
    // { chord, description, keys: [...] }. `keys` is the chord split into caps.
    property var keybinds: []
    property bool loaded: false
    // Shown in the panel footer when there is nothing to show.
    property string note: ""

    readonly property string runtimeDir: {
        var dir = Quickshell.env("XDG_RUNTIME_DIR");
        return dir ? dir : "/tmp";
    }

    readonly property string cachePath: root.runtimeDir + "/kooldots-keybinds.txt"

    // The separator keybind_index.lua writes between chord and description: an
    // em dash with a space either side.
    readonly property string separator: " — "

    function refresh() {
        root.note = "";
        rewrite.running = true;
    }

    function entry(chord, description) {
        return {
            chord: chord,
            description: description,
            keys: chord.split("+")
        };
    }

    // One line per bind: "SUPER+SHIFT+K — search keybinds". A bind with no
    // description is the bare chord.
    function parseCache(text) {
        var entries = [];
        if (!text) return entries;

        var lines = text.split("\n");
        for (var index = 0; index < lines.length; index++) {
            var line = lines[index].trim();
            if (line === "") continue;

            var cut = line.indexOf(root.separator);
            if (cut < 0) {
                entries.push(root.entry(line, ""));
                continue;
            }
            entries.push(root.entry(line.slice(0, cut),
                line.slice(cut + root.separator.length).trim()));
        }
        return entries;
    }

    // Mask bits: SHIFT 1, CTRL 4, ALT 8, SUPER 64.
    function modsFromMask(mask) {
        var mods = [];
        if (Math.floor(mask / 64) % 2 === 1) mods.push("SUPER");
        if (Math.floor(mask / 4) % 2 === 1) mods.push("CTRL");
        if (Math.floor(mask / 8) % 2 === 1) mods.push("ALT");
        if (mask % 2 === 1) mods.push("SHIFT");
        return mods;
    }

    function parseBinds(text) {
        var raw = [];
        try {
            raw = JSON.parse(text);
        } catch (error) {
            return [];
        }
        if (!Array.isArray(raw)) return [];

        var entries = [];
        for (var index = 0; index < raw.length; index++) {
            var bind = raw[index];
            if (!bind || typeof bind.key !== "string" || bind.key === "") continue;
            var chord = root.modsFromMask(bind.modmask || 0).concat([bind.key]).join("+");
            entries.push(root.entry(chord, bind.description || ""));
        }
        return entries;
    }

    // True when the list was replaced.
    function apply(entries) {
        if (entries.length === 0) return false;
        root.keybinds = entries;
        root.loaded = true;
        return true;
    }

    Process {
        id: rewrite
        command: ["hyprctl", "eval", "KOOLDOTS_KEYBIND_INDEX:write_cache()"]

        stdout: StdioCollector {
            onStreamFinished: {
                // Only the exact reply 'ok' counts as a successful write:
                // hyprctl can exit 0 while answering something else. Either way
                // the next step decides - an unchanged cache is read as it is,
                // and an absent one falls through to the bind table.
                if (text.trim() !== "ok") root.note = "";
                readCache.running = true;
            }
        }
    }

    Process {
        id: readCache
        command: ["cat", root.cachePath]

        stdout: StdioCollector {
            onStreamFinished: {
                if (!root.apply(root.parseCache(text))) readBinds.running = true;
            }
        }
    }

    Process {
        id: readBinds
        command: ["hyprctl", "-j", "binds"]

        stdout: StdioCollector {
            onStreamFinished: {
                if (root.apply(root.parseBinds(text))) return;
                root.loaded = true;
                root.note = "No keybinds found - run: hyprctl reload";
            }
        }
    }

    // The list is wanted as soon as the shell starts, so the panel has something
    // to show the first time it opens.
    Component.onCompleted: root.refresh()
}
