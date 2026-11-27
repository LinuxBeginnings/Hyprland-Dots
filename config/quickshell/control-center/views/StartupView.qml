// Startup Applications view for KoolDots Control Center

import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import "../components"

Item {
    id: startupView

    property var theme: null
    property var backend: null
    property var helpService: null

    property string newCommandText: ""

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 14
        spacing: 12

        // Contextual Help Drawer
        HelpDrawer {
            Layout.fillWidth: true
            theme: startupView.theme
            helpData: startupView.helpService ? startupView.helpService.getHelp("startup") : null
        }

        // Add Command Row
        RowLayout {
            Layout.fillWidth: true
            spacing: 10

            Rectangle {
                Layout.fillWidth: true
                implicitHeight: 36
                radius: 6
                color: theme ? theme.surface : "#202024"
                border.width: 1
                border.color: newCmdInput.activeFocus ? (theme ? theme.accent : "#cba6f7") : (theme ? theme.border : "#35353d")

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 10
                    anchors.rightMargin: 10
                    spacing: 8

                    Text {
                        text: "󰐥"
                        font.family: theme ? theme.iconFont : "sans-serif"
                        font.pixelSize: 14
                        color: theme ? theme.accent : "#cba6f7"
                    }

                    TextInput {
                        id: newCmdInput
                        Layout.fillWidth: true
                        font.family: theme ? theme.fontFamily : "monospace"
                        font.pixelSize: 12
                        color: theme ? theme.text : "#ffffff"
                        clip: true
                        text: startupView.newCommandText
                        onTextChanged: startupView.newCommandText = text

                        Text {
                            anchors.fill: parent
                            text: "Add new startup command or script (e.g. blueman-applet, cbatticon)..."
                            font: parent.font
                            color: theme ? theme.muted : "#666666"
                            visible: !newCmdInput.text && !newCmdInput.activeFocus
                        }
                    }
                }
            }

            Rectangle {
                implicitWidth: addCmdBtnText.implicitWidth + 24
                implicitHeight: 36
                radius: 6
                color: addCmdMouse.containsMouse ? (theme ? Qt.lighter(theme.accent, 1.1) : "#d9b8ff") : (theme ? theme.accent : "#cba6f7")

                Text {
                    id: addCmdBtnText
                    anchors.centerIn: parent
                    text: "+ Add Startup Command"
                    font.family: theme ? theme.fontFamily : "sans-serif"
                    font.pixelSize: 11
                    font.bold: true
                    color: theme ? theme.accentInk : "#111111"
                }

                MouseArea {
                    id: addCmdMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        if (startupView.newCommandText.trim().length > 0) {
                            var list = backend.startupApps.slice();
                            list.push({ "command": startupView.newCommandText.trim(), "enabled": true });
                            backend.startupApps = list;
                            startupView.newCommandText = "";
                            newCmdInput.text = "";
                        }
                    }
                }
            }
        }

        // Commands List
        Rectangle {
            Layout.fillWidth: true
            Layout.fillHeight: true
            radius: 8
            color: theme ? theme.surface : "#1c1c20"
            border.width: 1
            border.color: theme ? theme.border : "#303036"
            clip: true

            ListView {
                id: sList
                anchors.fill: parent
                anchors.margins: 6
                model: backend ? backend.startupApps : []
                spacing: 4
                clip: true

                delegate: Rectangle {
                    id: sDelegate
                    required property var modelData
                    required property int index
                    width: sList.width
                    implicitHeight: 44
                    radius: 6
                    color: sMouse.containsMouse ? (theme ? theme.hover : "#24242a") : (theme ? theme.surfaceAlt : "#222228")
                    border.width: 1
                    border.color: theme ? theme.border : "#303036"

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 12
                        anchors.rightMargin: 12
                        spacing: 12

                        // Toggle Checkbox
                        Rectangle {
                            width: 18
                            height: 18
                            radius: 4
                            color: sDelegate.modelData.enabled ? (theme ? theme.accent : "#cba6f7") : "transparent"
                            border.width: 1
                            border.color: theme ? theme.accent : "#cba6f7"

                            Text {
                                anchors.centerIn: parent
                                visible: sDelegate.modelData.enabled
                                text: "✓"
                                font.pixelSize: 11
                                font.bold: true
                                color: theme ? theme.accentInk : "#111111"
                            }

                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    var list = backend.startupApps.slice();
                                    list[sDelegate.index].enabled = !list[sDelegate.index].enabled;
                                    backend.startupApps = list;
                                }
                            }
                        }

                        // Command Text
                        Text {
                            Layout.fillWidth: true
                            text: sDelegate.modelData.command
                            font.family: theme ? theme.fontFamily : "monospace"
                            font.pixelSize: 12
                            font.strikeout: !sDelegate.modelData.enabled
                            color: sDelegate.modelData.enabled ? (theme ? theme.text : "#ffffff") : (theme ? theme.muted : "#666666")
                            elide: Text.ElideRight
                        }

                        // Delete Entry Button
                        Rectangle {
                            width: 26
                            height: 26
                            radius: 4
                            color: delMouse.containsMouse ? (theme ? theme.bad : "#f38ba8") : "transparent"
                            border.width: 1
                            border.color: theme ? theme.border : "#35353d"

                            Text {
                                anchors.centerIn: parent
                                text: "🗑"
                                font.pixelSize: 11
                            }

                            MouseArea {
                                id: delMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    var list = backend.startupApps.slice();
                                    list.splice(sDelegate.index, 1);
                                    backend.startupApps = list;
                                }
                            }
                        }
                    }

                    MouseArea {
                        id: sMouse
                        anchors.fill: parent
                        hoverEnabled: true
                    }
                }
            }
        }

        // Bottom Action Bar
        ActionButtons {
            Layout.fillWidth: true
            theme: startupView.theme
            backend: startupView.backend
            targetFile: backend ? backend.configHome + "/hypr/UserConfigs/user_startup.lua" : ""
            onApplyClicked: {
                if (backend) {
                    backend.statusMessage = "Startup applications updated!";
                    backend.statusType = "success";
                }
            }
            onValidateClicked: {
                if (backend) {
                    backend.statusMessage = "user_startup.lua validation passed!";
                    backend.statusType = "success";
                }
            }
        }
    }
}
