// One pill in the panel's horizontal tab bar.

import QtQuick
import QtQuick.Layouts

Rectangle {
    id: tab

    property Theme theme: Theme {}
    property string icon: ""
    property string label: ""
    property bool active: false

    signal clicked()

    implicitHeight: 30
    radius: 8
    color: active
        ? Qt.rgba(theme.accent.r, theme.accent.g, theme.accent.b, 0.20)
        : (hover.hovered ? theme.hover : "transparent")
    border.width: active ? 1 : 0
    border.color: Qt.rgba(theme.accent.r, theme.accent.g, theme.accent.b, 0.45)

    RowLayout {
        anchors.centerIn: parent
        spacing: 5

        Text {
            text: tab.icon
            font.family: tab.theme.iconFont
            font.pixelSize: 13
            color: tab.active ? tab.theme.accent : tab.theme.muted
        }

        Text {
            text: tab.label
            font.family: tab.theme.fontFamily
            font.pixelSize: 11
            font.bold: tab.active
            color: tab.active ? tab.theme.text : tab.theme.muted
        }
    }

    HoverHandler {
        id: hover
    }

    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        onClicked: tab.clicked()
    }
}
