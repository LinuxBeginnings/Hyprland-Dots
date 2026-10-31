// Network & bluetooth popup for Waybar.
//
// Start:   quickshell -p ~/.config/hypr/quickshell/network-widget
// Toggle:  ~/.config/hypr/scripts/QsNetworkPanel.sh toggle
//
// IPC (used by the Waybar module and available for keybinds):
//   quickshell ipc -p ~/.config/hypr/quickshell/network-widget \
//       call network-widget toggle|open|close|isOpen|refresh
//
// The panel starts hidden; the Waybar module opens it.

import QtQuick
import Quickshell
import Quickshell.Io

ShellRoot {
    id: shell

    Theme {
        id: theme
    }

    Backend {
        id: backend
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
        backend: backend
    }

    IpcHandler {
        target: "network-widget"

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
            backend.refresh();
        }
    }
}
