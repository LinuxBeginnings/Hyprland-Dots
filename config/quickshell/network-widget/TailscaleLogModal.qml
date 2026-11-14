// Modal for viewing Tailscale SSH logs with Text/JSON format toggle and Save to Disk.

import QtQuick
import QtQuick.Layouts

Rectangle {
    id: modal

    property Theme theme: Theme {}
    property Backend backend

    signal close()

    radius: 12
    color: theme.surface
    border.width: 1
    border.color: theme.border

    property string format: "text" // "text" or "json"
    property string defaultSavePath: {
        var home = Quickshell.env("HOME") || "";
        return home + "/tailscale-ssh.log";
    }

    property string statusMsg: ""
    property bool statusSuccess: false
    property bool saving: false

    function refreshLogs() {
        if (!backend) return;
        backend.loadTailscaleLogs(modal.format);
    }

    onVisibleChanged: {
        if (visible) {
            modal.statusMsg = "";
            modal.refreshLogs();
        }
    }

    onFormatChanged: {
        modal.refreshLogs();
    }

    function saveToDisk() {
        if (!backend || modal.saving) return;
        var p = savePathInput.text.trim();
        if (p === "") {
            modal.statusMsg = "Please enter a destination path";
            modal.statusSuccess = false;
            return;
        }

        modal.saving = true;
        modal.statusMsg = "Saving log to disk...";
        backend.saveTailscaleLogs(p, function (res) {
            modal.saving = false;
            modal.statusSuccess = res.success;
            modal.statusMsg = res.success ? "✓ Saved to " + res.path : ("✗ Save failed: " + res.error);
        });
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 14
        spacing: 10

        // Header
        RowLayout {
            Layout.fillWidth: true
            spacing: 8

            Text {
                text: "󰈙"
                font.family: modal.theme.iconFont
                font.pixelSize: 15
                color: modal.theme.accent
            }

            Text {
                text: "Tailscale SSH Logs"
                font.family: modal.theme.fontFamily
                font.pixelSize: 13
                font.bold: true
                color: modal.theme.text
                Layout.fillWidth: true
            }

            // Format toggle: Text vs JSON
            RowLayout {
                spacing: 4

                Rectangle {
                    implicitWidth: 50
                    implicitHeight: 24
                    radius: 5
                    readonly property bool isSelected: modal.format === "text"
                    color: isSelected ? modal.theme.accent : (textFmtMouse.containsMouse ? modal.theme.hover : modal.theme.surfaceAlt)
                    border.width: 1
                    border.color: isSelected ? modal.theme.accent : modal.theme.border

                    Text {
                        anchors.centerIn: parent
                        text: "Text"
                        font.family: modal.theme.fontFamily
                        font.pixelSize: 10
                        font.bold: parent.isSelected
                        color: parent.isSelected ? modal.theme.accentInk : modal.theme.text
                    }

                    MouseArea {
                        id: textFmtMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        onClicked: modal.format = "text"
                    }
                }

                Rectangle {
                    implicitWidth: 50
                    implicitHeight: 24
                    radius: 5
                    readonly property bool isSelected: modal.format === "json"
                    color: isSelected ? modal.theme.accent : (jsonFmtMouse.containsMouse ? modal.theme.hover : modal.theme.surfaceAlt)
                    border.width: 1
                    border.color: isSelected ? modal.theme.accent : modal.theme.border

                    Text {
                        anchors.centerIn: parent
                        text: "JSON"
                        font.family: modal.theme.fontFamily
                        font.pixelSize: 10
                        font.bold: parent.isSelected
                        color: parent.isSelected ? modal.theme.accentInk : modal.theme.text
                    }

                    MouseArea {
                        id: jsonFmtMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        onClicked: modal.format = "json"
                    }
                }
            }

            // Refresh Button
            Rectangle {
                implicitWidth: 24
                implicitHeight: 24
                radius: 12
                color: refreshMouse.containsMouse ? modal.theme.hover : "transparent"

                Text {
                    anchors.centerIn: parent
                    text: "󰑐"
                    font.family: modal.theme.iconFont
                    font.pixelSize: 12
                    color: modal.theme.text
                }

                MouseArea {
                    id: refreshMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    onClicked: modal.refreshLogs()
                }
            }

            // Close Button
            Rectangle {
                implicitWidth: 24
                implicitHeight: 24
                radius: 12
                color: closeMouse.containsMouse ? modal.theme.hover : "transparent"

                Text {
                    anchors.centerIn: parent
                    text: "󰅖"
                    font.family: modal.theme.iconFont
                    font.pixelSize: 13
                    color: modal.theme.text
                }

                MouseArea {
                    id: closeMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    onClicked: modal.close()
                }
            }
        }

        Rectangle {
            Layout.fillWidth: true
            height: 1
            color: modal.theme.border
        }

        // Log content view
        Rectangle {
            Layout.fillWidth: true
            Layout.fillHeight: true
            radius: 8
            color: modal.theme.bg
            border.width: 1
            border.color: modal.theme.border

            Flickable {
                id: logFlickable
                anchors.fill: parent
                anchors.margins: 8
                contentWidth: logText.implicitWidth
                contentHeight: logText.implicitHeight
                clip: true
                boundsBehavior: Flickable.StopAtBounds

                Text {
                    id: logText
                    text: {
                        if (!modal.backend) return "No logs available";
                        if (modal.format === "json") {
                            return JSON.stringify(modal.backend.tailscaleLogsJson, null, 2);
                        }
                        return modal.backend.tailscaleLogsText || "No logs recorded yet.";
                    }
                    font.family: modal.theme.fontFamily
                    font.pixelSize: 10
                    color: modal.theme.text
                    wrapMode: Text.NoWrap
                }
            }
        }

        // Save to disk section
        RowLayout {
            Layout.fillWidth: true
            spacing: 6

            Text {
                text: "Save Path:"
                font.family: modal.theme.fontFamily
                font.pixelSize: 10
                color: modal.theme.muted
            }

            Rectangle {
                Layout.fillWidth: true
                implicitHeight: 28
                radius: 6
                color: modal.theme.surfaceAlt
                border.width: 1
                border.color: savePathInput.activeFocus ? modal.theme.accent : modal.theme.border

                TextInput {
                    id: savePathInput
                    anchors.fill: parent
                    anchors.leftMargin: 8
                    anchors.rightMargin: 8
                    verticalAlignment: TextInput.AlignVCenter
                    color: modal.theme.text
                    font.family: modal.theme.fontFamily
                    font.pixelSize: 10
                    text: modal.defaultSavePath
                    selectByMouse: true
                }
            }

            Rectangle {
                implicitHeight: 28
                implicitWidth: 95
                radius: 6
                color: modal.theme.surfaceAlt
                border.width: 1
                border.color: modal.theme.border

                RowLayout {
                    anchors.centerIn: parent
                    spacing: 4
                    Text {
                        text: "󰆓"
                        font.family: modal.theme.iconFont
                        font.pixelSize: 11
                        color: modal.theme.accent
                    }
                    Text {
                        text: "Save to Disk"
                        font.family: modal.theme.fontFamily
                        font.pixelSize: 10
                        color: modal.theme.text
                    }
                }

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: modal.saveToDisk()
                }
            }
        }

        // Status Feedback
        RowLayout {
            Layout.fillWidth: true
            spacing: 6
            visible: modal.statusMsg !== ""

            Text {
                text: modal.statusSuccess ? "󰄬" : "󰅖"
                font.family: modal.theme.iconFont
                font.pixelSize: 12
                color: modal.statusSuccess ? modal.theme.good : modal.theme.bad
            }

            Text {
                Layout.fillWidth: true
                text: modal.statusMsg
                font.family: modal.theme.fontFamily
                font.pixelSize: 10
                color: modal.statusSuccess ? modal.theme.good : modal.theme.bad
                wrapMode: Text.Wrap
            }
        }
    }
}
