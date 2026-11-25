// Quickshell Waybar Font & Size Settings Shell

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

    FloatingWindow {
        id: window
        title: "Waybar Font Settings"
        visible: true
        color: "transparent"

        implicitWidth: 680
        implicitHeight: 520

        Main {
            anchors.fill: parent
            theme: theme
            backend: backend
        }
    }
}
