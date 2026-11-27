// Home / Dashboard view for KoolDots Control Center

import QtQuick
import QtQuick.Layouts
import "../components"

Item {
    id: homeView

    property var theme: null
    property var backend: null
    property var helpService: null
    signal switchTab(string tabId)

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 16
        spacing: 14

        // Contextual Help Drawer
        HelpDrawer {
            Layout.fillWidth: true
            theme: homeView.theme
            helpData: homeView.helpService ? homeView.helpService.getHelp("home") : null
        }

        // Hero System Status Card
        Rectangle {
            Layout.fillWidth: true
            implicitHeight: 110
            radius: 10
            color: theme ? theme.surface : "#1c1c20"
            border.width: 1
            border.color: theme ? theme.border : "#303036"

            RowLayout {
                anchors.fill: parent
                anchors.margins: 18
                spacing: 20

                // Brand Emblem
                Rectangle {
                    width: 64
                    height: 64
                    radius: 32
                    color: theme ? theme.surfaceAlt : "#26262e"
                    border.width: 2
                    border.color: theme ? theme.accent : "#cba6f7"

                    Text {
                        anchors.centerIn: parent
                        text: "󰣇"
                        font.family: theme ? theme.iconFont : "sans-serif"
                        font.pixelSize: 32
                        color: theme ? theme.accent : "#cba6f7"
                    }
                }

                // Info Details
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 4

                    RowLayout {
                        spacing: 8
                        Text {
                            text: "KoolDots Control Center"
                            font.family: theme ? theme.fontFamily : "sans-serif"
                            font.pixelSize: 18
                            font.bold: true
                            color: theme ? theme.text : "#ffffff"
                        }
                        Rectangle {
                            implicitWidth: dotsVer.implicitWidth + 12
                            implicitHeight: 20
                            radius: 10
                            color: theme ? theme.accent : "#cba6f7"
                            Text {
                                id: dotsVer
                                anchors.centerIn: parent
                                text: backend && backend.systemInfo ? backend.systemInfo.dots_version : "v3.0.0"
                                font.pixelSize: 10
                                font.bold: true
                                color: theme ? theme.accentInk : "#111111"
                            }
                        }
                    }

                    Text {
                        text: "Hyprland " + (backend && backend.systemInfo ? backend.systemInfo.hyprland_version : "v0.57.x") + " • " + (backend && backend.systemInfo ? backend.systemInfo.distro : "Linux") + " (Kernel " + (backend && backend.systemInfo ? backend.systemInfo.kernel : "") + ")"
                        font.family: theme ? theme.fontFamily : "sans-serif"
                        font.pixelSize: 12
                        color: theme ? theme.muted : "#aaaaaa"
                    }

                    Text {
                        text: "Config Root: ~/.config/hypr/UserConfigs • Backups: ~/.local/state/hypr/backups"
                        font.family: theme ? theme.fontFamily : "monospace"
                        font.pixelSize: 11
                        color: theme ? theme.info : "#89b4fa"
                    }
                }

                // Status Refresh Button
                Rectangle {
                    width: 36
                    height: 36
                    radius: 18
                    color: refreshMouse.containsMouse ? (theme ? theme.hover : "#2e2e36") : (theme ? theme.surfaceAlt : "#222228")
                    border.width: 1
                    border.color: theme ? theme.border : "#35353d"

                    Text {
                        anchors.centerIn: parent
                        text: "󰑐"
                        font.family: theme ? theme.iconFont : "sans-serif"
                        font.pixelSize: 16
                        color: theme ? theme.text : "#ffffff"
                    }

                    MouseArea {
                        id: refreshMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            if (backend) backend.refreshAll();
                        }
                    }
                }
            }
        }

        // Section Title: Quick Launch Cards
        Text {
            text: "Fast Management Shortcuts"
            font.family: theme ? theme.fontFamily : "sans-serif"
            font.pixelSize: 14
            font.bold: true
            color: theme ? theme.text : "#ffffff"
        }

        // Grid of Quick Actions
        GridLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            columns: 3
            rowSpacing: 12
            columnSpacing: 12

            // Card 1: Keybinds
            Rectangle {
                Layout.fillWidth: true
                Layout.fillHeight: true
                radius: 8
                color: c1Mouse.containsMouse ? (theme ? theme.hover : "#26262e") : (theme ? theme.surface : "#1c1c20")
                border.width: 1
                border.color: theme ? theme.border : "#303036"

                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: 14
                    spacing: 8

                    Text {
                        text: "󰌌 Keybindings"
                        font.family: theme ? theme.fontFamily : "sans-serif"
                        font.pixelSize: 14
                        font.bold: true
                        color: theme ? theme.accent : "#cba6f7"
                    }
                    Text {
                        Layout.fillWidth: true
                        text: "Explore, customize, remap, and validate your Hyprland shortcuts."
                        font.family: theme ? theme.fontFamily : "sans-serif"
                        font.pixelSize: 11
                        color: theme ? theme.muted : "#999999"
                        wrapMode: Text.WordWrap
                    }
                    Item { Layout.fillHeight: true }
                    Text {
                        text: (backend ? backend.keybinds.length : 0) + " shortcuts registered →"
                        font.pixelSize: 11
                        font.bold: true
                        color: theme ? theme.info : "#89b4fa"
                    }
                }

                MouseArea {
                    id: c1Mouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: homeView.switchTab("keybinds")
                }
            }

            // Card 2: Window Rules
            Rectangle {
                Layout.fillWidth: true
                Layout.fillHeight: true
                radius: 8
                color: c2Mouse.containsMouse ? (theme ? theme.hover : "#26262e") : (theme ? theme.surface : "#1c1c20")
                border.width: 1
                border.color: theme ? theme.border : "#303036"

                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: 14
                    spacing: 8

                    Text {
                        text: "󰖲 Window & Layer Rules"
                        font.family: theme ? theme.fontFamily : "sans-serif"
                        font.pixelSize: 14
                        font.bold: true
                        color: theme ? theme.accent : "#cba6f7"
                    }
                    Text {
                        Layout.fillWidth: true
                        text: "Configure floating windows, sizes, opacities, and layer rules."
                        font.family: theme ? theme.fontFamily : "sans-serif"
                        font.pixelSize: 11
                        color: theme ? theme.muted : "#999999"
                        wrapMode: Text.WordWrap
                    }
                    Item { Layout.fillHeight: true }
                    Text {
                        text: (backend ? backend.windowRules.length : 0) + " rules active →"
                        font.pixelSize: 11
                        font.bold: true
                        color: theme ? theme.info : "#89b4fa"
                    }
                }

                MouseArea {
                    id: c2Mouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: homeView.switchTab("rules")
                }
            }

            // Card 3: Settings
            Rectangle {
                Layout.fillWidth: true
                Layout.fillHeight: true
                radius: 8
                color: c3Mouse.containsMouse ? (theme ? theme.hover : "#26262e") : (theme ? theme.surface : "#1c1c20")
                border.width: 1
                border.color: theme ? theme.border : "#303036"

                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: 14
                    spacing: 8

                    Text {
                        text: "󰒓 System Settings"
                        font.family: theme ? theme.fontFamily : "sans-serif"
                        font.pixelSize: 14
                        font.bold: true
                        color: theme ? theme.accent : "#cba6f7"
                    }
                    Text {
                        Layout.fillWidth: true
                        text: "Keyboard layouts, touchpad gestures, blur variants, and animations."
                        font.family: theme ? theme.fontFamily : "sans-serif"
                        font.pixelSize: 11
                        color: theme ? theme.muted : "#999999"
                        wrapMode: Text.WordWrap
                    }
                    Item { Layout.fillHeight: true }
                    Text {
                        text: "Configure UserConfigs →"
                        font.pixelSize: 11
                        font.bold: true
                        color: theme ? theme.info : "#89b4fa"
                    }
                }

                MouseArea {
                    id: c3Mouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: homeView.switchTab("settings")
                }
            }

            // Card 4: Quick Toggles
            Rectangle {
                Layout.fillWidth: true
                Layout.fillHeight: true
                radius: 8
                color: c4Mouse.containsMouse ? (theme ? theme.hover : "#26262e") : (theme ? theme.surface : "#1c1c20")
                border.width: 1
                border.color: theme ? theme.border : "#303036"

                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: 14
                    spacing: 8

                    Text {
                        text: "󰔡 Quick Toggles"
                        font.family: theme ? theme.fontFamily : "sans-serif"
                        font.pixelSize: 14
                        font.bold: true
                        color: theme ? theme.accent : "#cba6f7"
                    }
                    Text {
                        Layout.fillWidth: true
                        text: "One-click switches for Weather units, Clock 12H/24H, Game Mode, and Wobble."
                        font.family: theme ? theme.fontFamily : "sans-serif"
                        font.pixelSize: 11
                        color: theme ? theme.muted : "#999999"
                        wrapMode: Text.WordWrap
                    }
                    Item { Layout.fillHeight: true }
                    Text {
                        text: "Open Switchboard →"
                        font.pixelSize: 11
                        font.bold: true
                        color: theme ? theme.info : "#89b4fa"
                    }
                }

                MouseArea {
                    id: c4Mouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: homeView.switchTab("toggles")
                }
            }

            // Card 5: Startup Applications
            Rectangle {
                Layout.fillWidth: true
                Layout.fillHeight: true
                radius: 8
                color: c5Mouse.containsMouse ? (theme ? theme.hover : "#26262e") : (theme ? theme.surface : "#1c1c20")
                border.width: 1
                border.color: theme ? theme.border : "#303036"

                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: 14
                    spacing: 8

                    Text {
                        text: "󰐥 Startup Apps"
                        font.family: theme ? theme.fontFamily : "sans-serif"
                        font.pixelSize: 14
                        font.bold: true
                        color: theme ? theme.accent : "#cba6f7"
                    }
                    Text {
                        Layout.fillWidth: true
                        text: "Inspect and manage autostart commands and system daemons."
                        font.family: theme ? theme.fontFamily : "sans-serif"
                        font.pixelSize: 11
                        color: theme ? theme.muted : "#999999"
                        wrapMode: Text.WordWrap
                    }
                    Item { Layout.fillHeight: true }
                    Text {
                        text: (backend ? backend.startupApps.length : 0) + " autostart apps →"
                        font.pixelSize: 11
                        font.bold: true
                        color: theme ? theme.info : "#89b4fa"
                    }
                }

                MouseArea {
                    id: c5Mouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: homeView.switchTab("startup")
                }
            }

            // Card 6: Monitors
            Rectangle {
                Layout.fillWidth: true
                Layout.fillHeight: true
                radius: 8
                color: c6Mouse.containsMouse ? (theme ? theme.hover : "#26262e") : (theme ? theme.surface : "#1c1c20")
                border.width: 1
                border.color: theme ? theme.border : "#303036"

                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: 14
                    spacing: 8

                    Text {
                        text: "󰍹 Monitors & Displays"
                        font.family: theme ? theme.fontFamily : "sans-serif"
                        font.pixelSize: 14
                        font.bold: true
                        color: theme ? theme.accent : "#cba6f7"
                    }
                    Text {
                        Layout.fillWidth: true
                        text: "Multi-monitor display layouts, resolutions, and refresh rate profiles."
                        font.family: theme ? theme.fontFamily : "sans-serif"
                        font.pixelSize: 11
                        color: theme ? theme.muted : "#999999"
                        wrapMode: Text.WordWrap
                    }
                    Item { Layout.fillHeight: true }
                    Text {
                        text: "Manage Monitors →"
                        font.pixelSize: 11
                        font.bold: true
                        color: theme ? theme.info : "#89b4fa"
                    }
                }

                MouseArea {
                    id: c6Mouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: homeView.switchTab("monitors")
                }
            }
        }
    }
}
