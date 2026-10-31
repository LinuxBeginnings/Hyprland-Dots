//@ pragma Env QT_LOGGING_RULES=qt.qpa.wayland.textinput=false
import QtQuick
import Quickshell
import "./modules"
import "./common"
import "./services"

ShellRoot {
    id: root

    readonly property var m3: Appearance.m3colors

    Hyprview {
        liveCapture: true
        moveCursorToActiveWindow: false
    }

    Component.onCompleted: MaterialThemeLoader.reapplyTheme()
}
