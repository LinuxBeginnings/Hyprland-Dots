// Expandable contextual help drawer providing page and section documentation

import QtQuick
import QtQuick.Layouts

Item {
    id: helpDrawer

    property var theme: null
    property var helpData: null
    property bool expanded: false

    implicitHeight: expanded ? helpCard.implicitHeight : 38

    Rectangle {
        id: helpCard
        anchors.fill: parent
        radius: 8
        color: theme ? theme.surfaceAlt : "#222228"
        border.width: 1
        border.color: theme ? theme.border : "#35353d"
        clip: true

        Behavior on height {
            NumberAnimation { duration: 180; easing.type: Easing.OutCubic }
        }

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 10
            spacing: 8

            // Header row with toggle
            RowLayout {
                Layout.fillWidth: true
                spacing: 8

                Rectangle {
                    width: 20
                    height: 20
                    radius: 10
                    color: theme ? theme.accent : "#cba6f7"

                    Text {
                        anchors.centerIn: parent
                        text: "?"
                        font.bold: true
                        font.pixelSize: 11
                        color: theme ? theme.accentInk : "#111111"
                    }
                }

                Text {
                    text: helpDrawer.helpData ? helpDrawer.helpData.title : "Help & Documentation"
                    font.family: theme ? theme.fontFamily : "sans-serif"
                    font.pixelSize: 12
                    font.bold: true
                    color: theme ? theme.text : "#ffffff"
                }

                // File location badge
                Rectangle {
                    visible: !!(helpDrawer.helpData && helpDrawer.helpData.file)
                    implicitWidth: fileText.implicitWidth + 8
                    implicitHeight: 18
                    radius: 4
                    color: theme ? theme.surface : "#1a1a1e"
                    border.width: 1
                    border.color: theme ? theme.border : "#35353d"

                    Text {
                        id: fileText
                        anchors.centerIn: parent
                        text: helpDrawer.helpData ? helpDrawer.helpData.file : ""
                        font.family: theme ? theme.fontFamily : "monospace"
                        font.pixelSize: 10
                        color: theme ? theme.accent : "#cba6f7"
                    }
                }

                Item { Layout.fillWidth: true }

                Text {
                    text: helpDrawer.expanded ? "Collapse ▲" : "What is this? ▼"
                    font.family: theme ? theme.fontFamily : "sans-serif"
                    font.pixelSize: 11
                    color: toggleMouse.containsMouse ? (theme ? theme.accent : "#cba6f7") : (theme ? theme.muted : "#888888")

                    MouseArea {
                        id: toggleMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: helpDrawer.expanded = !helpDrawer.expanded
                    }
                }
            }

            // Expanded help content
            ColumnLayout {
                Layout.fillWidth: true
                visible: helpDrawer.expanded
                spacing: 6

                Text {
                    Layout.fillWidth: true
                    text: helpDrawer.helpData ? helpDrawer.helpData.summary : ""
                    font.family: theme ? theme.fontFamily : "sans-serif"
                    font.pixelSize: 12
                    font.bold: true
                    color: theme ? theme.info : "#89b4fa"
                    wrapMode: Text.WordWrap
                }

                Text {
                    Layout.fillWidth: true
                    text: helpDrawer.helpData ? helpDrawer.helpData.description : ""
                    font.family: theme ? theme.fontFamily : "sans-serif"
                    font.pixelSize: 11
                    color: theme ? theme.text : "#dddddd"
                    wrapMode: Text.WordWrap
                    lineHeight: 1.25
                }
            }
        }
    }
}
