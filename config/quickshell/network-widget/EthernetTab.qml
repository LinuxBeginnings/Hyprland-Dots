// Ethernet tab: wired devices with their address, gateway, DNS and MAC.

import QtQuick
import QtQuick.Layouts

ColumnLayout {
    id: root

    property Theme theme: Theme {}
    property Backend backend

    height: implicitHeight
    spacing: 6

    function addressText(device) {
        if (device.ip === "") return "—";
        return device.prefix !== "" ? device.ip + "/" + device.prefix : device.ip;
    }

    function dnsText(device) {
        return device.dns.length > 0 ? device.dns.join(", ") : "—";
    }

    Repeater {
        model: root.backend.ethernetDevices

        delegate: ColumnLayout {
            required property var modelData
            Layout.fillWidth: true
            spacing: 4

            RowItem {
                theme: root.theme
                Layout.fillWidth: true
                icon: "󰌘"
                label: modelData.connection !== "" ? modelData.connection : modelData.iface
                detail: modelData.iface
                trailing: modelData.connected ? "Disconnect" : "Connect"
                highlighted: modelData.connected
                onActivated: modelData.connected
                    ? root.backend.disconnectDevice(modelData.iface)
                    : root.backend.connectDevice(modelData.iface)
            }

            InfoBlock {
                theme: root.theme
                Layout.fillWidth: true
                visible: modelData.connected
                rows: modelData.connected ? [
                    { label: "Address", value: root.addressText(modelData) },
                    { label: "Gateway", value: modelData.gateway !== "" ? modelData.gateway : "—" },
                    { label: "DNS", value: root.dnsText(modelData) },
                    { label: "MAC", value: modelData.mac !== "" ? modelData.mac : "—" }
                ] : []
            }

            Text {
                Layout.fillWidth: true
                Layout.leftMargin: 10
                Layout.bottomMargin: 4
                visible: !modelData.connected
                text: modelData.state !== "" ? "Cable unplugged (" + modelData.state + ")" : "Cable unplugged"
                font.family: root.theme.fontFamily
                font.pixelSize: 10
                color: root.theme.muted
            }
        }
    }

    Text {
        Layout.fillWidth: true
        Layout.leftMargin: 4
        visible: root.backend.ethernetDevices.length === 0
        text: "No wired network device"
        font.family: root.theme.fontFamily
        font.pixelSize: 11
        color: root.theme.muted
    }
}
