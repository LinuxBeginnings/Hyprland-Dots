// One clickable line in the panel: icon, title, optional detail, optional
// trailing text. Used for ethernet devices, Wi-Fi networks and BT devices.

import QtQuick
import QtQuick.Layouts

Rectangle {
    id: row

    property Theme theme: Theme {}
    property string icon: ""
    property string label: ""
    property string detail: ""
    property string trailing: ""
    property bool highlighted: false
    property bool dimmed: false
    property bool interactive: true

    signal activated()

    implicitHeight: detail === "" ? 38 : 46
    radius: 8
    // A tint of the accent stays readable whatever colour wallust picks,
    // unlike a solid selection colour (which can be near white).
    color: highlighted
        ? Qt.rgba(theme.accent.r, theme.accent.g, theme.accent.b, 0.22)
        : (hover.hovered && interactive ? theme.hover : "transparent")

    RowLayout {
        anchors.fill: parent
        anchors.leftMargin: 10
        anchors.rightMargin: 10
        spacing: 10

        Text {
            text: row.icon
            visible: text !== ""
            font.family: row.theme.iconFont
            font.pixelSize: 16
            color: row.dimmed ? row.theme.muted : row.theme.accent
            Layout.alignment: Qt.AlignVCenter
        }

        ColumnLayout {
            Layout.fillWidth: true
            spacing: 0

            Text {
                text: row.label
                color: row.theme.text
                font.family: row.theme.fontFamily
                font.pixelSize: 12
                elide: Text.ElideRight
                Layout.fillWidth: true
            }

            Text {
                text: row.detail
                visible: row.detail !== ""
                color: row.theme.muted
                font.family: row.theme.fontFamily
                font.pixelSize: 10
                elide: Text.ElideRight
                Layout.fillWidth: true
            }
        }

        Text {
            text: row.trailing
            visible: row.trailing !== ""
            color: row.theme.accent
            font.family: row.theme.fontFamily
            font.pixelSize: 11
            Layout.alignment: Qt.AlignVCenter
        }
    }

    HoverHandler {
        id: hover
    }

    MouseArea {
        anchors.fill: parent
        cursorShape: row.interactive ? Qt.PointingHandCursor : Qt.ArrowCursor
        onClicked: {
            if (row.interactive) row.activated();
        }
    }
}
