// Labelled values under a tab: address, gateway, DNS, MAC.

import QtQuick
import QtQuick.Layouts

Rectangle {
    id: block

    property Theme theme: Theme {}
    property var rows: []

    visible: rows.length > 0
    implicitHeight: content.implicitHeight + 18
    radius: 8
    color: theme.surface
    border.width: 1
    border.color: theme.border

    ColumnLayout {
        id: content
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.margins: 9
        spacing: 3

        Repeater {
            model: block.rows

            delegate: RowLayout {
                required property var modelData
                Layout.fillWidth: true
                spacing: 8

                Text {
                    text: modelData.label
                    font.family: block.theme.fontFamily
                    font.pixelSize: 10
                    color: block.theme.muted
                    Layout.preferredWidth: 58
                }

                Text {
                    text: modelData.value
                    font.family: block.theme.fontFamily
                    font.pixelSize: 10
                    color: block.theme.text
                    elide: Text.ElideRight
                    Layout.fillWidth: true
                }
            }
        }
    }
}
