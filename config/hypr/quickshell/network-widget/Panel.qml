// The popup itself: a layer-shell panel anchored under the Waybar clock area
// with three horizontal tabs - Ethernet, Wi-Fi and Bluetooth. Each tab owns the
// settings for its device type, and every state change goes through
// Backend -> QsNetworkPanel.sh.

import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland

PanelWindow {
    id: panel

    property Theme theme: Theme {}
    property Backend backend
    // Starting it shows the panel; the Waybar module then toggles it.
    property bool shown: true
    property int tab: 0

    visible: true
    color: "transparent"
    exclusiveZone: 0
    implicitWidth: 420
    implicitHeight: shown ? body.implicitHeight + 28 : 1

    anchors.top: true
    anchors.right: true
    margins.top: 44
    margins.right: 10

    // The surface stays mapped while hidden (collapsed to a single pixel) so
    // the shell keeps running between toggles - quickshell exits once no
    // window is left.
    WlrLayershell.layer: panel.shown ? WlrLayer.Overlay : WlrLayer.Background
    // Only take the keyboard while a password is being typed, so the panel
    // never steals keys from the focused window.
    WlrLayershell.keyboardFocus: (panel.shown && wifiTab.prompting)
        ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

    function syncVisibility() {
        backend.autoRefresh = shown;
        if (shown) {
            backend.error = "";
            backend.refresh();
        } else {
            wifiTab.cancelPrompt();
        }
    }

    Component.onCompleted: syncVisibility()
    onShownChanged: syncVisibility()

    function footerText() {
        if (backend.error !== "") return backend.error;
        if (!backend.loaded) return "Loading…";
        if (backend.busy) return "Working…";
        if (backend.note !== "") return backend.note;
        return "Click a network or device to connect or disconnect";
    }

    Rectangle {
        anchors.fill: parent
        visible: panel.shown
        radius: 14
        color: panel.theme.bg
        border.width: 1
        border.color: panel.theme.border
    }

    ColumnLayout {
        id: body
        visible: panel.shown
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.margins: 14
        spacing: 8

        // ------------------------------------------------------------ header
        RowLayout {
            Layout.fillWidth: true
            spacing: 6

            Text {
                text: "󰖟"
                font.family: panel.theme.iconFont
                font.pixelSize: 16
                color: panel.theme.accent
            }

            Text {
                text: "Connections"
                font.family: panel.theme.fontFamily
                font.pixelSize: 13
                font.bold: true
                color: panel.theme.text
                Layout.fillWidth: true
            }

            IconButton {
                theme: panel.theme
                glyph: "󰑐"
                onClicked: {
                    backend.error = "";
                    backend.refresh();
                }
            }

            IconButton {
                theme: panel.theme
                glyph: "󰅖"
                onClicked: panel.shown = false
            }
        }

        // --------------------------------------------------------------- tabs
        RowLayout {
            Layout.fillWidth: true
            spacing: 4

            TabButton {
                theme: panel.theme
                Layout.fillWidth: true
                icon: "󰌘"
                label: "Ethernet"
                active: panel.tab === 0
                onClicked: panel.tab = 0
            }

            TabButton {
                theme: panel.theme
                Layout.fillWidth: true
                icon: panel.backend.wifiEnabled ? "󰤨" : "󰤭"
                label: "Wi-Fi"
                active: panel.tab === 1
                onClicked: panel.tab = 1
            }

            TabButton {
                theme: panel.theme
                Layout.fillWidth: true
                icon: panel.backend.btEnabled ? "󰂯" : "󰂲"
                label: "Bluetooth"
                active: panel.tab === 2
                onClicked: panel.tab = 2
            }
        }

        // --------------------------------------------------------- tab content
        Item {
            id: tabArea
            Layout.fillWidth: true
            implicitHeight: panel.tab === 0 ? ethernetTab.height
                : (panel.tab === 1 ? wifiTab.height : bluetoothTab.height)

            EthernetTab {
                id: ethernetTab
                width: tabArea.width
                visible: panel.tab === 0
                theme: panel.theme
                backend: panel.backend
            }

            WifiTab {
                id: wifiTab
                width: tabArea.width
                visible: panel.tab === 1
                theme: panel.theme
                backend: panel.backend
            }

            BluetoothTab {
                id: bluetoothTab
                width: tabArea.width
                visible: panel.tab === 2
                theme: panel.theme
                backend: panel.backend
            }
        }

        // ------------------------------------------------------------ footer
        Text {
            Layout.fillWidth: true
            Layout.topMargin: 2
            text: panel.footerText()
            color: backend.error !== "" ? panel.theme.bad : panel.theme.muted
            font.family: panel.theme.fontFamily
            font.pixelSize: 10
            wrapMode: Text.Wrap
            elide: Text.ElideRight
            maximumLineCount: 3
        }
    }
}
