// KoolDots Control Center - Main Quickshell Entrypoint

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

    HelpService {
        id: helpService
    }

    // Dynamic Wallust palette watcher
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
        title: "KoolDots Control Center"
        visible: true
        color: "transparent"

        implicitWidth: 1120
        implicitHeight: 740

        MainView {
            anchors.fill: parent
            theme: theme
            backend: backend
            helpService: helpService
        }
    }
}
