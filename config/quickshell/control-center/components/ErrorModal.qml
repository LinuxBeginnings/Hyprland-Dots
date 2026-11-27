// Error modal displaying syntax/validation diagnostics with AI copy support

import QtQuick
import QtQuick.Layouts

Item {
    id: errorModal

    property var theme: null
    property var backend: null
    property bool visibleModal: backend && backend.hasError

    anchors.fill: parent
    visible: visibleModal

    // Backdrop
    Rectangle {
        anchors.fill: parent
        color: "#000000"
        opacity: 0.65

        MouseArea {
            anchors.fill: parent
            onClicked: {}
        }
    }

    // Modal Card
    Rectangle {
        anchors.centerIn: parent
        width: Math.min(680, parent.width - 40)
        height: Math.min(460, parent.height - 40)
        radius: 12
        color: theme ? theme.bg : "#161618"
        border.width: 1
        border.color: theme ? theme.bad : "#f38ba8"
        clip: true

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 20
            spacing: 14

            // Header
            RowLayout {
                Layout.fillWidth: true
                spacing: 10

                Text {
                    text: "⚠"
                    font.pixelSize: 18
                    color: theme ? theme.bad : "#f38ba8"
                }

                Text {
                    text: "Configuration Validation Error"
                    font.family: theme ? theme.fontFamily : "sans-serif"
                    font.pixelSize: 15
                    font.bold: true
                    color: theme ? theme.bad : "#f38ba8"
                }

                Item { Layout.fillWidth: true }

                Text {
                    text: backend ? backend.lastErrorTarget : ""
                    font.family: theme ? theme.fontFamily : "monospace"
                    font.pixelSize: 11
                    color: theme ? theme.muted : "#888888"
                }
            }

            Text {
                Layout.fillWidth: true
                text: "The requested modification was blocked because it failed pre-flight syntax or duplication checks. The original file has been preserved intact."
                font.family: theme ? theme.fontFamily : "sans-serif"
                font.pixelSize: 12
                color: theme ? theme.text : "#ffffff"
                wrapMode: Text.WordWrap
            }

            // Diagnostic Console Box
            Rectangle {
                Layout.fillWidth: true
                Layout.fillHeight: true
                radius: 6
                color: theme ? theme.surface : "#1a1a1e"
                border.width: 1
                border.color: theme ? theme.border : "#303036"
                clip: true

                Flickable {
                    anchors.fill: parent
                    anchors.margins: 10
                    contentWidth: errorText.implicitWidth
                    contentHeight: errorText.implicitHeight
                    clip: true

                    Text {
                        id: errorText
                        text: backend ? backend.lastErrorMessage : "No error output available."
                        font.family: theme ? theme.fontFamily : "monospace"
                        font.pixelSize: 11
                        color: theme ? theme.bad : "#f38ba8"
                        wrapMode: Text.WordWrap
                    }
                }
            }

            // Buttons Bar
            RowLayout {
                Layout.fillWidth: true
                spacing: 10

                // Copy Error for AI Button
                Rectangle {
                    implicitWidth: copyContent.implicitWidth + 24
                    implicitHeight: 34
                    radius: 6
                    color: copyMouse.containsMouse ? (theme ? theme.hover : "#303038") : (theme ? theme.surfaceAlt : "#25252c")
                    border.width: 1
                    border.color: theme ? theme.accent : "#cba6f7"

                    RowLayout {
                        id: copyContent
                        anchors.centerIn: parent
                        spacing: 8

                        Text {
                            text: "📋"
                            font.pixelSize: 12
                        }

                        Text {
                            text: "Copy Error for AI"
                            font.family: theme ? theme.fontFamily : "sans-serif"
                            font.pixelSize: 12
                            font.bold: true
                            color: theme ? theme.accent : "#cba6f7"
                        }
                    }

                    MouseArea {
                        id: copyMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            if (backend) backend.copyErrorToClipboard();
                        }
                    }
                }

                Item { Layout.fillWidth: true }

                // Dismiss Button
                Rectangle {
                    implicitWidth: 90
                    implicitHeight: 34
                    radius: 6
                    color: dismissMouse.containsMouse ? (theme ? theme.hover : "#333338") : (theme ? theme.surface : "#202024")
                    border.width: 1
                    border.color: theme ? theme.border : "#35353d"

                    Text {
                        anchors.centerIn: parent
                        text: "Dismiss"
                        font.family: theme ? theme.fontFamily : "sans-serif"
                        font.pixelSize: 12
                        color: theme ? theme.text : "#ffffff"
                    }

                    MouseArea {
                        id: dismissMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            if (backend) backend.hasError = false;
                        }
                    }
                }
            }
        }
    }
}
