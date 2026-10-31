// Keybind reference panel: every chord the compositor has registered, as a
// searchable, centred frame of key caps.
//
// Start:   quickshell -p ~/.config/quickshell/keybinds
// Toggle:  ~/.config/hypr/scripts/QsKeybinds.sh toggle      (SUPER ALT K)
//
// IPC (used by the toggle script, and available to anything else):
//   quickshell ipc -p ~/.config/quickshell/keybinds \
//       call keybinds toggle|open|close|isOpen|refresh
//
// The list is the live bind registry, not a parse of the config files: see
// services/HyprlandKeybinds.qml and hypr/lua/keybind_index.lua.
//
// The panel starts hidden and collapses to a single pixel, so the shell stays
// resident between toggles and opening it costs nothing. QsKeybinds.sh starts
// the shell on the first toggle and opens the panel.

import QtQuick
import Quickshell
import Quickshell.Io
import "root:/modules"
import "root:/services"

ShellRoot {
    id: shell

    Theme {
        id: theme
    }

    // Wallust output: the Waybar palette has the full theme, the quickshell
    // roles file is the fallback. Both are watched so a theme change repaints
    // the panel in place.
    // FileView exposes the contents through text(), not a text property.
    FileView {
        id: paletteColors

        path: theme.paletteFile
        watchChanges: true
        onTextChanged: theme.applyPaletteCss(paletteColors.text())
    }

    FileView {
        id: roleColors

        path: theme.jsonFile
        watchChanges: true
        onTextChanged: theme.applyJson(roleColors.text())
    }

    Panel {
        id: panel

        theme: theme
    }

    IpcHandler {
        target: "keybinds"

        function toggle(): void {
            panel.shown = !panel.shown;
        }

        function open(): void {
            panel.shown = true;
        }

        function close(): void {
            panel.shown = false;
        }

        function isOpen(): string {
            return panel.shown ? "1" : "0";
        }

        function refresh(): void {
            HyprlandKeybinds.refresh();
        }
    }
}
