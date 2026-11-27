// Reusable bottom control bar with Revert, Validate, Apply, Close, and status indicators

import QtQuick
import QtQuick.Layouts

Item {
    id: actionsBar

    property var theme: null
    property var backend: null
    property string targetFile: ""
    property bool canApply: true
    property bool canRevert: true
    property bool canEdit: true

    signal applyClicked()
    signal validateClicked()
    signal revertClicked()
    signal editClicked()
    signal closeClicked()

    implicitHeight: 44

    Rectangle {
        anchors.fill: parent
        color: theme ? theme.surface : "#1c1c20"
        border.width: 1
        border.color: theme ? theme.border : "#303036"
        radius: 8

        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: 12
            anchors.rightMargin: 12
            spacing: 10

            // Revert Button
            Rectangle {
                visible: actionsBar.canRevert
                implicitWidth: revertContent.implicitWidth + 20
                implicitHeight: 30
                radius: 6
                color: revertMouse.containsMouse ? (theme ? theme.hover : "#2f2f35") : "transparent"
                border.width: 1
                border.color: theme ? theme.warning : "#f9e2af"

                RowLayout {
                    id: revertContent
                    anchors.centerIn: parent
                    spacing: 6

                    Text {
                        text: "↺"
                        font.bold: true
                        color: theme ? theme.warning : "#f9e2af"
                    }

                    Text {
                        text: "Revert File"
                        font.family: theme ? theme.fontFamily : "sans-serif"
                        font.pixelSize: 11
                        font.bold: true
                        color: theme ? theme.warning : "#f9e2af"
                    }
                }

                MouseArea {
                    id: revertMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        if (actionsBar.targetFile && backend) {
                            backend.revertFile(actionsBar.targetFile);
                        }
                        actionsBar.revertClicked();
                    }
                }
            }

            // Edit in Default Editor Button
            Rectangle {
                visible: actionsBar.canEdit && actionsBar.targetFile.length > 0
                implicitWidth: editContent.implicitWidth + 20
                implicitHeight: 30
                radius: 6
                color: editMouse.containsMouse ? (theme ? theme.hover : "#2f2f35") : "transparent"
                border.width: 1
                border.color: theme ? theme.accent : "#cba6f7"

                RowLayout {
                    id: editContent
                    anchors.centerIn: parent
                    spacing: 6

                    Text {
                        text: ""
                        font.family: theme ? theme.iconFont : "sans-serif"
                        font.pixelSize: 11
                        color: theme ? theme.accent : "#cba6f7"
                    }

                    Text {
                        text: {
                            var fname = actionsBar.targetFile ? actionsBar.targetFile.split('/').pop() : "";
                            return fname ? ("Edit " + fname) : "Edit File";
                        }
                        font.family: theme ? theme.fontFamily : "sans-serif"
                        font.pixelSize: 11
                        font.bold: true
                        color: theme ? theme.accent : "#cba6f7"
                    }
                }

                MouseArea {
                    id: editMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        if (actionsBar.targetFile && backend) {
                            backend.editFile(actionsBar.targetFile);
                        }
                        actionsBar.editClicked();
                    }
                }
            }

            // Status message
            RowLayout {
                Layout.fillWidth: true
                spacing: 6
                visible: backend && backend.statusMessage.length > 0

                Text {
                    text: backend.statusType === "error" ? "⚠" : (backend.statusType === "success" ? "✓" : "ℹ")
                    font.pixelSize: 12
                    color: backend.statusType === "error"
                        ? (theme ? theme.bad : "#f38ba8")
                        : (backend.statusType === "success" ? (theme ? theme.good : "#a6e3a1") : (theme ? theme.info : "#89b4fa"))
                }

                Text {
                    Layout.fillWidth: true
                    text: backend ? backend.statusMessage : ""
                    font.family: theme ? theme.fontFamily : "sans-serif"
                    font.pixelSize: 11
                    color: backend.statusType === "error"
                        ? (theme ? theme.bad : "#f38ba8")
                        : (backend.statusType === "success" ? (theme ? theme.good : "#a6e3a1") : (theme ? theme.muted : "#aaaaaa"))
                    elide: Text.ElideRight
                }
            }

            Item { Layout.fillWidth: true; visible: !backend || !backend.statusMessage }

            // Validate Button
            Rectangle {
                implicitWidth: 80
                implicitHeight: 30
                radius: 6
                color: valMouse.containsMouse ? (theme ? theme.hover : "#282830") : (theme ? theme.surfaceAlt : "#222228")
                border.width: 1
                border.color: theme ? theme.border : "#35353d"

                Text {
                    anchors.centerIn: parent
                    text: "Validate"
                    font.family: theme ? theme.fontFamily : "sans-serif"
                    font.pixelSize: 11
                    color: theme ? theme.text : "#ffffff"
                }

                MouseArea {
                    id: valMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: actionsBar.validateClicked()
                }
            }

            // Apply Button
            Rectangle {
                implicitWidth: 84
                implicitHeight: 30
                radius: 6
                color: applyMouse.containsMouse
                    ? (theme ? Qt.lighter(theme.accent, 1.1) : "#d9b8ff")
                    : (theme ? theme.accent : "#cba6f7")
                opacity: actionsBar.canApply && (!backend || !backend.busy) ? 1.0 : 0.5

                Text {
                    anchors.centerIn: parent
                    text: backend && backend.busy ? "Applying..." : "Apply"
                    font.family: theme ? theme.fontFamily : "sans-serif"
                    font.pixelSize: 11
                    font.bold: true
                    color: theme ? theme.accentInk : "#111111"
                }

                MouseArea {
                    id: applyMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    enabled: actionsBar.canApply && (!backend || !backend.busy)
                    onClicked: actionsBar.applyClicked()
                }
            }

            // Close Button
            Rectangle {
                implicitWidth: 72
                implicitHeight: 30
                radius: 6
                color: closeMouse.containsMouse ? (theme ? theme.hover : "#282830") : (theme ? theme.surfaceAlt : "#222228")
                border.width: 1
                border.color: theme ? theme.border : "#35353d"

                Text {
                    anchors.centerIn: parent
                    text: "Close"
                    font.family: theme ? theme.fontFamily : "sans-serif"
                    font.pixelSize: 11
                    color: theme ? theme.text : "#ffffff"
                }

                MouseArea {
                    id: closeMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        actionsBar.closeClicked();
                        Qt.quit();
                    }
                }
            }
        }
    }
}
