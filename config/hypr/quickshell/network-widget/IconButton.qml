// Compact glyph button (refresh, scan, close, confirm).

import QtQuick

Rectangle {
    id: button

    property Theme theme: Theme {}
    property string glyph: ""
    property color glyphColor: theme ? theme.muted : "transparent"

    signal clicked()

    implicitWidth: 24
    implicitHeight: 24
    radius: 6
    color: hover.hovered ? theme.surfaceAlt : "transparent"

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
        cursorShape: Qt.PointingHandCursor
        onClicked: button.clicked()
    }
}
