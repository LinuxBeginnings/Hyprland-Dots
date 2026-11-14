// Modal for Exporting and Importing Tailscale host configurations.

import QtQuick
import QtQuick.Layouts

Rectangle {
    id: modal

    property Theme theme: Theme {}
    property Backend backend
    property string mode: "export" // "export" or "import"

    signal close()

    radius: 12
    color: theme.surface
    border.width: 1
    border.color: theme.border

    property string defaultPath: {
        var home = Quickshell.env("HOME") || "";
        return home + "/tailscale-hosts-export.json";
    }

    property string statusMsg: ""
    property bool statusSuccess: false
    property bool busy: false

    function reset() {
        modal.statusMsg = "";
        modal.statusSuccess = false;
        modal.busy = false;
        pathInput.text = modal.defaultPath;
    }

    onVisibleChanged: {
        if (visible) reset();
    }

    function execute() {
        if (!backend || modal.busy) return;
        var p = pathInput.text.trim();
        if (p === "") {
            modal.statusMsg = "Please enter a valid file path";
            modal.statusSuccess = false;
            return;
        }

        modal.busy = true;
        modal.statusMsg = modal.mode === "export" ? "Exporting configuration..." : "Importing configuration...";

        if (modal.mode === "export") {
            backend.exportTailscaleConfig(p, function (res) {
                modal.busy = false;
                modal.statusSuccess = res.success;
                modal.statusMsg = res.success ? "✓ Exported to " + res.path : ("✗ Export failed: " + res.error);
                if (res.success) {
                    Qt.callLater(function () {
                        // Keep visible briefly for feedback
                    });
                }
            });
        } else {
            backend.importTailscaleConfig(p, function (res) {
                modal.busy = false;
                modal.statusSuccess = res.success;
                modal.statusMsg = res.success ? "✓ Imported configuration successfully" : ("✗ Import failed: " + res.error);
            });
        }
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
                text: modal.mode === "export" ? "󰈔" : "󰈏"
                font.family: modal.theme.iconFont
                font.pixelSize: 15
                color: modal.theme.accent
            }

            Text {
                text: modal.mode === "export" ? "Export Tailscale Config" : "Import Tailscale Config"
                font.family: modal.theme.fontFamily
                font.pixelSize: 13
                font.bold: true
                color: modal.theme.text
                Layout.fillWidth: true
            }

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

        Text {
            Layout.fillWidth: true
            text: modal.mode === "export"
                ? "Export all configured Tailscale host SSH profiles into a JSON file to transfer to another machine or create a backup:"
                : "Select an exported Tailscale host SSH JSON configuration file from another machine to import and merge:"
            font.family: modal.theme.fontFamily
            font.pixelSize: 11
            color: modal.theme.muted
            wrapMode: Text.Wrap
        }

        ColumnLayout {
            Layout.fillWidth: true
            spacing: 4

            Text {
                text: modal.mode === "export" ? "Export Destination File Path" : "Source File Path"
                font.family: modal.theme.fontFamily
                font.pixelSize: 10
                color: modal.theme.muted
            }

            Rectangle {
                Layout.fillWidth: true
                implicitHeight: 30
                radius: 6
                color: modal.theme.surfaceAlt
                border.width: 1
                border.color: pathInput.activeFocus ? modal.theme.accent : modal.theme.border

                TextInput {
                    id: pathInput
                    anchors.fill: parent
                    anchors.leftMargin: 8
                    anchors.rightMargin: 8
                    verticalAlignment: TextInput.AlignVCenter
                    color: modal.theme.text
                    font.family: modal.theme.fontFamily
                    font.pixelSize: 11
                    text: modal.defaultPath
                    selectByMouse: true
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

        Item {
            Layout.fillHeight: true
        }

        Rectangle {
            Layout.fillWidth: true
            height: 1
            color: modal.theme.border
        }

        // Action Buttons
        RowLayout {
            Layout.fillWidth: true
            spacing: 8

            Item {
                Layout.fillWidth: true
            }

            Rectangle {
                implicitHeight: 30
                implicitWidth: 70
                radius: 6
                color: modal.theme.surfaceAlt
                border.width: 1
                border.color: modal.theme.border

                Text {
                    anchors.centerIn: parent
                    text: "Close"
                    font.family: modal.theme.fontFamily
                    font.pixelSize: 11
                    color: modal.theme.text
                }

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: modal.close()
                }
            }

            Rectangle {
                implicitHeight: 30
                implicitWidth: 80
                radius: 6
                color: modal.theme.accent

                Text {
                    anchors.centerIn: parent
                    text: modal.mode === "export" ? "Export" : "Import"
                    font.family: modal.theme.fontFamily
                    font.pixelSize: 11
                    font.bold: true
                    color: modal.theme.accentInk
                }

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: modal.execute()
                }
            }
        }
    }
}
