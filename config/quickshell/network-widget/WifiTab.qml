// Wi-Fi tab: radio switch, current connection details (address, gateway,
// DNS, MAC) and the available networks.

import QtQuick
import QtQuick.Layouts

ColumnLayout {
    id: root

    property Theme theme: Theme {}
    property Backend backend

    // A secured network that is not saved yet waits here until a password is
    // entered.
    property string pendingSsid: ""
    readonly property bool prompting: pendingSsid !== ""

    height: implicitHeight
    spacing: 6

    onVisibleChanged: {
        if (!visible) root.cancelPrompt();
    }

    readonly property var activeDevice: {
        for (var i = 0; i < backend.devices.length; i++) {
            if (backend.devices[i].type === "wifi") return backend.devices[i];
        }
        return null;
    }

    readonly property var activeNetwork: {
        for (var i = 0; i < backend.networks.length; i++) {
            if (backend.networks[i].inUse) return backend.networks[i];
        }
        return null;
    }

    function wifiGlyph(signal) {
        if (signal >= 80) return "󰤨";
        if (signal >= 60) return "󰤥";
        if (signal >= 40) return "󰤢";
        if (signal >= 20) return "󰤟";
        return "󰤯";
    }

    function isLocked(network) {
        return network.security !== "" && network.security !== "--";
    }

    function networkDetail(network) {
        var security = root.isLocked(network) ? network.security : "Open";
        return network.signal + "% · " + security;
    }

    function networkTrailing(network) {
        var parts = [];
        if (network.inUse) parts.push("Connected");
        if (root.isLocked(network)) parts.push("󰌾");
        return parts.join(" ");
    }

    function detailRows(device) {
        var rows = root.backend.formattedAddresses(device);
        if (rows.length === 0) rows.push({ label: "Address", value: "—" });
        rows.push({ label: "Gateway", value: device.gateway !== "" ? device.gateway : "—" });
        rows.push({ label: "DNS", value: device.dns.length > 0 ? device.dns.join(", ") : "—" });
        rows.push({ label: "MAC", value: device.mac !== "" ? device.mac : "—" });
        return rows;
    }

    function activateNetwork(network) {
        if (network.inUse) {
            backend.disconnectWifi(network.ssid);
            return;
        }
        if (!root.isLocked(network)) {
            backend.connectWifi(network.ssid, "");
            return;
        }
        root.pendingSsid = network.ssid;
        passwordInput.text = "";
        passwordInput.forceActiveFocus();
    }

    function submitPassword() {
        if (!root.prompting) return;
        backend.connectWifi(root.pendingSsid, passwordInput.text);
        root.pendingSsid = "";
    }

    function cancelPrompt() {
        root.pendingSsid = "";
    }

    // -------------------------------------------------------------- radio row
    RowLayout {
        Layout.fillWidth: true
        spacing: 6

        Text {
            text: root.backend.wifiEnabled
                ? (root.activeNetwork ? root.wifiGlyph(root.activeNetwork.signal) : "󰤨")
                : "󰤭"
            font.family: root.theme.iconFont
            font.pixelSize: 15
            color: root.backend.wifiEnabled ? root.theme.accent : root.theme.muted
        }

        ColumnLayout {
            Layout.fillWidth: true
            spacing: 0

            Text {
                text: "Wi-Fi"
                font.family: root.theme.fontFamily
                font.pixelSize: 12
                font.bold: true
                color: root.theme.text
            }

            Text {
                Layout.fillWidth: true
                text: !root.backend.wifiEnabled ? "Disabled"
                    : (root.activeNetwork ? root.activeNetwork.ssid : "Not connected")
                font.family: root.theme.fontFamily
                font.pixelSize: 10
                color: root.theme.muted
                elide: Text.ElideRight
            }
        }

        IconButton {
            theme: root.theme
            glyph: "󰑓"
            visible: root.backend.wifiEnabled
            onClicked: root.backend.rescanWifi()
        }

        Switch {
            theme: root.theme
            checked: root.backend.wifiEnabled
            onToggled: root.backend.setWifi(!root.backend.wifiEnabled)
        }
    }

    // ------------------------------------------------- connection information
    InfoBlock {
        theme: root.theme
        Layout.fillWidth: true
        visible: root.activeDevice !== null && root.activeDevice.connected
        rows: (root.activeDevice !== null && root.activeDevice.connected)
            ? root.detailRows(root.activeDevice) : []
    }

    // -------------------------------------------------------- password entry
    RowLayout {
        Layout.fillWidth: true
        spacing: 6
        visible: root.prompting

        Text {
            text: "󰌾"
            font.family: root.theme.iconFont
            font.pixelSize: 13
            color: root.theme.accent
        }

        Text {
            text: root.pendingSsid
            font.family: root.theme.fontFamily
            font.pixelSize: 10
            elide: Text.ElideRight
            color: root.theme.text
            Layout.maximumWidth: 96
        }

        Rectangle {
            Layout.fillWidth: true
            implicitHeight: 26
            radius: 6
            color: root.theme.surfaceAlt
            border.width: 1
            border.color: passwordInput.activeFocus ? root.theme.accent : root.theme.border

            TextInput {
                id: passwordInput
                anchors.fill: parent
                anchors.leftMargin: 8
                anchors.rightMargin: 8
                verticalAlignment: TextInput.AlignVCenter
                color: root.theme.text
                font.family: root.theme.fontFamily
                font.pixelSize: 11
                echoMode: TextInput.Password
                passwordCharacter: "•"
                selectByMouse: true
                onAccepted: root.submitPassword()
                Keys.onEscapePressed: root.cancelPrompt()
            }
        }

        IconButton {
            theme: root.theme
            glyph: "󰄬"
            glyphColor: root.theme.good
            onClicked: root.submitPassword()
        }

        IconButton {
            theme: root.theme
            glyph: "󰅖"
            onClicked: root.cancelPrompt()
        }
    }

    // --------------------------------------------------------- network list
    Flickable {
        Layout.fillWidth: true
        Layout.preferredHeight: Math.min(networkList.implicitHeight, 300)
        contentHeight: networkList.implicitHeight
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        visible: root.backend.wifiEnabled

        ColumnLayout {
            id: networkList
            width: parent.width
            spacing: 2

            Repeater {
                model: root.backend.networks

                delegate: RowItem {
                    required property var modelData
                    theme: root.theme
                    Layout.fillWidth: true
                    icon: root.wifiGlyph(modelData.signal)
                    label: modelData.ssid
                    detail: root.networkDetail(modelData)
                    trailing: root.networkTrailing(modelData)
                    highlighted: modelData.inUse
                    onActivated: root.activateNetwork(modelData)
                }
            }

            Text {
                Layout.fillWidth: true
                Layout.leftMargin: 10
                Layout.topMargin: 4
                visible: root.backend.loaded && root.backend.networks.length === 0
                text: "No networks found"
                font.family: root.theme.fontFamily
                font.pixelSize: 10
                color: root.theme.muted
            }
        }
    }

    Text {
        Layout.fillWidth: true
        Layout.leftMargin: 4
        visible: !root.backend.wifiEnabled
        text: "Wi-Fi is off"
        font.family: root.theme.fontFamily
        font.pixelSize: 11
        color: root.theme.muted
    }
}
