// Main Quickshell weather overlay panel.

import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland

PanelWindow {
    id: panel

    property Theme theme: null
    property Backend backend: null

    property bool shown: false
    property bool showSettings: false
    property bool sideBySideMode: false

    visible: true
    color: "transparent"
    exclusiveZone: 0

    anchors.top: true
    anchors.left: true
    anchors.right: panel.shown
    anchors.bottom: panel.shown
    implicitWidth: panel.shown ? 0 : 1
    implicitHeight: panel.shown ? 0 : 1

    WlrLayershell.layer: panel.shown ? WlrLayer.Overlay : WlrLayer.Background
    WlrLayershell.namespace: "quickshell:weather"
    WlrLayershell.keyboardFocus: panel.shown ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

    readonly property color cardColor: Qt.rgba(
        theme ? theme.bg.r : 0.08,
        theme ? theme.bg.g : 0.08,
        theme ? theme.bg.b : 0.09,
        0.95
    )

    onShownChanged: {
        if (shown && backend) {
            backend.refresh();
        } else {
            showSettings = false;
        }
    }

    // Dimmed backdrop (click outside to dismiss)
    Rectangle {
        anchors.fill: parent
        visible: panel.shown
        color: "#000000"
        opacity: 0.40

        MouseArea {
            anchors.fill: parent
            onClicked: panel.shown = false
        }
    }

    // Centered Card (starts at 40% of screen width)
    Rectangle {
        id: card

        anchors.centerIn: parent
        width: panel.sideBySideMode
            ? Math.min(1200, Math.max(880, Math.round(panel.width * 0.65)))
            : Math.min(840, Math.max(680, Math.round(panel.width * 0.40)))
        height: Math.min(900, Math.max(560, Math.round(panel.height * 0.65)))
        visible: panel.shown
        radius: 16
        color: panel.cardColor
        border.width: 1
        border.color: panel.theme ? panel.theme.border : "#3a3a3f"
        opacity: panel.shown ? 1 : 0
        clip: true

        Behavior on opacity {
            NumberAnimation { duration: 140 }
        }

        Behavior on width {
            NumberAnimation { duration: 180; easing.type: Easing.OutQuad }
        }

        focus: panel.shown
        Keys.onEscapePressed: {
            if (panel.showSettings) {
                panel.showSettings = false;
            } else {
                panel.shown = false;
            }
        }

        MouseArea {
            anchors.fill: parent
        }

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 14
            spacing: 12

            // Top Bar: Title + Location Tabs + Controls
            RowLayout {
                Layout.fillWidth: true
                spacing: 8

                // Title Pill
                RowLayout {
                    spacing: 6
                    Rectangle {
                        width: 3
                        height: 16
                        radius: 1.5
                        color: panel.theme ? panel.theme.accent : "#cba6f7"
                    }
                    Text {
                        text: "Weather"
                        font.family: panel.theme ? panel.theme.fontFamily : "sans-serif"
                        font.pixelSize: 14
                        font.bold: true
                        color: panel.theme ? panel.theme.text : "#ffffff"
                    }
                }

                Item { Layout.fillWidth: true }

                // Location Tabs
                LocationTabs {
                    theme: panel.theme
                    locations: panel.backend ? panel.backend.locations : []
                    activeId: panel.backend && panel.backend.settings ? panel.backend.settings.active_location_id : ""
                    sideBySideMode: panel.sideBySideMode
                    onSelectLocation: function (locId) {
                        panel.sideBySideMode = false;
                        panel.showSettings = false;
                        if (panel.backend) panel.backend.setActiveLocation(locId);
                    }
                    onToggleSideBySide: {
                        panel.showSettings = false;
                        panel.sideBySideMode = !panel.sideBySideMode;
                    }
                    onOpenSettings: {
                        panel.showSettings = !panel.showSettings;
                    }
                }

                // Refresh Button
                Rectangle {
                    implicitWidth: 28
                    implicitHeight: 28
                    radius: 14
                    color: refreshMouse.containsMouse ? (panel.theme ? panel.theme.hover : "#26262a") : "transparent"
                    border.width: 1
                    border.color: panel.theme ? panel.theme.border : "#3a3a3f"

                    Text {
                        anchors.centerIn: parent
                        text: "󰑐"
                        font.family: panel.theme ? panel.theme.iconFont : "sans-serif"
                        font.pixelSize: 12
                        color: panel.theme ? panel.theme.text : "#ffffff"
                    }

                    MouseArea {
                        id: refreshMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        onClicked: {
                            if (panel.backend) panel.backend.refresh();
                        }
                    }
                }

                // Settings Toggle Button
                Rectangle {
                    implicitWidth: 28
                    implicitHeight: 28
                    radius: 14
                    color: panel.showSettings
                        ? (panel.theme ? panel.theme.accent : "#cba6f7")
                        : (settingsMouse.containsMouse ? (panel.theme ? panel.theme.hover : "#26262a") : "transparent")
                    border.width: 1
                    border.color: panel.showSettings ? (panel.theme ? panel.theme.accent : "#cba6f7") : (panel.theme ? panel.theme.border : "#3a3a3f")

                    Text {
                        anchors.centerIn: parent
                        text: "󰒓"
                        font.family: panel.theme ? panel.theme.iconFont : "sans-serif"
                        font.pixelSize: 13
                        color: panel.showSettings
                            ? (panel.theme ? panel.theme.accentInk : "#161618")
                            : (panel.theme ? panel.theme.text : "#ffffff")
                    }

                    MouseArea {
                        id: settingsMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        onClicked: panel.showSettings = !panel.showSettings
                    }
                }

                // Close Button
                Rectangle {
                    implicitWidth: 28
                    implicitHeight: 28
                    radius: 14
                    color: closeArea.containsMouse ? (panel.theme ? panel.theme.hover : "#26262a") : "transparent"

                    Text {
                        anchors.centerIn: parent
                        text: "󰅖"
                        font.family: panel.theme ? panel.theme.iconFont : "sans-serif"
                        font.pixelSize: 13
                        color: panel.theme ? panel.theme.text : "#ffffff"
                    }

                    MouseArea {
                        id: closeArea
                        anchors.fill: parent
                        hoverEnabled: true
                        onClicked: panel.shown = false
                    }
                }
            }

            Rectangle {
                Layout.fillWidth: true
                height: 1
                color: panel.theme ? panel.theme.border : "#3a3a3f"
            }

            // Main Body Area
            Item {
                Layout.fillWidth: true
                Layout.fillHeight: true

                // View A: Settings Modal
                SettingsModal {
                    anchors.fill: parent
                    visible: panel.showSettings
                    theme: panel.theme
                    backend: panel.backend
                    onClose: panel.showSettings = false
                }

                // View B: Side-by-Side Multi-Location View
                RowLayout {
                    anchors.fill: parent
                    visible: !panel.showSettings && panel.sideBySideMode
                    spacing: 12

                    Repeater {
                        model: panel.backend ? panel.backend.locations : []

                        delegate: ColumnLayout {
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            spacing: 10

                            WeatherHero {
                                Layout.fillWidth: true
                                theme: panel.theme
                                location: modelData
                                settings: panel.backend ? panel.backend.settings : null
                            }

                            HourlyView {
                                Layout.fillWidth: true
                                theme: panel.theme
                                hourlyData: modelData.hourly || []
                                settings: panel.backend ? panel.backend.settings : null
                            }

                            WeeklyView {
                                Layout.fillWidth: true
                                Layout.fillHeight: true
                                theme: panel.theme
                                dailyData: modelData.daily || []
                                settings: panel.backend ? panel.backend.settings : null
                            }
                        }
                    }
                }

                // View C: Standard Single Location View (Hero + Hourly + 7-Day)
                ColumnLayout {
                    anchors.fill: parent
                    visible: !panel.showSettings && !panel.sideBySideMode
                    spacing: 10

                    WeatherHero {
                        Layout.fillWidth: true
                        theme: panel.theme
                        location: panel.backend ? panel.backend.activeLocation : null
                        settings: panel.backend ? panel.backend.settings : null
                    }

                    HourlyView {
                        Layout.fillWidth: true
                        theme: panel.theme
                        hourlyData: panel.backend && panel.backend.activeLocation ? (panel.backend.activeLocation.hourly || []) : []
                        settings: panel.backend ? panel.backend.settings : null
                    }

                    WeeklyView {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        theme: panel.theme
                        dailyData: panel.backend && panel.backend.activeLocation ? (panel.backend.activeLocation.daily || []) : []
                        settings: panel.backend ? panel.backend.settings : null
                    }
                }
            }
        }
    }
}
