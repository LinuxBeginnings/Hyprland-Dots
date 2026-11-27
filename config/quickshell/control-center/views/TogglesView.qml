// Quick Settings switchboard view covering system toggles

import QtQuick
import QtQuick.Layouts
import "../components"

Item {
    id: togglesView

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
            theme: togglesView.theme
            helpData: togglesView.helpService ? togglesView.helpService.getHelp("toggles") : null
        }

        // Toggles Grid
        GridLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            columns: 2
            rowSpacing: 12
            columnSpacing: 12

            // Toggle 1: Weather Units
            Rectangle {
                Layout.fillWidth: true
                Layout.fillHeight: true
                radius: 8
                color: theme ? theme.surface : "#1c1c20"
                border.width: 1
                border.color: theme ? theme.border : "#303036"

                RowLayout {
                    anchors.fill: parent
                    anchors.margins: 16
                    spacing: 14

                    Text {
                        text: "󰖐"
                        font.family: theme ? theme.iconFont : "sans-serif"
                        font.pixelSize: 28
                        color: theme ? theme.accent : "#cba6f7"
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 2
                        Text { text: "Weather Units"; font.pixelSize: 13; font.bold: true; color: theme ? theme.text : "#ffffff" }
                        Text {
                            text: "Current: " + (backend && backend.toggles.weather_units === "imperial" ? "Imperial (°F)" : "Metric (°C)")
                            font.pixelSize: 11
                            color: theme ? theme.muted : "#888888"
                        }
                    }

                    Rectangle {
                        implicitWidth: 80
                        implicitHeight: 30
                        radius: 6
                        color: t1Mouse.containsMouse ? (theme ? theme.hover : "#2c2c34") : (theme ? theme.surfaceAlt : "#222228")
                        border.width: 1
                        border.color: theme ? theme.accent : "#cba6f7"
                        Text { anchors.centerIn: parent; text: "Switch 󰑐"; font.pixelSize: 11; font.bold: true; color: theme ? theme.accent : "#cba6f7" }
                        MouseArea {
                            id: t1Mouse
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                if (backend) backend.setToggle("weather");
                            }
                        }
                    }
                }
            }

            // Toggle 2: Waybar Clock Format
            Rectangle {
                Layout.fillWidth: true
                Layout.fillHeight: true
                radius: 8
                color: theme ? theme.surface : "#1c1c20"
                border.width: 1
                border.color: theme ? theme.border : "#303036"

                RowLayout {
                    anchors.fill: parent
                    anchors.margins: 16
                    spacing: 14

                    Text {
                        text: "󰥔"
                        font.family: theme ? theme.iconFont : "sans-serif"
                        font.pixelSize: 28
                        color: theme ? theme.accent : "#cba6f7"
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 2
                        Text { text: "Clock Format"; font.pixelSize: 13; font.bold: true; color: theme ? theme.text : "#ffffff" }
                        Text { text: "Toggle 12H (AM/PM) or 24H military time on Waybar"; font.pixelSize: 11; color: theme ? theme.muted : "#888888" }
                    }

                    Rectangle {
                        implicitWidth: 80
                        implicitHeight: 30
                        radius: 6
                        color: t2Mouse.containsMouse ? (theme ? theme.hover : "#2c2c34") : (theme ? theme.surfaceAlt : "#222228")
                        border.width: 1
                        border.color: theme ? theme.accent : "#cba6f7"
                        Text { anchors.centerIn: parent; text: "Toggle 󰥔"; font.pixelSize: 11; font.bold: true; color: theme ? theme.accent : "#cba6f7" }
                        MouseArea {
                            id: t2Mouse
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                if (backend) backend.setToggle("clock");
                            }
                        }
                    }
                }
            }

            // Toggle 3: Game Mode
            Rectangle {
                Layout.fillWidth: true
                Layout.fillHeight: true
                radius: 8
                color: theme ? theme.surface : "#1c1c20"
                border.width: 1
                border.color: theme ? theme.border : "#303036"

                RowLayout {
                    anchors.fill: parent
                    anchors.margins: 16
                    spacing: 14

                    Text {
                        text: "󰊴"
                        font.family: theme ? theme.iconFont : "sans-serif"
                        font.pixelSize: 28
                        color: theme ? theme.accent : "#cba6f7"
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 2
                        Text { text: "Game Mode (High FPS)"; font.pixelSize: 13; font.bold: true; color: theme ? theme.text : "#ffffff" }
                        Text { text: "Disables blur, animations, and shadows for peak performance"; font.pixelSize: 11; color: theme ? theme.muted : "#888888" }
                    }

                    Rectangle {
                        implicitWidth: 80
                        implicitHeight: 30
                        radius: 6
                        color: t3Mouse.containsMouse ? (theme ? theme.hover : "#2c2c34") : (theme ? theme.surfaceAlt : "#222228")
                        border.width: 1
                        border.color: theme ? theme.accent : "#cba6f7"
                        Text { anchors.centerIn: parent; text: "Toggle 󰊴"; font.pixelSize: 11; font.bold: true; color: theme ? theme.accent : "#cba6f7" }
                        MouseArea {
                            id: t3Mouse
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                if (backend) backend.setToggle("game_mode");
                            }
                        }
                    }
                }
            }

            // Toggle 4: Window Wobble
            Rectangle {
                Layout.fillWidth: true
                Layout.fillHeight: true
                radius: 8
                color: theme ? theme.surface : "#1c1c20"
                border.width: 1
                border.color: theme ? theme.border : "#303036"

                RowLayout {
                    anchors.fill: parent
                    anchors.margins: 16
                    spacing: 14

                    Text {
                        text: "󰖲"
                        font.family: theme ? theme.iconFont : "sans-serif"
                        font.pixelSize: 28
                        color: theme ? theme.accent : "#cba6f7"
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 2
                        Text { text: "Window Wobble (0.57+)"; font.pixelSize: 13; font.bold: true; color: theme ? theme.text : "#ffffff" }
                        Text {
                            text: "Status: " + (backend && backend.toggles.wobble_enabled ? "Enabled" : "Disabled")
                            font.pixelSize: 11
                            color: theme ? theme.muted : "#888888"
                        }
                    }

                    Rectangle {
                        implicitWidth: 80
                        implicitHeight: 30
                        radius: 6
                        color: t4Mouse.containsMouse ? (theme ? theme.hover : "#2c2c34") : (theme ? theme.surfaceAlt : "#222228")
                        border.width: 1
                        border.color: theme ? theme.accent : "#cba6f7"
                        Text { anchors.centerIn: parent; text: "Toggle 󰖲"; font.pixelSize: 11; font.bold: true; color: theme ? theme.accent : "#cba6f7" }
                        MouseArea {
                            id: t4Mouse
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                if (backend) backend.setToggle("wobble");
                            }
                        }
                    }
                }
            }
        }
    }
}
