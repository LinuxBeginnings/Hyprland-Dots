// Ethernet tab: every wired device with its addresses (including aliases),
// gateway, DNS and MAC.

import QtQuick
import QtQuick.Layouts

ColumnLayout {
    id: root

    property Theme theme: Theme {}
    property Backend backend

    height: implicitHeight
    spacing: 6

    function dnsText(device) {
        return device.dns.length > 0 ? device.dns.join(", ") : "—";
    }

    function detailRows(device) {
        var rows = root.backend.formattedAddresses(device);
        if (rows.length === 0) rows.push({ label: "Address", value: "—" });
        rows.push({ label: "Gateway", value: device.gateway !== "" ? device.gateway : "—" });
        rows.push({ label: "DNS", value: root.dnsText(device) });
        rows.push({ label: "MAC", value: device.mac !== "" ? device.mac : "—" });
        return rows;
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
                // A device NetworkManager does not manage (ifupdown owns the
                // NIC in some VM images) still gets its addresses below, but
                // it cannot be brought up or down from here.
                detail: modelData.managed ? modelData.iface : "Unmanaged by NetworkManager"
                trailing: !modelData.managed ? ""
                    : (modelData.connected ? "Disconnect" : "Connect")
                highlighted: modelData.connected || modelData.addresses.length > 0
                interactive: modelData.managed
                onActivated: modelData.connected
                    ? root.backend.disconnectDevice(modelData.iface)
                    : root.backend.connectDevice(modelData.iface)
            }

            InfoBlock {
                theme: root.theme
                Layout.fillWidth: true
                visible: modelData.connected || modelData.addresses.length > 0
                rows: (modelData.connected || modelData.addresses.length > 0)
                    ? root.detailRows(modelData) : []
            }

            Text {
                Layout.fillWidth: true
                Layout.leftMargin: 10
                Layout.bottomMargin: 4
                visible: !modelData.connected && modelData.addresses.length === 0
                text: !modelData.managed ? "Not managed by NetworkManager"
                    : (modelData.state !== "" ? "Cable unplugged (" + modelData.state + ")" : "Cable unplugged")
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
