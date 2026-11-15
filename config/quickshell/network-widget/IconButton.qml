// Compact glyph button (refresh, scan, close, confirm).

import QtQuick

Rectangle {
    id: button

    property Theme theme: Theme {}
    property string glyph: ""
    property color glyphColor: theme ? theme.muted : "transparent"

    // Carries the click's modifiers, so a caller can give shift-click its own
    // meaning. Handlers that ignore the argument are unchanged.
    signal clicked(var mouse)

    implicitWidth: 24
    implicitHeight: 24
    radius: 6
    color: hover.hovered && button.enabled ? theme.surfaceAlt : "transparent"
    opacity: button.enabled ? 1.0 : 0.35

    Text {
        anchors.centerIn: parent
        text: button.glyph
        color: button.glyphColor
        font.family: button.theme.iconFont
        font.pixelSize: 14
    }

    HoverHandler {
        id: hover
    }

    MouseArea {
        anchors.fill: parent
        enabled: button.enabled
        cursorShape: button.enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
        onClicked: button.clicked(mouse)
    }
}
