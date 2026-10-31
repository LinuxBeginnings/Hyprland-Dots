// Bluetooth tab: adapter switch, discovery and the device list. Connected
// devices show their battery level when BlueZ reports one.

import QtQuick
import QtQuick.Layouts

ColumnLayout {
    id: root

    property Theme theme: Theme {}
    property Backend backend

    height: implicitHeight
    spacing: 6

    readonly property var connectedDevices: backend.btDevices.filter(function (device) {
        return device.connected;
    })

    readonly property var otherDevices: backend.btDevices.filter(function (device) {
        return !device.connected;
    })

    function batteryGlyph(level) {
        if (level >= 80) return "󰁹";
        if (level >= 40) return "󰂀";
        if (level >= 20) return "󰁾";
        return "󰁺";
    }

    function deviceGlyph(device) {
        if (device.icon === "audio-headset" || device.icon === "audio-headphones") return "󰋋";
        if (device.icon === "audio-speakers") return "󰓃";
        if (device.icon === "input-keyboard") return "󰌌";
        if (device.icon === "input-mouse") return "󰍽";
        if (device.icon === "phone") return "󰏲";
        if (device.icon === "computer") return "󰟀";
        return device.connected ? "󰂱" : "󰂯";
    }

    function batteryText(device) {
        if (device.battery < 0) return "";
        return root.batteryGlyph(device.battery) + " " + device.battery + "%";
    }

    function deviceDetail(device) {
        if (device.connected) return "Connected";
        if (device.paired) return "Paired · click to connect";
        return "Available · click to pair";
    }

    function activate(device) {
        if (device.connected) {
            backend.disconnectBluetooth(device.address);
        } else if (device.paired) {
            backend.connectBluetooth(device.address);
        } else {
            backend.pairBluetooth(device.address);
        }
    }

    // -------------------------------------------------------------- radio row
    RowLayout {
        Layout.fillWidth: true
        spacing: 6

        Text {
            text: root.backend.btEnabled ? "󰂯" : "󰂲"
            font.family: root.theme.iconFont
            font.pixelSize: 15
            color: root.backend.btEnabled ? root.theme.accent : root.theme.muted
        }

        ColumnLayout {
            Layout.fillWidth: true
            spacing: 0

            Text {
                text: "Bluetooth"
                font.family: root.theme.fontFamily
                font.pixelSize: 12
                font.bold: true
                color: root.theme.text
            }

            Text {
                Layout.fillWidth: true
                text: !root.backend.btEnabled ? "Disabled"
                    : (root.backend.btScanning ? "Scanning…"
                        : (root.backend.controller !== "" ? root.backend.controller : "No adapter"))
                font.family: root.theme.fontFamily
                font.pixelSize: 10
                color: root.theme.muted
                elide: Text.ElideRight
            }
        }

        IconButton {
            theme: root.theme
            glyph: "󰑓"
            visible: root.backend.btEnabled && !root.backend.btScanning
            onClicked: root.backend.scanBluetooth()
        }

        Switch {
            theme: root.theme
            checked: root.backend.btEnabled
            onToggled: root.backend.setBluetooth(!root.backend.btEnabled)
        }
    }

    // ------------------------------------------------------------ device list
    Flickable {
        Layout.fillWidth: true
        Layout.preferredHeight: Math.min(deviceList.implicitHeight, 320)
        contentHeight: deviceList.implicitHeight
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        visible: root.backend.btEnabled

        ColumnLayout {
            id: deviceList
            width: parent.width
            spacing: 2

            Text {
                Layout.fillWidth: true
                Layout.leftMargin: 10
                Layout.topMargin: 2
                visible: root.connectedDevices.length > 0
                text: "Connected"
                font.family: root.theme.fontFamily
                font.pixelSize: 9
                color: root.theme.muted
            }

            Repeater {
                model: root.connectedDevices

                delegate: RowItem {
                    required property var modelData
                    theme: root.theme
                    Layout.fillWidth: true
                    icon: root.deviceGlyph(modelData)
                    label: modelData.name !== "" ? modelData.name : modelData.address
                    detail: root.deviceDetail(modelData)
                    trailing: root.batteryText(modelData)
                    highlighted: true
                    onActivated: root.activate(modelData)
                }
            }

            Text {
                Layout.fillWidth: true
                Layout.leftMargin: 10
                Layout.topMargin: 6
                visible: root.otherDevices.length > 0
                text: "Paired & available"
                font.family: root.theme.fontFamily
                font.pixelSize: 9
                color: root.theme.muted
            }

            Repeater {
                model: root.otherDevices

                delegate: RowItem {
                    required property var modelData
                    theme: root.theme
                    Layout.fillWidth: true
                    icon: root.deviceGlyph(modelData)
                    label: modelData.name !== "" ? modelData.name : modelData.address
                    detail: root.deviceDetail(modelData)
                    trailing: root.batteryText(modelData)
                    onActivated: root.activate(modelData)
                }
            }

            Text {
                Layout.fillWidth: true
                Layout.leftMargin: 10
                Layout.topMargin: 4
                visible: root.backend.loaded && root.backend.btDevices.length === 0
                text: root.backend.btScanning ? "Scanning for devices…" : "No devices found"
                font.family: root.theme.fontFamily
                font.pixelSize: 10
                color: root.theme.muted
            }
        }
    }

    Text {
        Layout.fillWidth: true
        Layout.leftMargin: 4
        visible: !root.backend.btEnabled
        text: "Bluetooth is off"
        font.family: root.theme.fontFamily
        font.pixelSize: 11
        color: root.theme.muted
    }
}
