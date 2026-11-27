// Monitors and multi-display management view

import QtQuick
import QtQuick.Layouts
import "../components"

Item {
    id: monitorsView

    property var theme: null
    property var backend: null
    property var helpService: null

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 14
        spacing: 14

        // Contextual Help Drawer
        HelpDrawer {
            Layout.fillWidth: true
            theme: monitorsView.theme
            helpData: monitorsView.helpService ? monitorsView.helpService.getHelp("monitors") : null
        }

        // Monitors Overview Card
        Rectangle {
            Layout.fillWidth: true
            implicitHeight: 120
            radius: 8
            color: theme ? theme.surface : "#1c1c20"
            border.width: 1
            border.color: theme ? theme.border : "#303036"

            RowLayout {
                anchors.fill: parent
                anchors.margins: 16
                spacing: 16

                Rectangle {
                    width: 56
                    height: 56
                    radius: 28
                    color: theme ? theme.surfaceAlt : "#26262e"
                    border.width: 1
                    border.color: theme ? theme.accent : "#cba6f7"
                    Text { anchors.centerIn: parent; text: "󰍹"; font.family: theme ? theme.iconFont : "sans-serif"; font.pixelSize: 28; color: theme ? theme.accent : "#cba6f7" }
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 4
                    Text { text: "Display Layouts & Monitor Profiles"; font.pixelSize: 15; font.bold: true; color: theme ? theme.text : "#ffffff" }
                    Text {
                        text: "KoolDots tracks displays by hardware identity so multi-monitor setups, external docks, and laptop lids restore reliably without manual reconfiguration."
                        font.pixelSize: 11
                        color: theme ? theme.muted : "#888888"
                        wrapMode: Text.WordWrap
                    }
                    Text {
                        text: "Managed in: ~/.config/hypr/UserConfigs/monitors.lua"
                        font.family: "monospace"
                        font.pixelSize: 10
                        color: theme ? theme.info : "#89b4fa"
                    }
                }
            }
        }

        // Action Buttons Row (Launch Display Profile Menu / nwg-displays)
        RowLayout {
            Layout.fillWidth: true
            spacing: 12

            Rectangle {
                Layout.fillWidth: true
                implicitHeight: 48
                radius: 8
                color: d1Mouse.containsMouse ? (theme ? theme.hover : "#282830") : (theme ? theme.surface : "#1c1c20")
                border.width: 1
                border.color: theme ? theme.border : "#303036"

                RowLayout {
                    anchors.centerIn: parent
                    spacing: 10
                    Text { text: "󰒓"; font.family: theme ? theme.iconFont : "sans-serif"; font.pixelSize: 16; color: theme ? theme.accent : "#cba6f7" }
                    Text { text: "Open Display Profiles Menu (SUPER+ALT+D)"; font.bold: true; font.pixelSize: 12; color: theme ? theme.text : "#ffffff" }
                }

                MouseArea {
                    id: d1Mouse
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        if (backend) {
                            launchProfileProcess.command = [backend.configHome + "/hypr/scripts/DisplayProfileMenu.sh"];
                            launchProfileProcess.running = true;
                        }
                    }
                }
            }

            Rectangle {
                Layout.fillWidth: true
                implicitHeight: 48
                radius: 8
                color: d2Mouse.containsMouse ? (theme ? theme.hover : "#282830") : (theme ? theme.surface : "#1c1c20")
                border.width: 1
                border.color: theme ? theme.border : "#303036"

                RowLayout {
                    anchors.centerIn: parent
                    spacing: 10
                    Text { text: "󰍺"; font.family: theme ? theme.iconFont : "sans-serif"; font.pixelSize: 16; color: theme ? theme.accent : "#cba6f7" }
                    Text { text: "Launch nwg-displays Layout Editor"; font.bold: true; font.pixelSize: 12; color: theme ? theme.text : "#ffffff" }
                }

                MouseArea {
                    id: d2Mouse
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        launchNwgProcess.command = ["nwg-displays"];
                        launchNwgProcess.running = true;
                    }
                }
            }
        }

        Item { Layout.fillHeight: true }
    }

    Process { id: launchProfileProcess }
    Process { id: launchNwgProcess }
}
