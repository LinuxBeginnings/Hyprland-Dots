// Quickshell Weather Applet Root
//
// Start:   quickshell -p ~/.config/quickshell/weather
// Toggle:  ~/.config/hypr/scripts/QsWeather.sh toggle
//
// IPC:
//   quickshell ipc -p ~/.config/quickshell/weather \
//       call weather toggle|open|close|isOpen|ready|refresh

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

    // Watch Wallust CSS and QML JSON palette
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
        target: "weather"

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

        function ready(): string {
            return "1";
        }

        function refresh(): void {
            backend.refresh();
        }
    }
}
